# 10. Cost Analysis

> All pricing reflects AWS us-east-1 (N. Virginia) published rates as of early 2026. Estimates exclude free tier credits. Costs are modeled at three fleet sizes to demonstrate how the architecture scales economically.

---

## 10.1 Fleet Size Assumptions

| Parameter | Small (1K vehicles) | Medium (5K vehicles) | Large (10K vehicles) |
|---|---|---|---|
| Connected vehicles | 1,000 | 5,000 | 10,000 |
| Telemetry events/sec (avg) | ~500 | ~2,500 | ~5,000 |
| Event payload size | ~1 KB | ~1 KB | ~1 KB |
| Avg trips/vehicle/day | 2 | 2 | 2 |
| Avg trip duration | 25 min | 25 min | 25 min |
| Dashboard MAUs | 200 | 800 | 1,500 |
| API requests/day | ~100K | ~400K | ~800K |
| Dashcam uploads/day | 50 clips (~50 MB each) | 200 clips | 500 clips |

---

## 10.2 Production Cost Breakdown

### 10.2.1 Compute — ECS Fargate

Fargate pricing: $0.04048/vCPU-hour, $0.004445/GB-hour. Fargate Spot: ~70% discount.

| Service | vCPU | Memory | Tasks | Spot | Monthly Cost |
|---|---|---|---|---|---|
| Telemetry Server | 0.5 | 1 GB | 2 | No | 2 x ((0.5 x $0.04048) + (1 x $0.004445)) x 730 = **$36** |
| Telemetry Consumer | 1 | 2 GB | 2 | No | 2 x ((1 x $0.04048) + (2 x $0.004445)) x 730 = **$72** |
| SSE Service | 0.25 | 0.5 GB | 2 | Yes | 2 x ((0.25 x $0.04048) + (0.5 x $0.004445)) x 730 x 0.30 = **$6** |

**Fargate subtotal: ~$114/mo** (scales linearly with added tasks)

| Fleet Size | Est. Tasks | Est. Fargate Cost |
|---|---|---|
| 1K vehicles | 3 tasks (1 each) | ~$57 |
| 5K vehicles | 5 tasks | ~$100 |
| 10K vehicles | 6 tasks (2+2+2) | ~$114 |

### 10.2.2 Streaming — Kinesis Data Streams

Kinesis on-demand standard pricing: $0.080/GB ingested, $0.040/GB retrieved, $0.04/stream-hour.

| Fleet Size | Ingest Rate | Monthly Ingest GB | Monthly Cost |
|---|---|---|---|
| 1K | ~0.5 MB/s | ~1,300 GB | Stream: $29 + Ingest: $104 + Retrieval: $52 = **~$185** |
| 5K | ~2.5 MB/s | ~6,500 GB | Stream: $29 + Ingest: $520 + Retrieval: $260 = **~$809** |
| 10K | ~5 MB/s | ~13,000 GB | Stream: $29 + Ingest: $1,040 + Retrieval: $520 = **~$1,589** |

7-day extended retention adds $0.020/shard-hour. On-demand auto-provisions shards; at 5 MB/s this is roughly 5 shards:

| Fleet Size | Extended Retention |
|---|---|
| 1K | ~$1.50/mo |
| 5K | ~$7/mo |
| 10K | ~$15/mo |

> Kinesis is the single largest fixed-rate cost driver at scale. At 10K vehicles, consider Kinesis on-demand Advantage mode ($0.032/GB ingest, $0.016/GB retrieval) which would reduce this by around 60%.


### 10.2.3 Database — DynamoDB

On-demand pricing: $1.25/million WRUs, $0.25/million RRUs (eventually consistent). Storage: $0.25/GB-month.

The consumer writes only state changes, trip events, alerts, and periodic snapshots trigger DynamoDB writes. A realistic write amplification factor is ~15% of raw telemetry events:

| Fleet Size | Realistic Writes/mo | Write Cost | Read Cost | Storage | **Monthly Total** |
|---|---|---|---|---|---|
| 1K | ~195M | $244 | $98 | $13 | **~$355** |
| 5K | ~975M | $1,219 | $488 | $50 | **~$1,757** |
| 10K | ~1.95B | $2,438 | $975 | $100 | **~$3,513** |

**Capacity Mode Strategy:**

