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
 * reserve_inventory: Deducts stock from the Inventory table.
 */
exports.handler = async (event) => {
    console.log("Reserving Inventory for Item:", event);
    const TABLE_NAME = process.env.TABLE_NAME;

    if (event.failAt === 'reserve_inventory') throw new Error("Out of Stock");

    const params = {
        TableName: TABLE_NAME,
        Key: { itemId: event.Payload.itemId },
        UpdateExpression: "set stock = stock - :val",
        ConditionExpression: "stock >= :val",
        ExpressionAttributeValues: { ":val": 1 }
    };

    try {
        await docClient.send(new UpdateCommand(params));
        return { ...event, inventoryStatus: "RESERVED" };
    } catch (err) {
        if (err.name === "ConditionalCheckFailedException") {
            throw new Error("Insufficient Inventory Stock");
        }
        throw err;
    }
};
