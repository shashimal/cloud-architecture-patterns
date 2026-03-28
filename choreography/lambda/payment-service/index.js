const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const eb = new EventBridgeClient({});

exports.handler = async (event) => {
  console.log("[PAYMENT-SERVICE] Received event:", JSON.stringify(event));

  const { orderId, customerId, items, totalAmount, reservation } = event.detail;

  // Simulate payment processing: 90% success rate for demo purposes
  // In production this would call a payment gateway (Stripe, PayPal, etc.)
  const paymentSuccess = Math.random() < 0.9;

  const payment = {
    paymentId: randomUUID(),
    orderId,
    customerId,
    amount: totalAmount,
    currency: "USD",
    status: paymentSuccess ? "PROCESSED" : "FAILED",
    processedAt: new Date().toISOString(),
    failureReason: paymentSuccess ? null : "Card declined – insufficient funds",
  };

  // 1. Persist payment record
  await ddb.send(
    new PutCommand({
      TableName: process.env.PAYMENTS_TABLE,
      Item: payment,
    })
  );

  // 2. Publish result event – fulfillment-service or notification-service reacts
  const detailType = paymentSuccess ? "payment.processed" : "payment.failed";

  await eb.send(
    new PutEventsCommand({
      Entries: [
        {
          EventBusName: process.env.EVENT_BUS_NAME,
          Source: "ecommerce.payment-service",
          DetailType: detailType,
          Detail: JSON.stringify({ orderId, customerId, items, totalAmount, reservation, payment }),
          Time: new Date(),
        },
      ],
    })
  );

  console.log(`[PAYMENT-SERVICE] Published ${detailType} for order ${orderId}`);
};
