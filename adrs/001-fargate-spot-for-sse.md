# ADR-001: Fargate Spot for Interruption-Tolerant SSE Workloads

**Status:** Accepted
**Date:** 2026-01-02

## Context

The SSE Service is an ECS Fargate service that establishes persistent Server-Sent Events
connections with client's dashboards. It streams real-time vehicle data as the Telemetry Consumer publishes updates to Redis.

The original SSE implementation utilized standard Fargate capacity. This solution worked reliably but given that it was always active, it continuously consumed resources that at times aren't needed. Given that cost efficiency is a high priority design goal, the dedicated Fargate service delivered little value.

A key characteristic of the SSE service is that it's stateless and can seamlessly reconnects after interruption. During connection drops, the client's browser falls back to periodic API calls to DynamoDB within seconds. In the background the browser automatically reconnects once the SSE service recovers. This prevents gaps or loss of visibility from the user's perspective.

## Decision

The SSE service would be configured with Fargate spot capacity instead of standard capacity.

## Rationale

Fargate spot provides the same compute workflows at discounted prices up to 70% off compared to standard prices. The trade off is that AWS can reclaim capacity at any time, however this trade off is
acceptable with this workflow because:

1. The SSE service only subscribes to Redis channels and forwards events.
2. The browser handles automatic reconnection seamlessly.
3. The browser uses DynamoDB polling fallback to provides a secondary path during the brief interruption window, so the dashboard never shows stale data.
4. ECS automatically launches a replacement Spot task when one is reclaimed, so recovery is automated with no manual intervention.

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Fargate Spot (SSE Server) | Up to 70% cost reduction. Fully automated recovery. Interruption is not visible to user due to polling fallback. | Potential 2-minute interruption. | **Selected** |
| Standard Fargate | Zero interruption risk. Simplest to manage.  | Higher cost for an always active workload. No cost benefit during low traffic periods. | Rejected - cost premium is not justified. |
| EC2 Spot Instances (self-managed) | Potentially cheaper at larger scale. | Requires significantly more admin overhead. | Rejected - this design goes against the serverless-first approach. |
| WebSocket via API Gateway | Fully managed. No persistent compute required. | API Gateway WebSocket has per message pricing. Scales poorly to high volume use cases. Requires keep-alive logic. | Rejected - higher costs at the expected telemetry volume and adds admin overhead |

## Trade-offs

- **Optimizing for:** Cost efficiency on an always active workload.
- **Accepting:** Occasional 2-minute interruption windows during Spot reclamation with polling fallback and automated recovery.

## Consequences

- SSE Server compute cost reduced by approximately 60-70% compared to standard Fargate
- No change required for the front-end.
- The DDB polling fallback which originally served for network resilience, now doubled as the spot interruption safetynet.
- The ECS service `capacityProviderStrategy` configuration changes to `FARGATE_SPOT`.
- CloudWatch alarms should be implemented to monitor task replacement frequency and duration to detect sustained Spot unavailability. 