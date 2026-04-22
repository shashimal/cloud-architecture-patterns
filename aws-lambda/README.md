# AWS Lambda Function with Terraform

A simple AWS Lambda function pattern demonstrating Terraform best practices for serverless deployments.

## Architecture

This pattern creates:

- **Lambda Function**: Node.js 20.x function with ARM64 architecture for cost optimization
- **IAM Role**: Execution role with least-privilege permissions
- **CloudWatch Logs**: Automatic log group with configurable retention
- **Function URL**: Direct HTTP endpoint without API Gateway

## Usage

```hcl
# Deploy with default settings
terraform init
terraform plan
terraform apply

# Or customize with variables
terraform apply -var="function_name=my-api" -var="environment=prod"
```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | AWS region for deployment | `ap-southeast-1` |
| `function_name` | Name of the Lambda function | `hello-world-lambda` |
| `environment` | Environment name | `dev` |
| `log_retention_days` | CloudWatch logs retention | `14` |

## Outputs

| Name | Description |
|------|-------------|
| `lambda_function_arn` | ARN of the Lambda function |
| `lambda_function_name` | Name of the Lambda function |
| `lambda_function_url` | HTTP endpoint URL |
| `lambda_role_arn` | ARN of the execution role |

## Testing

After deployment, test the function URL:

```bash
curl $(terraform output -raw lambda_function_url)
```
