# Scatter and Gather Pattern with AWS Step Functions and Lambda

## Overview

The Scatter and Gather pattern distributes work across multiple parallel workers and then aggregates the results. This implementation uses:
- **AWS Step Functions** for orchestration (scatter phase)
- **AWS Lambda** for parallel workers
- **Terraform** for infrastructure as code

## Architecture

```
Input → Step Function (Scatter) → Multiple Lambda Workers (Parallel) → Aggregator Lambda (Gather) → Output
```

## Step-by-Step Implementation Guide

### Step 1: Project Setup

Create the following directory structure:
```
scatter-gather-aws/
├── main.tf
├── variables.tf
├── outputs.tf
├── lambda/
│   ├── worker/
│   │   └── index.js
│   └── aggregator/
│       └── index.js
└── step-function/
    └── state-machine.json
```

### Step 2: Lambda Worker Function

The worker function processes individual tasks in parallel.

### Step 3: Lambda Aggregator Function

The aggregator function collects and combines results from all workers.

### Step 4: Step Functions State Machine

Defines the scatter and gather workflow with parallel execution.

### Step 5: Terraform Infrastructure

Provisions all AWS resources including IAM roles, Lambda functions, and Step Functions.

### Step 6: Deploy

```bash
# Option 1: Use the deployment script
chmod +x deploy.sh
./deploy.sh

# Option 2: Manual deployment
terraform init
terraform plan
terraform apply
```

### Step 7: Test the Implementation

```bash
# Get the state machine ARN from Terraform outputs
STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn)

# Start execution with test input
aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input file://test-input.json

# Or with inline JSON
aws stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN \
  --input '{"items": ["task1", "task2", "task3", "task4"]}'

# Monitor execution
aws stepfunctions describe-execution \
  --execution-arn <execution-arn-from-previous-command>
```

### Step 8: View Results

Check the AWS Console:
- Step Functions → State machines → scatter-gather-scatter-gather
- CloudWatch Logs for detailed execution logs
- Lambda → Functions to see individual invocations

## How It Works

1. **Scatter Phase**: Step Function receives input and uses Map state to distribute tasks
2. **Parallel Processing**: Multiple Lambda workers execute simultaneously
3. **Gather Phase**: Aggregator Lambda collects and processes all results
4. **Output**: Combined result is returned

## Benefits

- Scalable parallel processing
- Automatic retry and error handling
- Visual workflow monitoring
- Cost-effective serverless architecture


## Configuration Options

### Adjusting Concurrency

In `step-function/state-machine.json`, modify the `MaxConcurrency` parameter:
```json
"MaxConcurrency": 10  // Process up to 10 items in parallel
```

### Lambda Timeout and Memory

In `main.tf`, adjust Lambda configuration:
```hcl
timeout = 30      // Execution timeout in seconds
memory_size = 128 // Memory in MB (add this parameter)
```

### Error Handling

The state machine includes:
- Automatic retries with exponential backoff
- Error catching to prevent complete failure
- CloudWatch logging for debugging

## Cost Considerations

- Step Functions: $0.025 per 1,000 state transitions
- Lambda: Based on execution time and memory
- CloudWatch Logs: Storage and data ingestion costs

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Customization Examples

### Example 1: Process S3 Files
Modify worker to process files from S3:
```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const { bucket, key } = event.item;
  const data = await s3.getObject({ Bucket: bucket, Key: key }).promise();
  // Process file data
  return { processed: true, key: key };
};
```

### Example 2: API Calls
Use workers to make parallel API calls:
```javascript
const axios = require('axios');

exports.handler = async (event) => {
  const response = await axios.get(event.item.url);
  return { url: event.item.url, data: response.data };
};
```

### Example 3: Database Operations
Process database records in parallel:
```javascript
const { DynamoDB } = require('aws-sdk');
const dynamodb = new DynamoDB.DocumentClient();

exports.handler = async (event) => {
  await dynamodb.put({
    TableName: 'MyTable',
    Item: event.item
  }).promise();
  return { processed: true, id: event.item.id };
};
```

## Troubleshooting

### Issue: Lambda timeout
- Increase timeout in `main.tf`
- Optimize worker code
- Break down large tasks

### Issue: Too many concurrent executions
- Reduce `MaxConcurrency` in state machine
- Check Lambda concurrency limits

### Issue: State machine fails
- Check CloudWatch Logs
- Verify IAM permissions
- Test Lambda functions individually

## Next Steps

1. Customize worker logic for your use case
2. Add monitoring and alerting
3. Implement DLQ for failed items
4. Add input validation
5. Set up CI/CD pipeline