DynamoDB on-demand mode is the correct default for this architecture. It requires zero capacity planning, handles unpredictable traffic spikes (vehicle reconnection storms, fleet onboarding bursts), and aligns with the platform's minimal operational overhead requirement (BR-8). Below ~5K vehicles, the operational simplicity of on-demand outweighs the cost premium.

However, telemetry  produces highly predictable write patterns vehicle count × events/sec is near-constant during operating hours. As the fleet grows beyond 5K vehicles and traffic patterns stabilize, provisioned capacity with auto-scaling becomes the recommended path:

| Fleet Size | Recommended Mode | Rationale |
|---|---|---|
| < 5K | On-demand | Traffic patterns still maturing, operational simplicity prioritized |
| 5K–10K | Evaluate provisioned | Predictable baselines established, 20–30% savings available |
| > 10K | Provisioned + auto-scaling | Cost savings of $700–$1,050/mo justify the added configuration |

Provisioned mode with auto-scaling at 10K vehicles (targeting 70% utilization with scale-up/down policies) would reduce DynamoDB costs from ~$3,513 to approximately **~$2,460–$2,810/mo**, a 20–30% reduction. The auto-scaling configuration adds minimal operational complexity since target tracking policies handle capacity adjustments automatically.

### 10.2.4 Caching — ElastiCache Redis

| Fleet Size | Node Type | Nodes | Monthly Cost |
|---|---|---|---|
| 1K | cache.t4g.micro | 1 | **~$12** |
| 5K | cache.t4g.micro | 2 (Multi-AZ) | **~$24** |
| 10K | cache.t4g.small | 2 (Multi-AZ) | **~$48** |

### 10.2.5 Networking

**NAT Gateway** (Prod Multi-AZ = 2 gateways):

| Component | Calculation | Monthly Cost |
|---|---|---|
| Hourly (2 gateways) | 2 x $0.045 x 730 hrs | $65.70 |
| Data processing (est. 50 GB/mo through NAT) | 50 x $0.045 | $2.25 |
| **NAT subtotal** | | **~$68** |

> Gateway endpoints for S3 and DynamoDB are free and handle the bulk of data traffic, keeping NAT processing costs minimal.

**NLB:**

| Component | Calculation | Monthly Cost |
|---|---|---|
| Hourly | $0.0225 x 730 hrs | $16.43 |
| NLCU (est. low utilization) | | ~$5 |
| **NLB subtotal** | | **~$22** |

**Kinesis Interface Endpoint** (2 AZs):

| Component | Calculation | Monthly Cost |
|---|---|---|
| Hourly | 2 x $0.01 x 730 hrs | $14.60 |
| Data (est. 100 GB) | 100 x $0.01 | $1.00 |
| **Endpoint subtotal** | | **~$16** |

**Networking total: ~$106/mo**


### 10.2.6 Serverless Compute — Lambda

Lambda pricing: $0.20/million requests, $0.0000166667/GB-second.

| Function | Memory | Avg Duration | Invocations/mo (10K) | Monthly Cost |
|---|---|---|---|---|
| Trip Processor | 512 MB | 2s | ~600K | **~$20** |
| Geofence Evaluator | 256 MB | 200ms | ~2M | **~$2** |
| Signing Proxy (Go) | 128 MB | 100ms | ~300K | **~$1** |
| Token Generator | 128 MB | 50ms | ~500K | **~$1** |
| Token Authorizer | 128 MB | 10ms | ~2M (cached 5min) | **~$1** |
| API Functions (misc) | 256 MB | 100ms | ~1M | **~$1** |
| Dashcam Processor | 1024 MB | 5s | ~15K | **~$2** |
| Pre-token Trigger | 128 MB | 50ms | ~100K | **~$1** |
| **Lambda subtotal** | | | | **~$29** |

### 10.2.7 API Layer

**API Gateway** (REST API): $3.50/million requests

| Fleet Size | Requests/mo | Monthly Cost |
|---|---|---|
| 1K | ~3M | **~$11** |
| 5K | ~12M | **~$42** |
| 10K | ~24M | **~$84** |

**Cognito** (Lite tier): First 10,000 MAUs free

