# 7. Business Continuity and Disaster Recovery

## 7.1 Backup Strategy

| Component | Strategy | Notes |
|---|---|---|
| DynamoDB (21 tables) | Tables configured with 35 day point in time recovery and deletion protection. | - |
| S3 | Versioning and Deletion Protection | Cross region replication planned for future expansions |
| Kinesis | 7-day retention | - |
| Secrets Manager | Secure Offline (On-premises) Backup | - |

S3 lifecycle policies:

| Bucket | Lifecycle |
|---|---|
| Telemetry | 90d Intelligent Tiering / 365d Glacier IR |
| Dashcam | Original footage retained for 7 days and then deleted / Compressed footage retained for 90d then 180d Glacier IR |
| Fleet Reports | 90d Intelligent Tiering / 365d → Glacier IR |
| CloudTrail | 90d Glacier IR / 365d expire |

---

## 7.2 Failover Procedures

| Failure | Auto-Recovery | During Outage | Manual Action |
|---|---|---|---|
| ECS task | ECS replaces unhealthy task | Vehicles reconnect, Kinesis buffers, Browser fallsback to polling | Investigate crash via CloudWatch logs |
| Redis node | ElastiCache replaces node (DNS unchanged) | SSE fails, Browser clients fallback to polling DynamoDB directly, all other workflows unaffected | None — Redis and SSE autorecover |
| Kinesis consumer lag | Consumer resumes from checkpoint | Real-time data delayed, historical data unaffected | Scale ECS tasks out |

### 7.3.1 Full Region Failure (us-east-1 to us-west-2)

Manual failover. Dual region expansion for production environment planned as operations scale.

| Step | Duration |
|---|---|
| Terraform apply | ~30 min |
| DynamoDB PITR restore | ~2 hours |
| Application deployment | ~15 min |
| **Total** | **~2–4 hours** |

### 7.3.2 Graceful Degradation

| Failed Component | Impact | 
|---|---|
| Redis | SSE fails, Browser fallsback to DDB polling in 5s | 
| Kinesis Consumer lag | Real-time processing degraded, no data loss |
| Single Lambda | Feature unavailable, SQS buffers jobs and DLQ captures failed jobs |
| API Gateway | REST/OAuth unavailable, dashboard and telemetry continue to function |
| Full region | All services down, manual failover to us-west-2 required |


