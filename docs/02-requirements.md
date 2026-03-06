# 2.0 Requirements

## 2.1 Business Requirements

| ID | Requirement |
|----|-------------|
| BR-1 | The platform must ingest and process vehicle telemetry from connected fleets in real-time |
| BR-2 | The platform must support multi-tenant fleet operations where each tenant's data, users, and vehicles are fully isolated | 
| BR-3 | The platform must provide vehicle state updates for real-time operational visibility | 
| BR-4 | The platform must support encrypted bidirectional vehicle communication for data ingestion and command execution |
| BR-5 | The platform must pseudonymize vehicle identification data (PII) at the ingestion boundary so that unique identifiers are never exposed  |
| BR-6 | The platform must scale from 100 to 10,000+ connected vehicles without design changes. As vehicle count increases, cost per vehicle should decrease. |
| BR-7 | The platform must be simple enough to run without a dedicated operations team. Managed services reduce admin overload and runbooks close gaps | 
| BR-8 | The platform should have the ability to replay data streams in the event of outages |
| BR-9 | The platform should be able to be extended to support additional OEM vehicle endpoints beyond initial implementation |

---

## 2.2 Technical Requirements

### 2.2.1 Data Ingestion and Streaming

| ID | Requirement | Specification |
|----|-------------|---------------|
| TR-1 | Secure vehicle connections | Accept mTLS-only connections from vehicles and validate certificates |
| TR-2 | Durable Data Streams | Individual events are unique and map to a specific vehicle. 7-day retention windows are used for replay or auditing |
| TR-3 | Fan-out processing | Process telemetry batches to multiple targets depending on the event |
| TR-4 | PII pseudonymization at ingestion | Apply a hashing algorithm to customer PII to reduce exposure risk |


### 2.2.2 Real-Time Data Delivery

| ID | Requirement | Specification |
|----|-------------|---------------|
| TR-5 | Server-sent events to client's dashboards | Deliver vehicle state updates to a client's dashboard immediately|
| TR-6 | Graceful degradation | If a client's SSE subscription fails to connect, clients must fallback to REST API polling as a backup |
| TR-7 | Connection resilience | Connections must be able to recover automatically in the event of brief outage or spot interruption |

### 2.2.3 API and Integration

| ID | Requirement | Specification |
|----|-------------|---------------|
| TR-8 | Zero-Trust API | All API requests are validated through JWT authentication and RBAC enforcement |
| TR-9 | Secure Command Signing | Internet egressing vehicle commands are cryptographically signed with OEM trusted keys. Keys are securely stored in Secrets Manager and support rotation. Every command is logged for auditing purposes |
| TR-10 | Service discovery | Private services must be able to discover each other automatically without hardcoding or manual intervention |

### 2.2.4 Multi-Tenancy and Data Isolation

| ID | Requirement | Specification |
|----|-------------|---------------|
| TR-11 | Four-layer tenant isolation | Enforce tenant boundaries independently at authentication, API authorization, data partitioning, and real-time subscription layers |
| TR-12 | Data partitioning | All data stores must partition by tenant IDs. Tenant-to-tenant data leakage should not be possible through ID validation |

### 2.2.5 Data Processing and Resilience

| ID | Requirement | Specification |
|----|-------------|---------------|
| TR-13 | Multi-stage processing safety net | Workflows must have a robust safety net that can detect anomalies, separate errored jobs, and route them to reconciliation paths. |
| TR-14 | At-least-once delivery | Consumers must be able to redelivery on failure and duplicate events must be idempotent |
| TR-15 | Dead-letter queues | DLQs prevent processing paths blockages and are retained for manual review and debugging |

### 2.2.6 Data Storage and Lifecycle

| ID | Requirement | Specification |
|----|-------------|---------------|
| TR-16 | Primary data store | Severless DynamoDB stores are provisioned with on-demand capacity to scale effectively |
| TR-17 | Object storage tiering | Lifecycle policies are configured where applicable to reduce storage costs |
| TR-18 | TTL-based expiration | Ephemeral data should auto-expire through TTLs without manual intervention |
| TR-19 | Point-in-time recovery | Primary data tables must have point in time recovery and deletion protection enabled |

---

## 2.3 Non-Functional Requirements

### 2.3.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1 | Telemetry ingestion latency (p99) | < 1 second end-to-end |
| NFR-2 | SSE event delivery latency (p99) | < 500ms from stream to browser |
| NFR-3 | API response latency (p95) | < 200ms for single-entity reads |

### 2.3.2 Availability and Resilience

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-4 | API availability | 99.9% (30-day rolling) |
| NFR-5 | Trip record write success rate | 99.95% |
| NFR-6 | Single component failure RTO | < 5 minutes with zero data loss |
| NFR-7 | Data recovery (corruption/deletion) | RTO < 1 hour, RPO < 15 minutes |
| NFR-8 | Full region failure | RTO < 4 hours, RPO < 1 hour |

