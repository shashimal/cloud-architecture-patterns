const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");

const ddbClient = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(ddbClient);
exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const orderId =
    event.orderId ||
    (event.createOrderResult && event.createOrderResult.orderId);

  await ddb.send(
    new UpdateCommand({
      TableName: table,
      Key: { orderId },
      UpdateExpression: "SET #s = :s",
      ExpressionAttributeNames: { "#s": "status" },
      ExpressionAttributeValues: { ":s": "CANCELLED" },
    })
  );

  return { orderId, status: "CANCELLED" };
};