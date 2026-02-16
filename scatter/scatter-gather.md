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

## Cleanup

To destroy all resources:
```bash
terraform destroy
```



