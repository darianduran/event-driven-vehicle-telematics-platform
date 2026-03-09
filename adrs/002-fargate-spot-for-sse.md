# ADR 2: Fargate Spot for Interruption-Tolerant SSE Workloads

The SSE Service is an ECS Fargate service that updates user's dashboards with vehicle data in real-time. It is stateless and reconnects seamlessly after failure. During SSE interruption the browser falls back to DynamoDB polling within 5 seconds and auto-reconnects once the SSE service recovers.

## Decision

We will configure the SSE service with Fargate Spot capacity instead of standard capacity.

## Rationale

Fargate Spot provides up to 70% cost reduction. The spot interruption trade-off is acceptable because the service is stateless, the browser handles automatic reconnection, DynamoDB polling provides a fallback during interruption, and ECS automatically launches replacement Spot tasks.

Rejected alternatives:
- **Standard Fargate:** Higher cost for an always-active workload with no cost benefit during low traffic.
- **EC2 Spot Instances:** Requires significantly more admin overhead.
- **WebSocket via API Gateway:** Per-message pricing scales poorly at expected telemetry volume.

## Status

Accepted (02JAN2026)

## Consequences

- SSE compute cost reduced by ~60-70%.
- No front-end changes required.
- The DDB polling fallback doubles as the Spot interruption safety net.
- ECS service `capacityProviderStrategy` changes to `FARGATE_SPOT`.
- CloudWatch alarms should monitor task replacement frequency to detect sustained Spot unavailability.
