const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
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
    throw new Error("Missing required 'items' array in event. Expected event.items or event.createOrderResult.items.")
  }

  // Example: artificially fail if a special item is requested
  if (items.some((item) => item.id === "OUT_OF_STOCK")) {
    throw new Error("Inventory not available");
  }

  for (const item of items) {
    await ddb.send(
      new PutCommand({
        TableName: table,
        Item: {
          itemId: item.id,
          reservedQty: item.qty,
        },
      })
    );
  }

  return { reserved: true };
};