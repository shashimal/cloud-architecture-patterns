import { DynamoDBClient, TransactWriteItemsCommand } from "@aws-sdk/client-dynamodb";
import { randomUUID } from "crypto";

const client = new DynamoDBClient({});

const ORDERS_TABLE = process.env.ORDERS_TABLE;
const OUTBOX_TABLE = process.env.OUTBOX_TABLE;

/**
 * Order Service – entry point via API Gateway HTTP API (POST /orders)
 *
 * The key operation here is a DynamoDB TransactWriteItems call that atomically:
 *   1. Inserts the order record into the `orders` table
 *   2. Inserts a corresponding outbox event into the `outbox-events` table
 *
 * Because both writes are wrapped in a single transaction, they either both
 * succeed or both fail.  There is no window where an order exists without a
 * matching outbox event (or vice-versa), which is the core guarantee of the
 * Transactional Outbox pattern.
 */
export const handler = async (event) => {
  const body = JSON.parse(event.body ?? "{}");
  const { customerId, items, totalAmount } = body;

  if (!customerId || !items || !totalAmount) {
    return {
      statusCode: 400,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        error: "customerId, items, and totalAmount are required",
      }),
    };
  }

  const orderId   = randomUUID();
  const eventId   = randomUUID();
  const timestamp = new Date().toISOString();
  const payload   = { orderId, customerId, items, totalAmount };

  // ── Atomic write ───────────────────────────────────────────────────────────
  // Both PutItems below either commit together or roll back together.
  // This prevents the dual-write problem (message lost if the app crashes
  // after saving the order but before enqueuing the event).
  await client.send(
    new TransactWriteItemsCommand({
      TransactItems: [
        {
          Put: {
            TableName: ORDERS_TABLE,
            Item: {
              orderId:     { S: orderId },
              customerId:  { S: customerId },
              items:       { S: JSON.stringify(items) },
              totalAmount: { N: String(totalAmount) },
              status:      { S: "PENDING" },
              createdAt:   { S: timestamp },
            },
          },
        },
        {
          Put: {
            TableName: OUTBOX_TABLE,
            Item: {
              eventId:     { S: eventId },
              eventType:   { S: "ORDER_CREATED" },
              aggregateId: { S: orderId },
              payload:     { S: JSON.stringify(payload) },
              status:      { S: "PENDING" },
              createdAt:   { S: timestamp },
            },
          },
        },
      ],
    })
  );

  console.log(`Order ${orderId} created. Outbox event ${eventId} enqueued.`);

  return {
    statusCode: 201,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ orderId, message: "Order created successfully" }),
  };
};
