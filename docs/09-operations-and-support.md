# 9. Operations and Support

## 9.1 Monitoring Setup

### 9.1.1 Observability Approach
The platform monitors latency, traffic, errors, and saturation across all layers through CloudWatch. 

### 9.1.2 Key Metrics by Signal

**Latency:**

| Component | Metric | Target |
|---|---|---|
| API Gateway p50 | IntegrationLatency | < 200ms |
| API Gateway p99 | IntegrationLatency | < 1,000ms |
| Kinesis consumer lag | IteratorAgeMilliseconds | < 1,000ms |
| DynamoDB read/write latency | SuccessfulRequestLatency | < 10ms |
| SSE event delivery (end-to-end) | Custom metric | < 500ms |
| Signing Proxy duration | Duration | < 5,000ms |

**Traffic:**

Kinesis Records/sec, API Gateway requests/min, SSE active connections, SQS messages enqueued/min, and CloudFront requests/min.

**Errors:**

| Component | Metric | Alarm Threshold |
|---|---|---|
| Lambda invocation errors | Errors | > 5 in 5 minutes |
| API Gateway 5xx rate | 5XXError | > 1% of requests |
| API Gateway 4xx rate | 4XXError | > 10% of requests |
| ECS task count mismatch | RunningTaskCount < DesiredTaskCount | Any mismatch |
| SQS DLQ depth | ApproximateNumberOfMessagesVisible | > 0 |
| Signing Proxy errors | Errors | > 10 in 5 minutes |

**Saturation:**

| Component | Metric | Alarm Threshold |
|---|---|---|
| Redis memory | DatabaseMemoryUsagePercentage | > 80% |
| Redis CPU | EngineCPUUtilization | > 70% |
| ECS CPU/memory | CPUUtilization / MemoryUtilization | > 80% sustained |
| Lambda concurrency | ConcurrentExecutions | > 80% of account limit |

### 9.1.3 Dashboards
Three CloudWatch dashboards are maintained: an **Operations Dashboard** covering traffic, latency, errors, and saturation across all services; a **Security Dashboard** covering CloudTrail alarms, GuardDuty findings, unauthorized API calls, and Signing Proxy activity; and a **Cost Dashboard** covering Fargate vCPU hours, Lambda invocations and duration, DynamoDB capacity units, and S3 storage by bucket.

### 9.1.4 Structured Logging
All services emit structured JSON logs with consistent fields: `timestamp`, `level`, `service`, `correlationId`, `message`, and a `context` object with operation-specific detail. Raw VINs, secrets, and tokens are never logged. Request/response bodies are logged at DEBUG level only with sensitive fields redacted. A `correlationId` is propagated across API Gateway, Lambda, the Fleet Consumer, and the SSE Server, enabling a single telemetry event to be traced end-to-end through the pipeline.

---

## 9.2 Alerting Configuration

### 9.2.1 Severity Levels

| Severity | Response Time | Channel | Examples |
|---|---|---|---|
| Critical | Immediate | SNS → Email/SMS | Root account usage, KMS key deletion, VIN mapping access |
| High | < 30 minutes | SNS → Email | IAM policy changes, Signing Proxy error spike |
| Medium | < 4 hours | SNS → Email | Unauthorized API calls, DLQ messages |
| Low | Next business day | Dashboard review | Elevated latency below threshold |

All alarms default to a 5-minute period, 1 evaluation period, 1 datapoint to alarm, and `notBreaching` for missing data.

### 9.2.2 Signing Proxy Alarms
The Signing Proxy has dedicated alarms due to its security-sensitive role:

| Alarm | Threshold | Rationale |
|---|---|---|
| High error rate | > 10 errors in 5 min | Potential OEM API issue or SSRF attempt |
| Unusual invocation rate | > 1,000 invocations in 5 min | Potential automated abuse |
| Throttling | > 0 throttles | Concurrency limit reached |
| High duration | Average > 5,000ms | OEM API latency degradation |

### 9.2.3 Log Retention

| Source | Destination | Retention |
|---|---|---|
| ECS services and Lambda functions | CloudWatch Logs | 14 days |
| API Gateway access logs | CloudWatch Logs | 14 days |
| VPC Flow Logs | CloudWatch Logs | 90 days |
| CloudTrail | S3 + CloudWatch Logs | 365 days |
| S3 access logs | S3 (logs bucket) | 90 days |

---

## 9.3 Maintenance Procedures

Operational runbooks are maintained in `ops/runbooks/` and cover the following scenarios:

| Runbook | Scenario |
|---|---|
| `ecs-task-failure.md` | ECS task failure diagnosis and mitigation |
| `kinesis-consumer-lag.md` | Processing delays and recovering via backlog |
| `security-incident.md` | Security incident procedures |