### 2.3.3 Security and Compliance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-9 | Encryption at rest | All data stores encrypted (KMS for sensitive data, AES-256 for others) |
| NFR-10 | Encryption in transit | TLS 1.2 minimum for all connections; mTLS for vehicle connections |
| NFR-11 | Audit logging | All API calls logged via CloudTrail; sensitive operations alarmed via metric filters |
| NFR-12 | Secrets management | No secrets in environment variables, code, or configuration files; rotation-capable secrets store required |
| NFR-13 | Least-privilege IAM | Per-function execution roles scoped to specific resources; no wildcard resource policies |

### 2.3.4 Scalability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-14 | Horizontal scalability | Support 100 to 50,000+ vehicles without architectural changes |
| NFR-15 | Burst absorption | Handle 2.5x steady-state traffic spikes without manual intervention |
| NFR-16 | On-demand capacity | All primary compute and storage services must auto-scale without pre-provisioning |

### 2.3.5 Operational Excellence

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-17 | Infrastructure as Code | 100% of resources defined in Terraform; no console-created resources |
| NFR-18 | Observability | Structured JSON logging with correlation IDs across all services; CloudWatch dashboards for golden signals |
| NFR-19 | Cost efficiency | Cost per vehicle decreases with fleet size; fixed costs amortize across tenants |
| NFR-20 | Serverless-first compute | ECS Fargate and Lambda only for application workloads; no self-managed EC2 instances |

## 2.4 Constraints and Assumptions

### Constraints

| ID | Constraint | Architectural Impact |
|----|-----------|----------------------|
| C-1 | Single-region deployment (us-east-1) | Regional failure requires manual failover; cross-region replication deferred to future phase |
| C-2 | Tesla Fleet Telemetry as reference data source | Ingestion layer is OEM-specific; all downstream components are OEM-agnostic by design |
| C-3 | Development budget of ~$500/month | Drives cost optimization decisions: NAT Instance over NAT Gateway, Fargate Spot for reconnectable workloads, on-demand pricing over reserved capacity |
| C-4 | No dedicated operations team | Architecture must minimize operational burden; favor managed services, auto-scaling, TTL-based cleanup, and automated recovery |
| C-5 | Serverless-first compute model | Eliminates cluster management overhead; constrains technology choices to Fargate and Lambda |

### Assumptions

| ID | Assumption | Capacity Impact |
|----|-----------|-----------------|
| A-1 | Average 15% of fleet actively driving at any time | Drives steady-state throughput model; 10,000 vehicles = ~1,500 concurrent streams |
| A-2 | 1–2 telemetry events per vehicle per second while driving | Sets baseline ingestion rate: 1,500–3,000 events/sec at 10K vehicles |
| A-3 | Average telemetry event payload of ~500 bytes (Protobuf) | Determines stream throughput: ~1.5 MB/sec at 10K vehicles |
| A-4 | Peak traffic multiplier of 2.5x steady state | Capacity model must handle 7,500 events/sec burst at 10K vehicles |
| A-5 | Vehicles buffer telemetry locally during connectivity gaps | Platform does not need to guarantee delivery from vehicles; at-least-once semantics start at the ingestion boundary |
| A-6 | Users access the platform via modern browsers with EventSource API support | Required for SSE-based real-time updates; no legacy browser support |

## 2.5 Service Level Objectives

The platform defines internal SLOs that serve as engineering targets. These are set tighter than any external SLA to provide an error budget buffer. Full SLO definitions, measurement methodology, and error budget policy are documented in [§9 Operations and Support](09-operations-and-support.md) and [`ops/slos/slos.md`](../ops/slos/slos.md).

| SLO | Target | Error Budget (30 days) |
|-----|--------|----------------------|
| API availability | 99.9% | 43.2 minutes of downtime |
| Telemetry ingestion latency (p99) | < 1 second | 0.1% of events may exceed 1s |
| SSE event delivery latency (p99) | < 500ms | 0.1% of events may exceed 500ms |
| Trip record write success rate | 99.95% | 0.05% of trips may fail to persist |

### Recovery Objectives

| Tier | Scope | RTO | RPO |
|------|-------|-----|-----|
| Service availability | Single component failure | < 5 minutes | 0 (no data loss) |
| Data recovery | Data corruption or accidental deletion | < 1 hour | < 15 minutes |
| Full region failure | us-east-1 regional outage | < 4 hours | < 1 hour |

See [§7 Business Continuity and DR](07-business-continuity-and-dr.md) for detailed recovery procedures.
