# ADR-002: API Gateway + Lambda over Fargate for REST API

**Status:** Accepted
**Date:** 2026-01-10

## Context

The platform exposes a REST API serving the web console and external integrations. This API
handles fleet management operations, vehicle data retrieval, trip history queries,
authentication flows, report generation, and alert management. Request patterns are unpredictable and correlates with fleet operation working hours.

The original implementation ran the REST API as a dedicated ECS Fargate service.
Although the design was functional, it introduced a fixed cost even when workloads were not in use.

## Decision

Replace the dedicated ECS Fargate API service with Amazon API Gateway (HTTP API) and Lambda functions.

## Rationale

API Gateway HTTP API + Lambda is a better fit for this workload because:

1. Pay-per-request pricing eliminates idle cost entirely.
2. API Gateway provides integrated request authentication and authorization with Cognito.

The migration reduced monthly API compute costs by roughly 80% while simultaneously reducing
admin overhead.

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| API Gateway (HTTP API) + Lambda | Pay-per-request; zero idle cost; built-in JWT auth and CORS; automatic scaling; no container management for API layer | Cold starts on first request after idle (~200-500ms for Node.js); 29-second API Gateway timeout; 10MB payload limit | **Selected** |
| ECS Fargate (dedicated API service) | No cold starts; no timeout constraints; full control over runtime environment | Fixed minimum cost regardless of traffic; requires scaling policy configuration; container image management overhead; must implement auth middleware | Rejected — idle cost unjustified for bursty, low-to-moderate traffic API |
| ECS Fargate with scale-to-zero | Could theoretically eliminate idle cost | ECS Fargate does not support true scale-to-zero; minimum desired count of 0 still incurs ALB costs and has slow cold-start (30-60s for task launch) | Rejected — not a real scale-to-zero solution; worse cold start than Lambda |
| AppRunner | Simpler than ECS; supports scale-to-zero | Less mature; fewer integration options; still container-based with slower cold starts than Lambda; limited VPC integration at the time of evaluation | Rejected — Lambda provides better cost efficiency and richer API Gateway integration |

## Trade-offs

- **Optimizing for:** Cost efficiency and less admin overhead.
- **Accepting:** Cold start latency (~200-500ms) on first request after idle period; 29-second
  hard timeout on API Gateway.

## Consequences

- Monthly API compute cost reduced by approximately 80%
- Zero-traffic periods no longer incur zero compute cost
- API Gateway provides JWT authorization, CORS, and access logging as managed features,
  reducing application code
- Cold starts add ~200-500ms to the first request after an idle period; subsequent requests
  within the same execution context are warm
- The 29-second API Gateway timeout requires that any long-running operations (report
  generation, bulk exports) use an async pattern (SQS + polling) rather than synchronous
  response
- Lambda concurrency limits (default 1000 per region) are well above expected peak traffic
  but should be monitored
- Container image management is no longer needed for the API layer — deployment is a Lambda
  code package update
