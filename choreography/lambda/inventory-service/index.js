const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const eb = new EventBridgeClient({});

exports.handler = async (event) => {
  console.log("[INVENTORY-SERVICE] Received event:", JSON.stringify(event));

  // EventBridge delivers the order payload in event.detail
  const order = event.detail;
  const { orderId, customerId, items, totalAmount } = order;

  // Simulate inventory check: 80% success rate for demo purposes
  // In production this would query actual stock levels
  const inventoryAvailable = Math.random() < 0.8;

  const reservation = {
    reservationId: randomUUID(),
    orderId,
    items,
    status: inventoryAvailable ? "RESERVED" : "FAILED",
    reservedAt: new Date().toISOString(),
    failureReason: inventoryAvailable ? null : "Insufficient stock for one or more items",
  };

  // 1. Persist reservation record
  await ddb.send(
    new PutCommand({
      TableName: process.env.INVENTORY_TABLE,
      Item: reservation,
    })
  );

  // 2. Publish result event – payment-service or notification-service reacts
  const detailType = inventoryAvailable ? "inventory.reserved" : "inventory.failed";

  await eb.send(
    new PutEventsCommand({
      Entries: [
        {
          EventBusName: process.env.EVENT_BUS_NAME,
          Source: "ecommerce.inventory-service",
          DetailType: detailType,
          Detail: JSON.stringify({ orderId, customerId, items, totalAmount, reservation }),
          Time: new Date(),
        },
      ],
    })
  );

  console.log(`[INVENTORY-SERVICE] Published ${detailType} for order ${orderId}`);
};
