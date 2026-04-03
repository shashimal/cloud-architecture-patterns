const { STSClient, AssumeRoleCommand } = require("@aws-sdk/client-sts");
const { DynamoDBClient, PutItemCommand, QueryCommand } = require("@aws-sdk/client-dynamodb");

// Clients initialized outside handler for reuse
const stsClient = new STSClient({ region: process.env.AWS_REGION });

/**
 * Multi-Tenant Lambda Handler
 * Enforces data isolation via IAM Session Tags
 */
exports.handler = async (event) => {
    console.log("Event received:", JSON.stringify(event));

    try {
        // 1. Extract Tenant ID from Cognito Authorizer claims
        // API Gateway maps the ID Token claims to requestContext.authorizer.claims
        const claims = event.requestContext.authorizer.claims;
        const tenantId = claims['custom:tenantId'];

        if (!tenantId) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: "Tenant ID missing from user profile." })
            };
        }

        // 2. Assume the Shared Tenant Role with a Session Tag
        const assumeRoleCommand = new AssumeRoleCommand({
            RoleArn: process.env.TENANT_ACCESS_ROLE_ARN,
            RoleSessionName: `SaaSSession-${tenantId}-${Date.now()}`,
            DurationSeconds: 900, // 15 mins (minimum)
            Tags: [
                { Key: "tenantId", Value: tenantId }
            ]
        });

        const assumedRole = await stsClient.send(assumeRoleCommand);

        // 3. Create a scoped DynamoDB Client using temporary credentials
        const tenantDbClient = new DynamoDBClient({
            region: process.env.AWS_REGION,
            credentials: {
                accessKeyId: assumedRole.Credentials.AccessKeyId,
                secretAccessKey: assumedRole.Credentials.SecretAccessKey,
                sessionToken: assumedRole.Credentials.SessionToken
            }
        });

        const tableName = process.env.TABLE_NAME;

        // 4. Perform a sample operation
        // If we tried to use a different TenantId here, DynamoDB would return AccessDenied
        const queryCommand = new QueryCommand({
            TableName: tableName,
            KeyConditionExpression: "tenantId = :tid",
            ExpressionAttributeValues: {
                ":tid": { S: tenantId }
            }
        });

        const result = await tenantDbClient.send(queryCommand);

        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                message: `Success! Authenticated as tenant: ${tenantId}`,
                data: result.Items
            })
        };

    } catch (error) {
        console.error("Error:", error);
        
        // Handle IAM Access Denied specifically
        if (error.name === 'AccessDeniedException') {
            return {
                statusCode: 403,
                body: JSON.stringify({ message: "Security Violation: Tenant isolation enforced by IAM." })
            };
        }

        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Internal Server Error", error: error.message })
        };
    }
};