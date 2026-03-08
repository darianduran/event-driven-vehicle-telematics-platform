# ADR 1: VIN Pseudonymization at the Ingestion Layer

VINs are unique vehicle identifiers that are classified as PII data. VINs can be linked back to the vehicle owner and in context of this platform can expose an owner's location, historical data, and driving patterns. Unauthorized VIN retrieval can lead to fraudalent crime against users or unauthorized command execution attempts.

The original implementation simply stored raw VIN in all DynamoDB tables, S3 buckets, and CloudWatch logs. While all data stores were encrypted with KMS, the raw VIN was readable by any resource with read access or by internal users. Any misconfigured IAM policies, logs leaks, or potential injection attacks could expose user's VIN data. 

## Decision

We will apply HMAC-SHA256 pseudonymization to raw VINs at the ingestion boundary (Consumer) before any data reaches application databases, caches, or logs. A dedicated `vin-mapping` DynamoDB table stores the bidirectional mapping, restricted to a single admin IAM role with full CloudTrail data event logging.

## Rationale
HMAC-SHA256 provides deterministic output a unique partition key across all data stores, irreversibility without the key, fixed-length output, and single-function-call simplicity.

Rejected alternatives:
- **Raw VIN + KMS at rest:** Does not protect against authorized access; logs and exports contain raw VINs.
- **AES-256 encryption:** Cannot serve as partition key and decryption required on every read.
- **SHA-256 hash (no key):** Rainbow table attack can recover all VINs.
- **Tokenization via CloudHSM:** Significanly high cost and requires API calls on every operation.

## Status

Accepted (09JAN2026)

## Consequences

- Raw VINs are minimized to the ingestion layer. All downstream stores, caches, logs, and API responses use only pseudoVINs.
- The `vin-mapping` table is the single point of reverse resolution, requiring restricted IAM, CloudTrail data event logging, and deletion protection.
- The HMAC key in Secrets Manager is permanently fixed and rotation requires manual re-pseudonymization and data store modifications.