| Fleet Size | MAUs | Monthly Cost |
|---|---|---|
| 1K | 200 | **$0** (free tier) |
| 5K | 800 | **$0** (free tier) |
| 10K | 1,500 | **$0** (free tier) |

### 10.2.8 Edge and CDN

**CloudFront:** $0.085/GB (first 10 TB to NA/EU), $0.0075/10K HTTPS requests

| Fleet Size | Data Transfer | Requests/mo | Monthly Cost |
|---|---|---|---|
| 1K | ~5 GB | ~1M | **~$1** |
| 5K | ~20 GB | ~4M | **~$5** |
| 10K | ~50 GB | ~10M | **~$12** |

**WAF:** $5/Web ACL + $1/rule + $0.60/million requests

| Component | Monthly Cost |
|---|---|
| 1 Web ACL | $5 |
| ~5 rules (incl. managed rule groups) | $8 |
| Request inspection (10K: ~35M req/mo) | $21 |
| **WAF subtotal** | **~$34** |

### 10.2.9 Storage — S3

S3 Standard: $0.023/GB-month. PUT: $0.005/1K requests. GET: $0.0004/1K requests.

| Bucket | Est. Storage (10K) | Monthly Cost |
|---|---|---|
| Telemetry archives | ~100 GB | **~$4** |
| Dashcam | ~750 GB raw + compressed | **~$18** |
| Fleet reports | ~10 GB | **~$1** |
| CloudTrail logs | ~5 GB | **~$1** |
| Frontend assets | ~1 GB | **~$1** |
| **S3 subtotal** | | **~$25** |

> Lifecycle policies transition data to Intelligent-Tiering and Glacier IR over time, reducing long-term storage costs by ~80%.

### 10.2.10 Messaging — SQS & SNS

SQS Standard: $0.40/million requests. SNS: $0.50/million publishes, $0.06/100K HTTP notifications.

| Service | Est. Requests/mo (10K) | Monthly Cost |
|---|---|---|
| SQS (alert queue, DLQs) | ~5M | **~$2** |
| SNS (alert fan-out, notifications) | ~2M publishes | **~$2** |
| **Messaging subtotal** | | **~$4** |

### 10.2.11 Security & Encryption

**KMS:** $1/key/month, $0.03/10K requests

| Component | Monthly Cost |
|---|---|
| 2 CMKs (data + telemetry) | $2 |
| API requests (~1.5M/mo at 10K fleet) | ~$4 |
| **KMS subtotal** | **~$6** |

**Secrets Manager:** $0.40/secret/month, $0.05/10K API calls

| Component | Monthly Cost |
|---|---|
| ~5 secrets (DB creds, API keys, tokens) | $2 |
| API calls (~50K/mo) | ~$0.25 |
| **Secrets Manager subtotal** | **~$2** |

**Security subtotal: ~$8/mo**


### 10.2.12 Observability & Audit

| Service | Pricing Basis | Est. Usage (10K) | Monthly Cost |
|---|---|---|---|
| CloudWatch Logs | $0.50/GB ingestion | ~15 GB | **~$8** |
| CloudWatch Metrics | $0.30/metric (first 10K) | ~30 custom metrics | **~$9** |
| CloudWatch Alarms | $0.10/standard alarm | ~30 alarms | **~$3** |
| CloudWatch Dashboards | $3.00/dashboard | 3 dashboards | **~$9** |
| CloudTrail | 1st mgmt trail free; data events $0.10/100K | ~500K data events | **~$5** |
| GuardDuty | ~$1/GB VPC Flow Logs (first 500 GB) | ~10 GB flow logs | **~$10** |
| **Observability subtotal** | | | **~$44** |

### 10.2.13 AI/ML — Amazon Bedrock (Optional)

Claude Haiku 3.5 pricing: $0.80/million input tokens, $4.00/million output tokens.

Used for natural-language fleet queries and anomaly summarization. Token estimates assume ~500 input tokens and ~200 output tokens per query:

| Fleet Size | Queries/mo | Input Tokens | Output Tokens | Monthly Cost |
|---|---|---|---|---|
| 1K | ~50K | 25M | 10M | Input: $20 + Output: $40 = **~$60** |
| 5K | ~200K | 100M | 40M | Input: $80 + Output: $160 = **~$240** |
| 10K | ~500K | 250M | 100M | Input: $200 + Output: $400 = **~$600** |

