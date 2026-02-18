const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
    DynamoDBDocumentClient,
    PutCommand,
    UpdateCommand,
    GetCommand
} = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);


/**
 * cancel_order: Compensation for CreateOrder. Marks order as CANCELLED.
 */
exports.handler = async (event) => {
    console.log("Compensating: Cancelling Order", event);
    console.log("Compensating: Cancelling Order", event.originalInput.orderId);
    const TABLE_NAME = process.env.TABLE_NAME;

    const params = {
        TableName: TABLE_NAME,
        Key: { orderId: event.originalInput.orderId },
        UpdateExpression: "set #s = :s",
        ExpressionAttributeNames: { "#s": "status" },
        ExpressionAttributeValues: { ":s": "CANCELLED" }
    };

    await docClient.send(new UpdateCommand(params));
    return { ...event, orderStatus: "CANCELLED" };
};

