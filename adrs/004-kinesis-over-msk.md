# ADR 4: Kinesis Data Streams over Amazon MSK

The platform requires a durable, real-time streaming layer to ingest vehicle telemetry data and send it to the Consumer for processing. The stream must handle sustained throughput of thousnads of events per second and have some level of data redundancy in the event data replays are needed. Two managed services that are candidates are Kinesis and Kafka.

## Decision

We will use Kinesis Data Streams as the ingestion stream.

## Rationale

Kinesis on-demand eliminates the need for shard management during early phases of the platform. Capacity scales out and in automatically based on throughput without any need for admin overhead. Given the single consumer target and added AWS-native integrations connecting Kinesis to ECS Fargate, Kinesis becomes the ideal choice.

MSK is a stronger choice when it comes to the need for more complex consumer targets. Since the platform only requires a single consumer target, MSK capabilities aren't beneficial here. Additionally, transitioning to MSK would require VPC network and IAM modifications, and modification of the consumer service.

Cost comparison at 10K vehicles (~5 MB/s sustained):

| Service | Monthly Estimate | Notes |
|---|---|---|
| Kinesis on-demand | ~$1,589 | Scales to zero when idle, no minimum |
| Kinesis provisioned | ~$700–$900 | 5 shards at ~$0.015/shard-hour + PUT payload units. Cost-effective once throughput is predictable (~5K+ vehicles) |
| Kinesis on-demand Advantage | ~$636 | Available at scale (see Cost Analysis §10.5) |
| MSK Serverless | ~$1,200–$1,800 | Cluster hours + storage + partition hours |
| MSK Provisioned (kafka.m5.large x3) | ~$600–$900 | Lower unit cost but fixed floor, requires capacity planning |

The platform launches in on-demand mode for minimal overhead during early stages. Once the userbase fleet size exceeds around 5k vehicle, transitioning to provisioned mode becomes the ideal choice. Provisioned mode cuts costs by nearly 50% while traffic patern is fairly predicatable. If predicting provisioned shard amount becomes a challenge, Kinesis on-demand still remains the better choice over MSK serverless.


Just like Kinesis provisioned mode, MSK provisioned mode would be a great economical approach but adds in further admin overhead than Kinesis provisioned mode. MSK Serverless has low operational overhead but would add initial admin overhead that Kinesis would not need.

Rejected alternatives:
- **MSK Serverless:** Comparable cost to Kinesis with additional complex initial setup.
- **MSK Provisioned:** Comparable cost to Kinesis provisioned but again with additional complex setup.
- **SQS as primary ingestion:** SQS is more suitable to serve as a job buffer between Consumer and Lambda Functions.

Reevaluation triggers:
- Additional consumers that pull from the data stream are provisioned
- Event routing directly from the data stream rather than the Consumer triggering events
- The need for cloud portability increases in the future

## Status

Accepted (30DEC2025)

## Consequences

- On-demand mode handles all shard management during early phases of the platform.
- The single stream is a simplified approach but means that specific data events (vehicle-data, vehicle-alerts, vehicle-erorrs, etc) all share the same single stream.
- Potential single point of failure is introduced, however, provisioning failover streams is very fast and modifications to Consumer is as easy as modifying SSM parameter value.
- Transition plan to switch from on-demand to provisioned mdoe is needed once platform matures to around 5k vehicles.
- Platform is currently locked into vendor with Kinesis. Transitioning to Kafka woudl result in better portability but would require modifications to telemetry server and consumers. This is an acceptable tradeoff during early stages but requires reevaluation later.