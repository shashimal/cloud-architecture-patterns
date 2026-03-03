import { DynamoDBClient, UpdateItemCommand } from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({});
const ORDERS_TABLE = process.env.ORDERS_TABLE;

export const handler = async (event) => {
  for (const record of event.Records) {
    // SQS message body wraps the SNS notification envelope
    const snsEnvelope = JSON.parse(record.body);
    const orderData   = JSON.parse(snsEnvelope.Message);

    console.log("=== Order Notification Received ===");
    console.log(`Order ID    : ${orderData.orderId}`);
    console.log(`Customer ID : ${orderData.customerId}`);
    console.log(`Items       : ${JSON.stringify(orderData.items)}`);
    console.log(`Total       : $${orderData.totalAmount}`);
    console.log("===================================");

    // TODO: replace with real notification logic (SES, Twilio, etc.)

    // Mark the order as NOTIFIED now that the customer has been informed
    await client.send(new UpdateItemCommand({
      TableName: ORDERS_TABLE,
      Key: { orderId: { S: orderData.orderId } },
      UpdateExpression: "SET #status = :status, notifiedAt = :notifiedAt",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: {
        ":status":     { S: "NOTIFIED" },
        ":notifiedAt": { S: new Date().toISOString() },
      },
    }));

    console.log(`Order ${orderData.orderId} status updated to NOTIFIED`);
  }
};
