# 5. Security and Compliance
## 5.1 Data Classification

#### 5.1.1 Restricted Data
Data classified as Restricted are certain to cause severe harm to customers, the organization, and poses a serious risk to vehicles if disclosed or altered without authorization.
#### 5.1.2 Confidential Data
Confidential data include operational or user data that could cause moderate privacy and security risk if exposed.


#### 5.1.4 Data Classification Assignments
| Asset | Classification |
|------|----------------|
| OAuth tokens | Restricted |
| VIN (PII) | Restricted |
| Kinesis stream data | Restricted |
| Secrets (API keys, credentials) | Restricted |
| Dashcam footage (PII) | Restricted |
| Vehicle state / telemetry data | Confidential |
| Historic trip data | Confidential |
| Vehicle alerts | Confidential |
| Error / connectivity metrics | Confidential |
| Security events | Confidential |
| Security configuration (settings, geofences) | Confidential |
| Fleet organizations / users | Confidential |
| Fleet drivers and assignments | Confidential |
| Maintenance records and alerts | Confidential |
| Fleet reports and report archives | Confidential |
| Command audit logs | Confidential |
| Telemetry archive | Confidential |

---
## 5.2 Security Controls

### 5.2.1 VIN Pseudonymization
Vehicles connect via mTLS and transmit events containing raw VINs through the Telemetry Server to Kinesis unmodified. The Consumer then pseudonymizes each VIN using an HMAC-SHA256 key stored in Secrets Manager. All downstream data stores use only the pseudoVIN, with the sole exception being the heavily secured and audited `vin-mapping` DynamoDB table. Raw VIN exposure is confined entirely to the ingestion layer.

### 5.2.2 Network Security and Service Authentication
All application workloads run in private subnets, with only the NLB and NAT Gateways occupying public subnets. VPC Gateway Endpoints are used for S3 and DynamoDB to keep traffic off the public internet. The platform operates within a multi-account AWS Organization separating the management account from environment accounts. At the edge, WAF enforces a limit of 500 requests per 5 minutes per IP, applies AWS Managed Rules for common exploit protection, and geoblocks traffic outside North America. SQS dead-letter queues prevent processing path congestion. Within the network, the Telemetry Server authenticates vehicles using mTLS with certificates stored in Secrets Manager. All user-facing requests are validated by Cognito JWT authorizers at API Gateway, outbound OEM requests are signed by the Secure Signing Proxy using a trusted private key, and ECS services discover each other via Cloud Map private DNS.

### 5.2.3 Secrets & Parameter Management
Secrets Manager is reserved for sensitive credentials such as private keys, client ID/secrets, TLS cert/keys, and the VIN HMAC key. Each resource is granted minimal IAM permissions to retrieve only the exact secret it requires. SSM Parameter Store handles non-sensitive application configuration at lower operational cost.

### 5.2.4 Logging and Audit Trails
CloudTrail captures all AWS API activity and stores trails in S3 for one year. Metric filters target sensitive operations including VIN mapping table access, root account usage, IAM and S3 policy changes, and KMS modifications, each with corresponding CloudWatch alarms publishing to SNS. Every vehicle command is written to a `command-audit` DynamoDB table with a 90-day TTL. GuardDuty runs with VPC Flow Log analysis, forwarding critical findings to SNS, while CloudWatch monitors command signer error rates, traffic spikes, and anomalies.

### 5.2.5 Data Retention and Deletion
Telemetry data transitions to Glacier IR at 90 days and expires at 365 days. Original dashcam footage expires after 7 days, while compressed versions are retained with tiered storage through 60 days. CloudTrail logs expire at 365 days. DynamoDB TTLs automatically purge breadcrumbs, alerts, vehicle telemetry events (errors, connectivity, metrics), command audit entries, and invitation tokens at 90 days. Application logs are retained for 14 days, VPC flow logs for 90 days, and ECR retains only the last 5 images.

---

## 5.3 Identity and Access Management

### 5.3.1 Authentication and JWT Claims
Cognito issues JWT tokens validated by API Gateway authorizers. A pre-token Lambda trigger injects custom claims such as account role and organization into the ID token at mint-time. Access to sensitive resources like dashcam media requires a short-lived, resource-scoped token issued by the Token Generator after verifying vehicle ownership, validated by a custom request authorizer with a 5-minute cache. CloudFront signed URLs provide the same ownership-gated access for S3-delivered content. All ECS and Lambda resources are scoped to the minimum required IAM permissions for their specific S3, DynamoDB, Secrets, SSM, SQS, and ECR resources.

### 5.3.2 Role-Based Access Control (RBAC)
A Lambda API function enforces five roles — owner, admin, manager, driver, and viewer — with DynamoDB data partitioned by `organizationId` to enforce tenant boundaries.

### 5.3.3 Dual-Person Access Controls
IAM boundary policies are assigned to IAM administrators to prevent full admin access and privilege escalation, and SCPs require MFA for destructive actions such as terminating instances or deleting data stores. Dual-person access for sensitive data — splitting `DecryptKMS` and `GetObject` permissions across separate team members — is planned but not yet implemented.

---

## 5.4 Encryption Strategy

### 5.4.1 Encryption at Rest and In Transit
Sensitive S3 buckets (telemetry, dashcam, reports) use dedicated KMS Customer Managed Keys with bucket keys and automatic rotation. Kinesis uses KMS-managed encryption. All other S3 buckets use AES-256 SSE-S3, DynamoDB uses default encryption, and Secrets Manager handles its own service-native encryption. In transit, TLS is enforced at CloudFront, API Gateway, and NLB, while the Telemetry Server exclusively accepts mTLS connections.


