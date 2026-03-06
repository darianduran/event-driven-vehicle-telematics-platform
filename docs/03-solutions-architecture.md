# 3.0 Solution Architecture

## 3.1 High-Level Architecture

### 3.1.1 High-Level Architecture Diagram

![Architecture Overview](../diagrams/aws-architecture-overview.png)

### 3.1.3 AWS Services

| Service | Role | Design Rationale |
|---------|------|-----------------|
| **CloudFront** | Multi-origin CDN with path-based routing to S3, API Gateway, and NLB | Terminates TLS globally, separates API and SSE traffic, provides DDoS baseline |
| **WAF** | Rate limiting + AWS managed rule sets | Protects API Gateway and CloudFront from abuse at the edge |
| **API Gateway (HTTP)** | REST API with JWT + custom authorizers | Managed auth offload; HTTP API chosen over REST API for lower latency and cost. See [ADR-002](../adrs/002-api-gateway-lambda-over-fargate.md) |
| **Cognito** | User pool with pre-token trigger | Embeds `organizationId`, `role`, and authorized `pseudoVINs` into JWT at mint-time. See [§5.4](05-security-and-compliance.md) |
| **ECS Fargate** | Telemetry Server (mTLS), Consumer (KCL), SSE Server (Spot) | Serverless compute removes cluster management; Container Insights provides golden signals. See [ADR-003](../adrs/003-ecs-fargate-over-eks.md), [ADR-004](../adrs/004-lambda-vs-fargate-decision-matrix.md) |
| **ECR** | Container image repositories (4) with scan-on-push | Vulnerability scanning at push-time; lifecycle policy retains last 5 images per repo |
| **NLB** | TCP passthrough load balancer for mTLS (port 443) and SSE (port 3000) | Layer 4 passthrough preserves mTLS termination at the application; routes SSE traffic from CloudFront |
| **Kinesis Data Streams** | On-demand telemetry ingestion with per-VIN partition ordering | Ordered, durable, replayable stream; on-demand mode absorbs burst without pre-provisioning shards |
| **ElastiCache (Redis)** | Real-time vehicle state + pub/sub fan-out to SSE clients | Sub-millisecond reads for current vehicle state; pub/sub fan-out. See [ADR-006](../adrs/006-redis-for-realtime-pubsub.md) |
| **DynamoDB** | Primary data store (28 tables) | Single-digit millisecond reads; on-demand capacity. See [ADR-005](../adrs/005-dynamodb-multi-table-design.md) |
| **Lambda** | REST API handlers, async processors, JWT enrichment | 11 functions for async tasks, authorizers, and scheduled jobs. See [ADR-002](../adrs/002-api-gateway-lambda-over-fargate.md) |
| **SQS** | Async processing queues with DLQs | Decouples Kinesis consumers from downstream processing; DLQs prevent data loss |
| **SNS** | Critical Alerts and Security Alerts notification topics | Fan-out for operational and security alerts; integrates with GuardDuty via EventBridge |
| **EventBridge** | Scheduled tasks (orphan detection, cleanup) + GuardDuty event routing | Cron-style operations without persistent compute; routes GuardDuty findings to SNS |
| **S3** | Webpage asset hosting, trip archives, dashcam media, exported reports, logs | Lifecycle policies tier cold data to Glacier IR; VPC Gateway Endpoint eliminates NAT cost |
| **Secrets Manager** | TLS certs, API keys, HMAC key (8 secrets) | Rotation-capable; no secrets in environment variables or code |
| **Systems Manager Parameter Store** | 18 runtime-tunable parameters for ECS and Lambda services | Configuration changes take effect without redeployment; covers ingestion rates, trip thresholds, token expiry |
| **KMS** | Dedicated encryption keys for Kinesis, S3 (telemetry, dashcam, fleet-reports) | Customer-managed keys with automatic rotation; bucket key enabled to reduce API costs |
| **ACM** | DNS-validated TLS certificate for CloudFront custom domain | Automated certificate renewal; CloudFront requires us-east-1 certificate |
| **CloudWatch** | Logs, alarms, metric filters, Container Insights, dashboards | Centralized observability; 7 security metric filters on CloudTrail; Container Insights for ECS golden signals |
| **CloudTrail** | Multi-region audit trail with S3 data events on sensitive buckets | Full API audit trail with log file validation; 7 metric filters and alarms for security monitoring |
| **GuardDuty** | Threat detection via VPC Flow Log analysis | Automated threat detection; high/critical findings forwarded to Security Alerts SNS topic |
| **AWS Cloud Map** | Private DNS service discovery under Cloudmap namespaces | Internal service-to-service resolution without hardcoded endpoints |
| **AWS Location Service** | Geocoding, reverse geocoding, route calculation | Powers the Live Map and location-based features in the web console |
| **Amazon Bedrock** | AI-powered trip summary generation (Claude Haiku) | Optional natural-language trip summaries generated during trip processing; invoked by Trip Processor Lambda |
| **AWS Organizations** | Multi-account governance with SCPs | SCPs enforce region restriction, instance type limits, root account denial, MFA for destructive actions |
| **AWS Budgets** | Development account cost monitoring ($500/month) | Multi-threshold alerting at 80%, 90% (forecasted), and 100% of budget |

