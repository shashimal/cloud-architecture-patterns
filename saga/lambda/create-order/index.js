const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
const crypto = require("crypto");

const client = new DynamoDBClient({});
const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
    console.log("Creating Order:", event.orderId);

    const orderId = crypto.randomUUID();

    await client.send(
        new PutItemCommand({
            TableName: TABLE_NAME,
            Item: {
                order_id: { S: orderId },
                status: { S: "CREATED" }
            }
        })
    );

    return {
        order_id: orderId,
        status: "ORDER_CREATED"
    };
};