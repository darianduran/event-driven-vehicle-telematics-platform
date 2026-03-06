# 1.0 Executive Summary

## 1.1 Business Context

The automotive telematics industry is rapidly expanding as fleet operators adopt modernized connected vehicles into their fleets. To operate efficiently with large-scale fleet sizes, organizations require real-time visibility into their vehicles, driver behaviors, remote management, and actionable insights such as maintenance requirements.

This solution architecture demonstrates how to design and deploy a vehicle telemetry platform on AWS that addresses common challenges faced by fleet management providers.

## 1.2 Problem Statement

Fleet telemetry platforms must solve five simultaneous challenges at scale:

- Ingest thousands of telemetry events per second with subsecond latency.
- Serve concurrent data consumers including dashboards and analytical insights to multiple clients.
- Implement strict boundaries between clients and fleet organizations.
- Secure and protect customer data and privacy.
- Keep costs proportional to user-base and fleet size.

For the full requirements specification including SLAs, constraints, and assumptions, see [Requirements documentation](02-requirements.md).

## 1.3 Solution Overview

The platform addresses these challenges through five architectural pillars:

- **Event-driven ingestion** — Kinesis Data Streams with per-vehicle ordering and 7-day replay
- **Real-time processing** — Go-based ECS Fargate Consumer with Protobuf parsing, VIN pseudonymization, and trip boundary detection
- **Sub-second dashboard updates** — Redis pub/sub fan-out to Server-Sent Events
- **Four-layer tenant isolation** — Authentication, API authorization, data partitioning, and real-time subscriptions enforced independently
- **VIN pseudonymization** — HMAC-SHA256 at the ingestion boundary so raw VINs never reach application databases

The full architecture is documented in [§3 Solution Architecture](03-solution-architecture.md), with data flows and schemas in [§4 Technical Design](04-technical-design.md).

## 1.4 Key Outcomes

| Outcome | How it's achieved |
|---------|-------------------|
| Real-time visibility | Sub-second telemetry via Kinesis → ECS Consumer → Redis pub/sub → SSE |
| Strong tenant isolation | Four independent isolation layers — any single layer compromise does not expose cross-tenant data |
| Privacy by design | VIN pseudonymization at ingestion; raw VINs stored only in admin-restricted table with CloudTrail auditing |
| Cost proportional to scale | On-demand Kinesis/DynamoDB; Fargate Spot for SSE; NAT Instance in dev; VPC Gateway Endpoints |
| Operational maturity | IaC-only (26 Terraform modules); 4 SLOs with error budget policy; 5 runbooks; structured logging |
| Security depth | 8-layer defense-in-depth; STRIDE threat model; dual-person access controls; GuardDuty |
| Resilient processing | 3-tier trip safety net; Kinesis 7-day replay; DLQs; SSE → API polling fallback |
| Documented decisions | 7 ADRs capturing context, alternatives, and rationale |

## 1.5 Cost at Scale

| Fleet Size | Monthly Cost | Cost Per Vehicle |
|------------|-------------|-----------------|
| 100 vehicles | ~$150 | $1.50 |
| 1,000 vehicles | ~$220 | $0.22 |
| 10,000 vehicles | ~$620 | $0.062 |
| 50,000 vehicles | ~$1,730 | $0.035 |

Fixed costs (WAF, GuardDuty, KMS, base compute) amortize across the fleet; variable costs (Kinesis, DynamoDB, S3) scale linearly. See [§10 Cost Analysis](10-cost-analysis.md) for per-service breakdowns.