> Bedrock is entirely optional and can be disabled without affecting core platform functionality. Costs scale linearly with query volume and can be capped with usage quotas.

### 10.2.14 Other Services

| Service | Details | Monthly Cost |
|---|---|---|
| ECR | ~5 container images, ~2 GB storage | **~$1** |
| Cloud Map | Service discovery, ~10 instances | **~$1** |
| EventBridge | ~2M events/mo | **~$2** |
| Route 53 | 1 hosted zone + queries | **~$2** |
| Amazon Location Service | Geofence evaluations (~2M/mo) | **~$3** |
| **Other subtotal** | | **~$9** |

---

## 10.3 Monthly Cost Summary

### Without Bedrock AI

| Service Category | 1K Vehicles | 5K Vehicles | 10K Vehicles |
|---|---|---|---|
| ECS Fargate | $57 | $100 | $114 |
| Kinesis Data Streams | $187 | $816 | $1,604 |
| DynamoDB | $355 | $1,757 | $3,513 |
| ElastiCache Redis | $12 | $24 | $48 |
| Networking | $106 | $106 | $106 |
| Lambda | $10 | $20 | $29 |
| API Gateway | $11 | $42 | $84 |
| Cognito | $0 | $0 | $0 |
| CloudFront | $1 | $5 | $12 |
| WAF | $20 | $27 | $34 |
| S3 | $8 | $15 | $25 |
| SQS & SNS | $2 | $3 | $4 |
| Security (KMS + Secrets) | $5 | $6 | $8 |
| Observability & Audit | $30 | $37 | $44 |
| Other Services | $9 | $9 | $9 |
| **Total (without Bedrock)** | **~$813** | **~$2,967** | **~$5,634** |
| **Per vehicle/month** | **~$0.81** | **~$0.59** | **~$0.56** |

### With Bedrock AI

| Fleet Size | Base Cost | Bedrock Cost | **Total** | **Per Vehicle** |
|---|---|---|---|---|
| 1K | $813 | $60 | **~$873** | **~$0.87** |
| 5K | $2,967 | $240 | **~$3,207** | **~$0.64** |
| 10K | $5,634 | $600 | **~$6,234** | **~$0.62** |

> Per-vehicle cost decreases at scale because fixed costs (networking, WAF, observability, base Fargate) are amortized across more vehicles. The architecture achieves ~31% cost efficiency improvement from 1K to 10K vehicles.


---

## 10.4 Cost Drivers Analysis

At the 10K vehicle tier, the top cost drivers are:

| Rank | Service | Monthly Cost | % of Total |
|---|---|---|---|
| 1 | DynamoDB | $3,513 | 62.3% |
| 2 | Kinesis Data Streams | $1,604 | 28.5% |
| 3 | ECS Fargate | $114 | 2.0% |
| 4 | Networking | $106 | 1.9% |
| 5 | API Gateway | $84 | 1.5% |
| | All other services | $213 | 3.8% |

DynamoDB and Kinesis together account for ~91% of total costs. This concentration means optimization efforts should focus almost exclusively on these two services for maximum impact.

---

## 10.5 Cost Optimization Roadmap

Cost optimization is staged to match fleet growth. At smaller fleet sizes, operational simplicity is prioritized over cost savings. As the fleet scales and traffic patterns stabilize, progressively more aggressive optimizations become justified.

### Phase 1: Launch (< 5K vehicles)

No optimization required. On-demand pricing for both DynamoDB and Kinesis provides zero-config scaling and absorbs traffic variability from fleet onboarding, vehicle reconnection storms, and seasonal patterns. The cost premium over provisioned modes is modest at this scale and is offset by reduced operational burden.

### Phase 2: Growth (5K–10K vehicles)

| Optimization | Target Service | Est. Savings | Complexity |
|---|---|---|---|
| Switch to DynamoDB provisioned capacity with auto-scaling | DynamoDB | 20–30% (~$350–$530/mo at 5K) | Medium |
| Enable Kinesis on-demand Advantage mode | Kinesis | ~60% (~$485/mo at 5K) | Low |
| Compute Savings Plans (1-yr, no upfront) | Fargate + Lambda | ~30% (~$35/mo) | Low |
| Reserved ElastiCache nodes (1-yr) | ElastiCache | ~30% (~$7/mo) | Low |

