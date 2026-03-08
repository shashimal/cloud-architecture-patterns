# Choreography Pattern – Event-Driven Microservices on AWS

## What is the Choreography Pattern?

In the **Choreography** pattern, each microservice knows what to do when it receives a specific event.
There is **no central controller** (unlike Orchestration). Services communicate exclusively through events,
making each service independently deployable, scalable, and loosely coupled.

```
Orchestration:  Client → Orchestrator → Service A → Orchestrator → Service B → ...
Choreography:   Client → Service A ──(event)──► Service B ──(event)──► Service C → ...
```

---

## Use Case: E-Commerce Order Processing

A customer places an order. Five independent microservices react to events in sequence:

| Service              | Trigger Event         | Published Event                        |
|---------------------|-----------------------|----------------------------------------|
| Order Service        | HTTP POST /orders     | `order.placed`                         |
| Inventory Service    | `order.placed`        | `inventory.reserved` / `inventory.failed` |
| Payment Service      | `inventory.reserved`  | `payment.processed` / `payment.failed` |
| Fulfillment Service  | `payment.processed`   | `order.fulfilled`                      |
| Notification Service | All events above      | _(none – terminal consumer)_           |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (ap-southeast-1)                             │
│                                                                                 │
│  ┌──────────┐   POST /orders   ┌─────────────────────────────────────────────┐ │
│  │          │ ───────────────► │           API Gateway HTTP API              │ │
│  │  Client  │                  └───────────────────┬─────────────────────────┘ │
│  │  (curl)  │                                      │ invoke                    │
│  └──────────┘                                      ▼                           │
│                                        ┌────────────────────┐                  │
│                                        │   Order Service    │                  │
│                                        │     (Lambda)       │                  │
│                                        │                    │                  │
│                                        │  1. Persist order  │                  │
│                                        │  2. Publish event  │                  │
│                                        └─────────┬──────────┘                  │
│                                                  │ PutItem                      │
│                                                  ▼                              │
│                                        ┌────────────────────┐                  │
│                                        │  DynamoDB: orders  │                  │
│                                        └────────────────────┘                  │
│                                                  │                              │
│                                   PutEvents ◄────┘                             │
│                                        │ order.placed                          │
│                                        ▼                                        │
│  ╔═════════════════════════════════════════════════════════════╗               │
│  ║           EventBridge Custom Bus: ecommerce-orders          ║               │
│  ╚══════════════════════╤══════════════════════════════════════╝               │
│                         │                                                       │
│         ┌───────────────┼────────────────────────────────────┐                │
│         │ order.placed  │                           order.placed               │
│         ▼               │                                     ▼               │
│  ┌──────────────────┐   │                    ┌───────────────────────────────┐ │
│  │ Inventory Service│   │                    │     Notification Service      │ │
│  │    (Lambda)      │   │                    │          (Lambda)             │ │
│  │                  │   │                    │                               │ │
│  │ • Check stock    │   │                    │ • Logs customer messages      │ │
│  │ • Reserve items  │   │                    │ • (prod: SES / SNS / etc.)    │ │
│  └────────┬─────────┘   │                    └──────────────▲────────────────┘ │
│           │             │                                   │ all events        │
│   ┌───────┴──────┐      │                                   │                  │
│   │              │      │           ┌───────────────────────┘                  │
│   ▼              ▼      │           │                                           │
│ inventory.  inventory.  │           │                                           │
│ reserved    failed ─────┼───────────┘                                          │
│   │                     │                                                       │
│   ▼                     │                                                       │
│  ╔══════════════════════╧═════════════════════════════════════╗                │
│  ║           EventBridge Custom Bus: ecommerce-orders          ║                │
│  ╚═════════════════════════════╤══════════════════════════════╝                │
│                                │ inventory.reserved                             │
│                                ▼                                                │
│                    ┌───────────────────────┐                                   │
│                    │   Payment Service     │                                   │
│                    │      (Lambda)         │                                   │
│                    │                       │                                   │
│                    │ • Charge card         │                                   │
│                    │ • Record payment      │                                   │
│                    └──────────┬────────────┘                                  │
│                               │                                                 │
│                    ┌──────────┴──────────┐                                    │
│                    ▼                     ▼                                     │
│              payment.          payment.failed ──────────► Notification        │
│              processed                                       Service           │
│                    │                                                            │
│                    ▼                                                            │
│         ╔═══════════════════════════════════════════════════╗                 │
│         ║         EventBridge: payment.processed            ║                 │
│         ╚══════════════════╤════════════════════════════════╝                 │
│                            │                                                    │
│                            ▼                                                    │
│                 ┌──────────────────────┐                                       │
│                 │  Fulfillment Service │                                       │
│                 │      (Lambda)        │                                       │
│                 │                      │                                       │
│                 │ • Create shipment    │                                       │
│                 │ • Assign tracking #  │                                       │
│                 └──────────┬───────────┘                                      │
│                            │ order.fulfilled                                   │
│                            ▼                                                   │
│                    Notification Service                                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Event Flow (Happy Path)

