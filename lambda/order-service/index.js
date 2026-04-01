const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { EventBridgeClient, PutEventsCommand } = require("@aws-sdk/client-eventbridge");
const { randomUUID } = require("crypto");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const eb = new EventBridgeClient({});

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body || "{}");

    const orderId = randomUUID();
    const order = {
      orderId,
      customerId: body.customerId || "anonymous",
      items: body.items || [],
      totalAmount: body.totalAmount || 0,
      status: "PLACED",
      createdAt: new Date().toISOString(),
    };

    // 1. Persist order to DynamoDB
    await ddb.send(
      new PutCommand({
        TableName: process.env.ORDERS_TABLE,
        Item: order,
      })
    );

    // 2. Publish order.placed event – downstream services react autonomously
    const result = await eb.send(
      new PutEventsCommand({
        Entries: [
          {
            EventBusName: process.env.EVENT_BUS_NAME,
            Source: "ecommerce.order-service",
            DetailType: "order.placed",
            Detail: JSON.stringify(order),
            Time: new Date(),
          },
        ],
      })
    );

    if (result.FailedEntryCount > 0) {
      throw new Error(`EventBridge PutEvents failed: ${JSON.stringify(result.Entries)}`);
    }

    console.log(`[ORDER-SERVICE] Order ${orderId} placed. event published.`);

    return {
      statusCode: 201,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        orderId,
        status: "PLACED",
        message: "Order placed successfully. Processing has started.",
      }),
    };
  } catch (err) {
    console.error("[ORDER-SERVICE] Error:", err);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: err.message }),
    };
  }
};
