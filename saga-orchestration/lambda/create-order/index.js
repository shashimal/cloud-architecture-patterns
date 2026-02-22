const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
} = require("@aws-sdk/lib-dynamodb");

const ddbClient = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(ddbClient);

exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const orderId = event.orderId;
  const items = event.items;
  const amount = event.amount;

  await ddb.send(
    new PutCommand({
      TableName: table,
      Item: {
        orderId,
        items,
        amount,
        status: "PENDING",
        createdAt: new Date().toISOString(),
      },
    })
  );

  return { orderId, amount, items, status: "PENDING" };
};