# Transactional Outbox Pattern on AWS

## 1. What is the Transactional Outbox Pattern?

A common challenge in distributed systems is the **dual-write problem**: when a service must both update its database *and* emit an event/message, a crash between the two operations leaves the system in an inconsistent state — either the data is saved but the event is lost, or the event fires but the data was never committed.

The **Transactional Outbox** pattern solves this by treating the event as just another piece of data:

1. In a **single atomic transaction**, write the business record *and* an outbox event record to the same database.
2. A separate **relay process** reads new outbox events and publishes them to the messaging system.
3. Once published, the outbox event is marked `PUBLISHED`.

Because steps 1 is one transaction, the database guarantees either both records are committed or neither is.

---

## 2. Use Case: E-commerce Order Notification

When a customer places an order:

| Step | What happens |
|------|-------------|
| 1 | Client calls `POST /orders` via API Gateway |
| 2 | **order-service** Lambda writes an `orders` record **and** an `outbox-events` record in a single `TransactWriteItems` call |
| 3 | DynamoDB Streams detects the new outbox event and triggers **outbox-processor** |
| 4 | **outbox-processor** publishes the `ORDER_CREATED` event to SNS and marks the outbox event as `PUBLISHED` |
| 5 | SNS fans out to the SQS notification queue |
| 6 | **notification-service** Lambda consumes the SQS message and sends the customer a confirmation (email/SMS in production) |

---

## 3. Architecture

```
┌──────────────┐    POST /orders    ┌─────────────────────┐
│    Client    │ ─────────────────► │   API Gateway HTTP   │
└──────────────┘                    └─────────┬───────────┘
                                              │ invoke
                                              ▼
                                   ┌─────────────────────┐
                                   │    order-service     │
                                   │      (Lambda)        │
                                   └─────────┬───────────┘
                                             │ TransactWriteItems (atomic)
                              ┌──────────────┴──────────────┐
                              ▼                             ▼
                   ┌──────────────────┐        ┌───────────────────────┐
                   │  outbox-orders   │        │    outbox-events       │
                   │  (DynamoDB)      │        │  (DynamoDB + Streams)  │
                   └──────────────────┘        └───────────┬───────────┘
                                                           │ INSERT stream event
                                                           ▼
                                               ┌─────────────────────┐
                                               │  outbox-processor   │
                                               │     (Lambda)        │
                                               └────────┬────────────┘
                                                        │ Publish + mark PUBLISHED
                                          ┌─────────────┴──────────────┐
                                          ▼                            ▼
                               ┌──────────────────┐       ┌──────────────────────┐
                               │   SNS Topic       │       │   outbox-events      │
                               │ order-events-topic│       │   status = PUBLISHED │
                               └────────┬──────────┘       └──────────────────────┘
                                        │ fan-out
                                        ▼
                               ┌──────────────────┐
                               │   SQS Queue       │
                               │ order-notifications│
                               └────────┬──────────┘
                                        │ event source mapping
                                        ▼
                               ┌──────────────────┐
                               │notification-service│
                               │     (Lambda)       │
                               └──────────────────┘
                                 (email / SMS / etc.)
```

### Key guarantee

`TransactWriteItems` writes to both `outbox-orders` and `outbox-events` atomically. If the Lambda crashes after the commit, the stream still fires and the event is delivered. If it crashes before the commit, no stale event is produced.

---

## 4. AWS Services Used

| Service | Role |
|---------|------|
| **API Gateway HTTP API** | Exposes `POST /orders` to the internet |
| **Lambda** (order-service) | Handles order creation with atomic dual-write |
| **DynamoDB** (outbox-orders) | Stores orders |
| **DynamoDB** (outbox-events) | Stores outbox events; Streams enabled |
| **DynamoDB Streams** | CDC trigger – fires on every new outbox event |
| **Lambda** (outbox-processor) | Reads stream, publishes to SNS, marks event PUBLISHED |
| **SNS** | Durable pub/sub fan-out |
| **SQS** (+ DLQ) | Decouples consumers; dead-letter queue for failures |
| **Lambda** (notification-service) | Downstream consumer – sends customer notifications |

---

## 5. Project Structure

```
transactional-outbox/
├── versions.tf               # Terraform & provider version constraints
├── main.tf                   # All AWS resources
├── iam.tf                    # IAM roles & policies (one per Lambda)
├── data.tf                   # archive_file data sources & IAM policy documents
├── outputs.tf                # Useful outputs (API URL, table names, …)
└── lambda/
    ├── order-service/
    │   └── index.mjs         # Atomic order + outbox write
    ├── outbox-processor/
    │   └── index.mjs         # Stream reader → SNS publisher
    └── notification-service/
        └── index.mjs         # SQS consumer → customer notification
```

---

## 6. Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`aws configure` or `AWS_PROFILE` env var)
- AWS credentials with permissions to create Lambda, DynamoDB, SNS, SQS, API Gateway, and IAM resources

---

## 7. Deployment Steps

### 7.1 Initialize Terraform

```bash
cd transactional-outbox
terraform init
```

### 7.2 Review the Plan

```bash
terraform plan
```

### 7.3 Apply

```bash
terraform apply
```

Terraform will output the API endpoint when complete:

```
api_endpoint = "https://<id>.execute-api.ap-southeast-1.amazonaws.com/orders"
```

---

## 8. Testing

### 8.1 Create an Order (happy path)

```bash
curl -X POST \
  $(terraform output -raw api_endpoint) \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-42",
    "items": [
      { "productId": "prod-001", "name": "Wireless Headphones", "qty": 1 },
      { "productId": "prod-002", "name": "USB-C Cable",         "qty": 2 }
    ],
    "totalAmount": 89.99
  }'
```

Expected response:

```json
{
  "orderId": "<uuid>",
  "message": "Order created successfully"
}
```

### 8.2 Verify the DynamoDB Tables

Check that both tables were written atomically:

```bash
# Orders table
aws dynamodb scan \
  --table-name outbox-orders \
  --region ap-southeast-1

# Outbox events table (should show status PENDING → PUBLISHED)
aws dynamodb scan \
  --table-name outbox-events \
  --region ap-southeast-1
```

### 8.3 Verify the Event Flow in CloudWatch

Open CloudWatch Logs and inspect the three Lambda log groups:

| Log Group | What to look for |
|-----------|-----------------|
| `/aws/lambda/order-service` | `Order <id> created. Outbox event <id> enqueued.` |
| `/aws/lambda/outbox-processor` | `Outbox event <id> published to SNS and marked PUBLISHED` |
| `/aws/lambda/notification-service` | The `=== Order Notification Received ===` block with order details |

### 8.4 Test the Dual-Write Guarantee (optional)

The pattern's value is visible when you simulate a partial failure.  Add a deliberate exception to the `order-service` handler *after* the `TransactWriteItemsCommand` returns and redeploy.  You will see:

- The order **and** outbox event were committed (both rows appear in DynamoDB).
- The stream still fires because the data is already durable.
- The outbox-processor successfully publishes the event — no message is lost.

---

## 9. Clean Up

```bash
terraform destroy
```

> **Note**: This also deletes the DynamoDB tables and all data inside them.
