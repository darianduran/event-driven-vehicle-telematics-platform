# 8. Implementation Plan

## 8.1 Deployment Strategy

### 8.1.1 Pipeline Architecture

Two independent pipelines (infrastructure changes are infrequent/high-risk; app changes ship continuously):

**Infrastructure (Terraform):** Lint/format → validate → tflint → tfsec/checkov → plan (saved to artifact) → manual approval → apply from saved plan → smoke tests.

**Application (Containers + Lambda):** Unit tests → build → push to ECR/S3 → auto-deploy to dev → integration tests → manual approval → rolling deploy to prod → health checks.

### 8.1.2 Deployment Strategies

| Component | Strategy | Details |
|---|---|---|
| ECS Services | Rolling update | Min healthy 100%, max 200%. Health check grace 60s, deregistration delay 30s. |
| Lambda | Artifact replacement | Rollback by redeploying previous package. |
| Frontend (S3 + CloudFront) | Sync + invalidation | Propagates globally in 5-10 min. |

---

## 8.2 Release Management

### 8.2.1 Environment Parity

Same Terraform modules, different variables:

| Config | Dev | Prod |
|---|---|---|
| NAT | Instance (t4g.nano, ~$3/mo) | Gateway (Multi-AZ, ~$68/mo) |
| ECS desired count | 1 per service | 2+ (Multi-AZ) |
| Deletion protection | Disabled | Enabled |
| GuardDuty | Dashboard only | SNS alerting |
| WAF mode | Count (observe) | Block (enforce) |
| CloudTrail | Enabled | Enabled + S3 data events |
| Log retention | 14 days | 14d app, 90d VPC, 365d audit |

### 8.2.2 Secrets Rotation

| Secret | Rotation | Impact |
|---|---|---|
| TLS cert + key | Manual (OEM coordinated) | ECS restart |
| OEM API keys | Manual (OEM policy) | Signing Proxy restart |
| Cognito client secret | Via Cognito console/API | App client update |
| Session encryption secret | Manual | Active sessions invalidated |
| HMAC pseudonymization key | Manual | Rotations require access to `vin-mapping` table and pseudonymization of rawVin and update of the psuedoVin across all tables |

### 8.2.3 Rollback

| Component | Procedure |
|---|---|
| ECS | Redeploy previous task definition revision |
| Lambda | Redeploy previous zip via `update-function-code` |
| Terraform | Revert in Git → `terraform plan` → apply |
| Frontend | Sync previous build to S3 → CloudFront invalidation |