### 3.1.5 Integration Points

The platform integrates with three external systems across distinct trust boundaries:

| Integration | Protocol | Direction | Trust Level | Authentication |
|---|---|---|---|---|
| Connected vehicles | WebSocket over mTLS | Inbound | Semi-trusted | OEM-issued X.509 certificates validated by the Telemetry Server |
| Vehicle OEM Fleet API | HTTPS | Outbound | Semi-trusted | Request signing with OEM-registered private key (Secrets Manager) |
| Browser clients | HTTPS / SSE | Inbound | Untrusted | Cognito JWT with embedded tenant claims |

Internal service-to-service communication uses AWS Cloud Map for private DNS discovery under the `fleet.local` namespace. The Signing Proxy resolves the OEM API endpoint at the application layer and validates the destination domain before forwarding signed requests.

All integration points are documented in the STRIDE threat model — see [Appendix B](appendix-b-risk-register.md).

---

## 3.2 Network Architecture

![Network Topology](../diagrams/network-topology.png)


| Subnet Tier | Resources | Purpose |
|---|---|---|
| Public (2) | NLB, NAT Gateway | Load balancing for mTLS passthrough and SSE; outbound internet for private subnets |
| Private (2) | ECS Fargate tasks, VPC-attached Lambda, ElastiCache Redis | All application compute runs in private subnets with no direct internet exposure |

Network cost optimizations:

- VPC Gateway Endpoints for S3 and DynamoDB eliminate NAT data transfer fees for storage operations
- NAT Instances are used for non-production environments reducing costs to below $5
- VPC Flow Logs capture all ACCEPT and REJECT traffic to CloudWatch Logs with 90-day retention for security analysis

NLB forwarding rules:

| Port | Target | Purpose |
|---|---|---|
| 443 (TCP) | Fleet Telemetry Server | mTLS passthrough — TLS terminated by the application, not the load balancer |
| 3000 (TCP) | Fleet SSE Server | Server-Sent Events streaming to browser clients via CloudFront |

---

## 3.3 Security Architecture Overview

Security is enforced at eight layers using a defense-in-depth model. A compromise at any single layer does not expose sensitive data:

![Defense in Depth Diagram](../diagrams/defense-in-depth.png)


Key security controls at the architecture level:

- VIN pseudonymization (HMAC-SHA256) at the ingestion boundary — raw VINs never reach application databases or logs
- Cognito JWT with embedded tenant claims (`organizationId`, `role`, `pseudoVINs`) injected server-side at token mint-time
- Per-function IAM execution roles with least-privilege policies scoped to specific DynamoDB tables, S3 buckets, and SQS queues
- Service Control Policies (SCPs) enforce region restriction, instance type limitation, root account denial, and MFA for destructive actions
- CloudTrail with 7 metric filters and alarms monitoring sensitive operations

For the complete security design including encryption tables, RBAC matrix, multi-tenancy isolation model, and audit logging details, see [§5 Security and Compliance](05-security-and-compliance.md). For the STRIDE threat model, see [Appendix B](appendix-b-risk-register.md).