```
Client                  Order       Inventory    Payment    Fulfillment  Notification
  │                    Service       Service      Service     Service      Service
  │                       │             │            │            │            │
  │──POST /orders────────►│             │            │            │            │
  │                       │             │            │            │            │
  │                       │─PutItem────►[orders DB]  │            │            │
  │                       │             │            │            │            │
  │                       │─PutEvents──►[EventBridge: order.placed]            │
  │◄──201 { orderId }─────│             │            │            │            │
  │                       │             │            │            │            │
  │                       │         ◄───┤ order.placed            │            │
  │                       │         ◄───┼─────────────────────────┼────────────┤
  │                       │             │            │            │  [notify:  │
  │                       │             │            │            │  "placed"] │
  │                       │         ────►[inventory DB]           │            │
  │                       │         PutItem          │            │            │
  │                       │             │            │            │            │
  │                       │         PutEvents──►[EventBridge: inventory.reserved]
  │                       │             │            │            │            │
  │                       │             │        ◄───┤ inventory.reserved      │
  │                       │             │        ◄───┼─────────────────────────┤
  │                       │             │            │            │  [notify:  │
  │                       │             │            │            │  "reserved"]
  │                       │             │        ────►[payments DB]            │
  │                       │             │        PutItem          │            │
  │                       │             │            │            │            │
  │                       │             │        PutEvents──►[EventBridge: payment.processed]
  │                       │             │            │            │            │
  │                       │             │            │        ◄───┤ payment.processed
  │                       │             │            │        ◄───┼────────────┤
  │                       │             │            │            │  [notify:  │
  │                       │             │            │            │  "payment"]│
  │                       │             │            │        ────►[shipments DB]
  │                       │             │            │        PutItem          │
  │                       │             │            │            │            │
  │                       │             │            │        PutEvents──►[EventBridge: order.fulfilled]
  │                       │             │            │            │        ◄───┤
  │                       │             │            │            │  [notify:  │
  │                       │             │            │            │  "shipped"]│
```

---

## Error Flow (Inventory Failure)

```
  Order Service ──order.placed──► EventBridge
                                       │
                              inventory.service
                                       │
                              [stock check fails]
                                       │
                              ─inventory.failed──► EventBridge
                                                        │
                                               notification-service
                                                        │
                                               "Order cancelled – out of stock"
```

---

## AWS Services Used

| Service             | Purpose                                                    |
|--------------------|------------------------------------------------------------|
| API Gateway HTTP    | Single entry point for the client                          |
| Lambda (x5)         | Each microservice as a serverless function                 |
| EventBridge         | Custom event bus for decoupled event routing               |
| DynamoDB (x4)       | Independent data store per service (orders/inventory/payments/shipments) |

---

## Project Structure

```
choreography/
├── versions.tf          # Terraform + provider config
├── apigw.tf             # API Gateway HTTP API
├── eventbridge.tf       # Event bus, routing rules, Lambda permissions
├── dynamodb.tf          # Four DynamoDB tables
├── lambda.tf            # Five Lambda function modules
├── iam.tf               # IAM roles and policies per service
├── data.tf              # ZIP archives + IAM policy documents
├── outputs.tf           # API endpoint URL, table names
└── lambda/
    ├── order-service/       index.js  → publishes order.placed
    ├── inventory-service/   index.js  → publishes inventory.reserved / failed
    ├── payment-service/     index.js  → publishes payment.processed / failed
    ├── fulfillment-service/ index.js  → publishes order.fulfilled
    └── notification-service/index.js  → terminal consumer, logs notifications
```

---

## Deploy

```bash
cd choreography

# Initialise providers and modules
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply

# Note the API endpoint from outputs
terraform output api_endpoint
```

---

## Sample Request Payload

