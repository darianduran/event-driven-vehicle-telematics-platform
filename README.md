# Event Driven Vehicle Telematics Platform (AWS Reference Architecture)
> Author: Darian Duran | [LinkedIn](https://linkedin.com/in/darianduran)

---

This reference architecture demonstrates the design and deployment of a near real-time vehicle telematics platform on AWS. The architecture is capable of ingesting and processing thousands of events per second with subsecond latency. The platform is roled based and provides two different dashboards tailored to fleet operations and personal owners.

---

## Table of Contents
- [Event Driven Vehicle Telematics Platform (AWS Reference Architecture)](#event-driven-vehicle-telematics-platform-aws-reference-architecture)
  - [Table of Contents](#table-of-contents)
  - [1. Use Case](#1-use-case)
  - [2. System Context \& High Level Architecture](#2-system-context--high-level-architecture)
    - [C4 Level 1 — System Context](#c4-level-1--system-context)
    - [High-Level AWS Architecture](#high-level-aws-architecture)
  - [3. Key Design Highlights](#3-key-design-highlights)
  - [4. Cost at Scale](#4-cost-at-scale)
  - [5. Installation Prerequisites](#5-installation-prerequisites)
    - [AWS Account Setup](#aws-account-setup)
  - [6. Installation](#6-installation)
    - [Bootstrap Remote State](#bootstrap-remote-state)
    - [Deploy Environment](#deploy-environment)
    - [Build and Push Container Images](#build-and-push-container-images)
    - [Update ECS Services](#update-ecs-services)
  - [7. Deployment Validation](#7-deployment-validation)
  - [8. Repository Structure](#8-repository-structure)
  - [9. Documentation Index](#9-documentation-index)
  - [10. Architecture Decision Records](#10-architecture-decision-records)
  - [11. Cleanup](#11-cleanup)
 
---

## 1. Use Case

| Challenge | Scale |
|---|---|
| High volume data throughput | Solution must be capable of handling up to tens of thousands of events per second at peak demand |
| Processing latency | The solution must be able to provide end to end data processing latency below 1 second |
| Telemetry Translation| The solution must be able to transform vehicle data into actionable use cases such as dashboards, automation, and key insights |
| User security and isolation | Strict security controls to protect user data and vehicles, and enforce isolation between users |

---

## 2. System Context & High Level Architecture

### C4 Level 1 — System Context
![C4 Level 1 - System Context](diagrams/c4-level1-context.png)

### High-Level AWS Architecture
![AWS High-level Diagram](diagrams/high-level-diagram.png)

---

## 3. Key Design Highlights

| Highlight | Summary |
|---|---|
| Subsecond data ingestion | Kinesis data stream ingests telemetry data in real-time |
| Real-time processing | ECS Fargate Consumer pulls from Kinesis and processes to multiple targets in milliseconds |
| Live dashboards | Redis and SSE service provides real-time updates |
| Multi-tenant isolation | Zero trust API request processing and partition key design enforce multi-tenant isolation |
| VIN pseudonymization | HMAC-SHA256 pseudonymizes user PII to minimize potential data exposure |
| Defense-in-depth | Multi layer security control implementation |
| IaC Deployments | Architecture is defined and deployed through reusable Terraform IaC |
| Reliable fallbacks | Backup workflows and workflows implemented to provide safety nets for multiple workflows in case of failure |

---

## 4. Cost at Scale

| Fleet Size | Monthly Cost | Cost Per Vehicle |
|---|---|---|
| 100 vehicles | ~$150 | $1.50 |
| 1,000 vehicles | ~$220 | $0.22 |
| 10,000 vehicles | ~$620 | $0.062 |
| 50,000 vehicles | ~$1,730 | $0.035 |

---

## 5. Installation Prerequisites

### AWS Account Setup
- Create an AWS account and setup AWS Organizations (optional)
- Verify if the account has adequate service quota for utilized services if the account already has resources provisioned.
- Create an IAM user with admin access and create an access key. Install and configure AWS CLI `aws configure`
- Domain registered via Route 53 or an external registrar
- Provision an ACM certificate in `us-east-1` for CloudFront

---

## 6. Installation

### Bootstrap Remote State
```bash
cd iac/bootstrap
terraform init
terraform apply
```

### Deploy Environment
```bash
cd iac/envs/{environment}
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Add your values
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Build and Push Container Images
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

for service in telemetry-server telemetry-consumer sse-server; do
  docker build -t $service ./src/$service
  docker tag $service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/fleet-dev-$service:latest
  docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/fleet-dev-$service:latest
done
```

### Update ECS Services
```bash
for service in telemetry-consumer telemetry-server sse-server; do
  aws ecs update-service \
    --cluster fleet-dev-cluster \
    --service fleet-dev-$service \
    --force-new-deployment
done
```

---

## 7. Deployment Validation
```bash
aws ecs describe-services \
  --cluster fleet-dev-cluster \
  --services fleet-dev-telemetry-consumer fleet-dev-telemetry-server fleet-dev-sse-server \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount,status:status}'
```

---

## 8. Repository Structure

---

## 9. Documentation Index

| Document | What It Covers |
|---|---|
| [Executive Summary](docs/01-executive-summary.md) | An overview of the solution and key objectives |
| [Requirements](docs/02-requirements.md) | Requirements and constraints of the solution |
| [Solution Architecture](docs/03-solutions-architecture.md) | A granular breakdown of different domains within the solution |
| [Technical Design](docs/04-technical-design.md) | Technical breakdown of the architecture |
| [Security & Compliance](docs/05-security-and-compliance.md) | Data classification definition and security controls |
| [Performance & Scalability](docs/06-performance-and-scalability.md) | Estimating capacity and performance |
| [Business Continuity & DR](docs/07-business-continuity-and-dr.md) | Backup and failover details |
| [Implementation Plan](docs/08-implementation-plan.md) | Deployment strategy |
| [Operations & Support](docs/09-operations-andsupport.md) | Observability and operational workflows |
| [Cost Analysis](docs/10-cost-analysis.md) | Service cost breakdown and cost optimization efforts |
| [Appendix A](docs/appendix-a-well-architected-framework.md) | Self-assessment of adherence to well-architected framework and improvement goals |

---

## 10. Architecture Decision Records

| ADR | Decision | Status |
|---|---|---|
| [ADR-001](adrs/001-vin-pseudonymization.md) | Implementing pseudonymization to protect PII | Accepted |
| [ADR-002](adrs/002-fargate-spot-for-sse.md) | Fargate Spot to optimize interruptable workflow | Accepted |
| [ADR-003](adrs/003-fargate-over-eks.md) | ECS Fargate over EKS for container orchestration | Accepted |

---

## 11. Cleanup
```bash
cd iac/envs/prod && terraform destroy
cd iac/envs/dev && terraform destroy
cd iac/bootstrap && terraform destroy
```

> S3 buckets must be manually emptied before applying terraform destroy.
