const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    PutCommand,
    UpdateCommand,
    GetCommand
} = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// --- 3. INVENTORY SERVICE ---

/**
 * release_inventory: Compensation for ReserveInventory. Returns stock.
 */
exports.handler = async (event) => {
    console.log("Compensating: Releasing Inventory for Item:", event.itemId);
    const TABLE_NAME = process.env.TABLE_NAME;

    const params = {
        TableName: TABLE_NAME,
        Key: { itemId: event.itemId },
        UpdateExpression: "set stock = stock + :val",
        ExpressionAttributeValues: { ":val": 1 }
    };

    await docClient.send(new UpdateCommand(params));
    return { ...event, inventoryStatus: "RELEASED" };
};