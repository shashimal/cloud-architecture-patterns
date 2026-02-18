const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    PutCommand,
    UpdateCommand,
    GetCommand
} = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// --- 1. ORDER SERVICE ---

/**
 * create_order: Creates a PENDING order in DynamoDB.
 */
exports.handler = async (event) => {
    console.log("Creating Order:", event);
    const TABLE_NAME = process.env.TABLE_NAME;

    // Simulate failure for testing
    if (event.failAt === 'create_order') throw new Error("Order Creation Failed");

    const params = {
        TableName: TABLE_NAME,
        Item: {
            orderId: event.orderId,
            status: "PENDING",
            amount: event.amount,
            itemId: event.itemId,
            createdAt: new Date().toISOString()
        }
    };

    await docClient.send(new PutCommand(params));
    return { ...event, orderStatus: "PENDING" };
};
