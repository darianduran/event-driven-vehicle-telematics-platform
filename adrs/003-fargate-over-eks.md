# ADR 3: ECS Fargate over EKS

The platform runs three containerized services: Telemetry Server, Telemetry Consumer, and SSE Server. Given the smaller budget and lack of operational team,  less admin overhead and infrastructure cost are clear objectives.

## Decision

We will use Amazon ECS with Fargate launch type for all containerized workloads.

## Rationale

EKS costs around $70/month before factoring in the cost of nodes. Fargate eliminates EC2 instance management entirely. For only three services with straightforward networking, Kubernetes abstractions add in significant costs without proportional value.

Rejected alternatives:
- **EKS with Fargate:** $73/mo control plane and complex IAM setup.
- **EKS with managed node groups:** $70/mo control plane + EC2 costs with significant admin overhead.
- **ECS on EC2:** Requires EC2 instance management.

Reevaluation can occur if service count rises or if compatibility with other cloud service providers is needed in the future.

## Status

Accepted (29DEC2025). 

## Consequences

- $73/month saved by avoiding the EKS control plane.
- Fargate Spot available for cost-tolerant workloads (see ADR-002).
- Cloudmap needed for service to service communication.
