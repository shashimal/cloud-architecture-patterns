import { DynamoDBClient, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";

const dynamoClient = new DynamoDBClient({});
const snsClient    = new SNSClient({});

const OUTBOX_TABLE  = process.env.OUTBOX_TABLE;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

/**
 * Outbox Processor – triggered by DynamoDB Streams on the `outbox-events` table.
 *
 * For every INSERT event it:
 *   1. Publishes the event payload to SNS (reliable delivery)
 *   2. Updates the outbox record status to PUBLISHED
 *
 * Using DynamoDB Streams as the trigger means we never poll the outbox table
 * and events are delivered with low latency.  The stream guarantees at-least-once
 * delivery, so downstream consumers must be idempotent.
 */
export const handler = async (event) => {
  for (const record of event.Records) {
    // Only process newly inserted outbox events
    if (record.eventName !== "INSERT") continue;

    const newImage  = record.dynamodb.NewImage;
    const eventId   = newImage.eventId.S;
    const eventType = newImage.eventType.S;
    const payload   = newImage.payload.S;

    console.log(`Processing outbox event ${eventId} (${eventType})`);

    // ── Step 1: Publish to SNS ─────────────────────────────────────────────
    await snsClient.send(
      new PublishCommand({
        TopicArn: SNS_TOPIC_ARN,
        Message:  payload,
        MessageAttributes: {
          eventType: {
            DataType:    "String",
            StringValue: eventType,
          },
        },
      })
    );

    // ── Step 2: Mark outbox event as PUBLISHED ─────────────────────────────
    await dynamoClient.send(
      new UpdateItemCommand({
        TableName:                 OUTBOX_TABLE,
        Key:                       { eventId: { S: eventId } },
        UpdateExpression:          "SET #status = :status, processedAt = :ts",
        ExpressionAttributeNames:  { "#status": "status" },
        ExpressionAttributeValues: {
          ":status": { S: "PUBLISHED" },
          ":ts":     { S: new Date().toISOString() },
        },
      })
    );

    console.log(`Outbox event ${eventId} published to SNS and marked PUBLISHED`);
  }
};
