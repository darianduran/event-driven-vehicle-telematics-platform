# 7. Performance and Scalability

---

## 7.1 Performance SLAs

| Metric | Target | Measurement |
|---|---|---|
| API response latency | < 1 second | API Gateway to client |
| DynamoDB write latency | < 5 seconds | Vehicle event to DynamoDB write |
| Dashboard update latency | < 3 seconds | Vehicle event to browser timeframe |
| Trip detection latency | < 30 seconds | Drive state change to trip record creation |
| Vehicle command round-trip | < 10 seconds | User action to OEM API response |

---

## 7.2 Scalability Approach

### 7.2.1 Telemetry Ingestion (Kinesis)
Kinesis on-demand mode auto-provisions shards based on throughput. Records are retained for 7 days as a crash-recovery buffer.

### 7.2.2 Database (DynamoDB)
All 21 tables use PAY_PER_REQUEST billing, scaling automatically to 40,000 RCU/WCU per table by default. 

### 7.2.3 Compute (ECS Fargate)

| Service | CPU | Memory | Steady Load (10K fleet) | Scaling Trigger |
|---|---|---|---|---|
| Telemetry Server | 512 | 1024 MB | ~30% CPU | > 70% CPU for 5 min |
| Telemetry Consumer | 1024 | 2048 MB | ~50% CPU | > 70% CPU for 5 min |
| SSE Service | 256 | 512 MB | ~40% CPU per 1K connections | > 70% CPU for 5 min |

The Telemetry Consumer is the most compute-intensive service due to batch processing across Kinesis, DynamoDB, Redis, and S3. 


