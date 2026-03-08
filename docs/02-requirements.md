# 2.0 Requirements

## 2.1 Business Requirements

| ID | Requirements |
|----|--------------|
| BR-1 | The platform must ingest and process high volume telemetry from vehicles in real-time |
| BR-2 | The platform must support multi-tenant user operations with isolation |
| BR-3 | The platform must provide subsecond vehicle state updates to enable real-time user visibility into their operation |
| BR-4 | The platform must support bidirectional vehicle interaction to receive data and send command executions remotely |
| BR-5 | The platform must take steps to protect user PII (VINs) and minimize exposure scope |
| BR-6 | The platform must be able to scale from 100 to 10,000+ vehicles without architectural changes |
| BR-7 | The platform must be able to maintain costs that fluctuate dynamically to userbase and fleet sizes |
| BR-8 | The platform must be simple enough to maintain without a dedicated team and automate most operations (minimal admin overhead) |
| BR-9 | The platform must take steps to prevent data loss and ability to replay data if needed |

---

## 2.2 Technical Requirements
### 2.2.1 Data Ingestion & Streaming
| ID | Requirements |
|----|--------------|
| TR-1 | Secure vehicle communications must be implemented and validated using mTLS |
| TR-2 | HMAC-SHA256 pseudonymization implemented in this layer to minimize exposure scope of PII |
| TR-3 | Durable and real-time stream implemented using Kinesis and 7-day archival window |

### 2.2.2 Data Delivery
| ID | Requirements |
|----|--------------|
| TR-4 | Vehicle data is updated in real-time using server sent events and Redis. |
| TR-5 | Graceful degradation implemented to maintain critical application function. SSE service is designed to automatically recover upon connection loss without manual intervention or refreshing |
| TR-6 | Resilient fallback in place to shift dashboard updates from SSE to automated DynamoDB API polling in the event of SSE interruption. Upon recovery SSE autoconnects. |

### 2.2.3 API and Integration
| ID | Requirements |
|----|--------------|
| TR-6 | No API request is trusted by default and must authenticate JWT before execution |
| TR-7 | Vehicle commands are internet-egressing and must have steps taken to prevent interception and manipulation. Payloads are cryptographically signed with OEM trusted private keys that are stored and managed in Secrets Manager |
| TR-8 | Internal (ECS) services must be able to communicate with eachother without manually providing each with IP address information. Cloud Map provides services with persistent private DNS.

### Multi-tenancy
| ID | Requirements |
|----|--------------|
| TR-9 | DynamoDB PK design prevents cross-user and organization data leakage. API requests are not trusted by default and validated via JWT authentication. |

### Processing Resilience
| ID | Requirements |
|----|--------------|
| TR-10 | Trip analytics workflows have multi layer safety nets including orphaned job detection and DLQs to clear primary processing path |
| TR-11 | Consumer supports re-delivery after failure |

### Data Storage and Management
| ID | Requirements |
|----|--------------|
| TR-12 | Data solution must be managed and provide minimal processing overhead. DynamoDB is serverless and provides millisecond operations |
| TR-13 | S3 lifecycle policies is utilized to transition data progressively into cheaper storage classes |
| TR-14 | TTL utilized to auto-expire ephermeral data from DynamoDB without manual intervention |
| TR-15 | Data must remain secure and protected. All primary tables have point-in-time recovery and deletion protection enabled |