```json
{
  "customerId": "cust-42",
  "items": [
    { "productId": "prod-001", "name": "Wireless Headphones", "qty": 1, "price": 79.99 },
    { "productId": "prod-002", "name": "USB-C Cable",         "qty": 2, "price": 9.99  }
  ],
  "totalAmount": 99.97
}
```

---

## Testing Instructions

### 1. Place an order

```bash
API_URL=$(terraform output -raw api_endpoint)

curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "cust-42",
    "items": [
      { "productId": "prod-001", "name": "Wireless Headphones", "qty": 1, "price": 79.99 },
      { "productId": "prod-002", "name": "USB-C Cable",         "qty": 2, "price": 9.99  }
    ],
    "totalAmount": 99.97
  }' | jq .
```

**Expected response:**
```json
{
  "orderId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "PLACED",
  "message": "Order placed successfully. Processing has started."
}
```

---

### 2. Watch the event chain in CloudWatch Logs

Each Lambda writes structured logs. Open the AWS Console → CloudWatch → Log groups and tail:

```
/aws/lambda/choreography-order-service
/aws/lambda/choreography-inventory-service
/aws/lambda/choreography-payment-service
/aws/lambda/choreography-fulfillment-service
/aws/lambda/choreography-notification-service
```

Or use the AWS CLI to stream logs:

```bash
# Stream order-service logs
aws logs tail /aws/lambda/choreography-order-service --follow

# Stream notification-service logs (shows all events end-to-end)
aws logs tail /aws/lambda/choreography-notification-service --follow
```

---

### 3. Verify data in DynamoDB

```bash
ORDER_ID="<orderId from step 1>"

# Check order record
aws dynamodb get-item \
  --table-name choreography-orders \
  --key "{\"orderId\":{\"S\":\"$ORDER_ID\"}}" \
  --region ap-southeast-1 | jq .

# Check inventory reservation
aws dynamodb scan \
  --table-name choreography-inventory \
  --filter-expression "orderId = :oid" \
  --expression-attribute-values "{\":oid\":{\"S\":\"$ORDER_ID\"}}" \
  --region ap-southeast-1 | jq .

# Check payment record
aws dynamodb scan \
  --table-name choreography-payments \
  --filter-expression "orderId = :oid" \
  --expression-attribute-values "{\":oid\":{\"S\":\"$ORDER_ID\"}}" \
  --region ap-southeast-1 | jq .

# Check shipment record
aws dynamodb scan \
  --table-name choreography-shipments \
  --filter-expression "orderId = :oid" \
  --expression-attribute-values "{\":oid\":{\"S\":\"$ORDER_ID\"}}" \
  --region ap-southeast-1 | jq .
```

---

### 4. Test failure scenarios

The services use probabilistic simulation:
- **Inventory failure**: ~20% chance → triggers `inventory.failed`
- **Payment failure**: ~10% chance → triggers `payment.failed`

Run multiple orders to observe both paths:

```bash
for i in {1..10}; do
  curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"customerId\":\"cust-$i\",\"items\":[{\"productId\":\"prod-00$i\",\"name\":\"Item $i\",\"qty\":1,\"price\":$((i * 10)).00}],\"totalAmount\":$((i * 10)).00}" \
    | jq -r '"Order \(.orderId): \(.status)"'
done
```

Then check the notification-service logs to see the mix of success and failure notifications.

---

### 5. Inspect EventBridge rules

```bash
aws events list-rules \
  --event-bus-name ecommerce-orders \
  --region ap-southeast-1 | jq '.Rules[] | {Name, State, EventPattern}'
```

---

## Tear Down

```bash
terraform destroy
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Custom EventBridge bus | Isolates domain events from the default bus |
| One DynamoDB table per service | Services are independently deployable; no shared schema |
| Separate IAM role per Lambda | Least-privilege; each role only has the permissions it needs |
| Probabilistic simulation | Demonstrates both happy and failure paths without external dependencies |
| Notification service as terminal consumer | Centralises cross-cutting concerns (alerts, logs) without polluting business logic |

---

## Choreography vs Orchestration

| Aspect             | Choreography                        | Orchestration                          |
|--------------------|-------------------------------------|----------------------------------------|
| Control            | Distributed – each service decides  | Centralised – orchestrator directs     |
| Coupling           | Loose – services only know events   | Tighter – orchestrator knows all steps |
| Visibility         | Hard – must aggregate logs          | Easy – single orchestrator state       |
| Failure handling   | Each service handles its own errors | Orchestrator manages retries/rollbacks |
| Best for           | Simple, linear event chains         | Complex flows with branching/compensation |