At this phase, DynamoDB provisioned mode becomes the highest-impact change. Fleet telemetry produces highly predictable write patterns vehicle count × events/sec is near-constant during operating hours making auto-scaling target tracking policies effective with minimal tuning. Configure auto-scaling at 70% target utilization with scale-up at 3 minutes and scale-down at 15 minutes to handle daily traffic curves.

### Phase 3: Scale (> 10K vehicles)

| Optimization | Target Service | Est. Savings | Complexity |
|---|---|---|---|
| DynamoDB provisioned + auto-scaling (if not already) | DynamoDB | 20–30% (~$700–$1,050/mo at 10K) | Medium |
| Kinesis Advantage mode (if not already) | Kinesis | ~60% (~$950/mo at 10K) | Low |
| Batch DynamoDB writes (BatchWriteItem) | DynamoDB | 5–10% additional WRU reduction | Medium |
| Set Bedrock usage quotas and prompt caching | Bedrock | Prevents runaway costs | Low |
| S3 Intelligent-Tiering for archives | S3 | ~40% on aged data (~$5/mo) | Low |
| Consolidate CloudWatch dashboards | Observability | ~$6/mo | Low |

**Maximum optimized cost at 10K vehicles:** Applying DynamoDB provisioned mode and Kinesis Advantage mode alone reduces the monthly total from ~$5,634 to approximately **~$3,734/mo** (~$0.37/vehicle) a 34% reduction with minimal added operational complexity.

---

## 10.6 Environment Cost Comparison

The architecture supports a minimal development environment for testing and iteration:

| Component | Production (10K) | Development | Notes |
|---|---|---|---|
| ECS Fargate | $114 (6 tasks) | ~$19 (1 task each, Spot) | All services on Spot, minimum tasks |
| Kinesis | $1,604 (on-demand) | ~$30 (provisioned, 1 shard) | Provisioned mode for dev |
| DynamoDB | $3,513 (on-demand) | ~$25 (provisioned, 5 WCU/5 RCU) | Minimal provisioned capacity |
| ElastiCache | $48 | ~$12 (single t4g.micro) | No Multi-AZ |
| Networking | $106 | ~$35 (1 NAT, no NLB) | Single-AZ, direct connect |
| Lambda | $29 | ~$5 | Minimal invocations |
| API Gateway | $84 | ~$4 | Low traffic |
| Observability | $44 | ~$15 | Fewer metrics, 1 dashboard |
| Other | $92 | ~$25 | Reduced across the board |
| **Total** | **~$5,634** | **~$170** | **97% reduction** |

> A development environment costs approximately $170/mo, making it practical to maintain persistent dev/staging environments without significant budget impact.

---

## 10.7 Pricing References

All estimates are based on published AWS pricing pages for us-east-1 as of early 2026:

| Service | Pricing Page |
|---|---|
| ECS Fargate | https://aws.amazon.com/fargate/pricing/ |
| Kinesis Data Streams | https://aws.amazon.com/kinesis/data-streams/pricing/ |
| DynamoDB | https://aws.amazon.com/dynamodb/pricing/on-demand/ |
| ElastiCache | https://aws.amazon.com/elasticache/pricing/ |
| Lambda | https://aws.amazon.com/lambda/pricing/ |
| API Gateway | https://aws.amazon.com/api-gateway/pricing/ |
| S3 | https://aws.amazon.com/s3/pricing/ |
| CloudFront | https://aws.amazon.com/cloudfront/pricing/ |
| WAF | https://aws.amazon.com/waf/pricing/ |
| NAT Gateway | https://aws.amazon.com/vpc/pricing/ |
| SQS | https://aws.amazon.com/sqs/pricing/ |
| SNS | https://aws.amazon.com/sns/pricing/ |
| KMS | https://aws.amazon.com/kms/pricing/ |
| Secrets Manager | https://aws.amazon.com/secrets-manager/pricing/ |
| Cognito | https://aws.amazon.com/cognito/pricing/ |
| CloudWatch | https://aws.amazon.com/cloudwatch/pricing/ |
| Bedrock | https://aws.amazon.com/bedrock/pricing/ |
| Amazon Location | https://aws.amazon.com/location/pricing/ |