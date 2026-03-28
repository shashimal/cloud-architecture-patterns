const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const eb = new EventBridgeClient({});

exports.handler = async (event) => {
  console.log("[FULFILLMENT-SERVICE] Received event:", JSON.stringify(event));

  const { orderId, customerId, items, totalAmount, reservation, payment } = event.detail;

  // Generate shipment details
  const shipmentId = randomUUID();
  const trackingNumber = `TRK-${shipmentId.substring(0, 8).toUpperCase()}`;
  const estimatedDelivery = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(); // +3 days

  const shipment = {
    shipmentId,
    orderId,
    customerId,
    items,
    trackingNumber,
    carrier: "FastShip Express",
    status: "DISPATCHED",
    estimatedDelivery,
    createdAt: new Date().toISOString(),
  };

  // 1. Persist shipment record
  await ddb.send(
    new PutCommand({
      TableName: process.env.SHIPMENTS_TABLE,
      Item: shipment,
    })
  );

  // 2. Publish order.fulfilled – notification-service sends the final notification
  await eb.send(
    new PutEventsCommand({
      Entries: [
        {
          EventBusName: process.env.EVENT_BUS_NAME,
          Source: "ecommerce.fulfillment-service",
          DetailType: "order.fulfilled",
          Detail: JSON.stringify({ orderId, customerId, items, totalAmount, reservation, payment, shipment }),
          Time: new Date(),
        },
      ],
    })
  );

  console.log(
    `[FULFILLMENT-SERVICE] Order ${orderId} fulfilled. Shipment ${shipmentId} dispatched. Tracking: ${trackingNumber}`
  );
};
