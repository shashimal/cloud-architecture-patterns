const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  DeleteCommand,
} = require("@aws-sdk/lib-dynamodb");

const ddbClient = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(ddbClient);

exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const input =
    (event && event.Payload) ||
    (event && event.payload) ||
    (event && event.input) ||
    event ||
    {};

  const items =
    input.items ||
    (input.createOrderResult && input.createOrderResult.items) ||
    (input.createOrderResult &&
      input.createOrderResult.Payload &&
      input.createOrderResult.Payload.items) ||
    [];

  if (!Array.isArray(items) || items.length === 0) {
    return { released: true };
  }

  for (const item of items) {
    await ddb.send(
      new DeleteCommand({
        TableName: table,
        Key: { itemId: item.id },
      })
    );
  }

  return { released: true };
};