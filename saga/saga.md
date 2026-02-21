## Implementing the Saga Pattern on AWS with Terraform

*A step‑by‑step tutorial using a simple order workflow*

Distributed systems fail in messy ways. A payment might succeed while inventory reservation fails, or an order might be created but never confirmed. The **Saga pattern** is a way to manage these long‑lived, multi‑step business transactions safely.

In this tutorial, you’ll build a **centralized (orchestrated) Saga** on AWS using:

- **AWS Step Functions** – the Saga orchestrator  
- **AWS Lambda** – individual business and compensation steps  
- **Amazon DynamoDB** – to store orders and inventory  
- **Terraform** – to provision everything as code  

We’ll model a simple **“Place Order”** flow and show how to **roll back** when something goes wrong.

---

## 1. The Use Case: Place Order with Compensation

Imagine an e‑commerce system with this happy path:

1. **Create Order** – save a new order as `PENDING`  
2. **Charge Payment** – debit the customer  
3. **Reserve Inventory** – lock stock for the order  
4. **Complete** – mark the order as `CONFIRMED`  

But in reality, failures happen:

- Payment may fail  
- Inventory may be out of stock  
- Downstream systems may time out  

With the **Saga pattern**, each forward step has an optional **compensation step** that semantically undoes it:

- `CreateOrder` ⇢ compensate with `CancelOrder`  
- `ChargePayment` ⇢ compensate with `RefundPayment`  
- `ReserveInventory` ⇢ compensate with `ReleaseInventory`  

Our Saga will look like this:

- **Forward path**:  
  `CreateOrder → ChargePayment → ReserveInventory → Success`
- **On payment failure**:  
  `CreateOrder → ChargePayment (fails) → CancelOrder`
- **On inventory failure**:  
  `CreateOrder → ChargePayment → ReserveInventory (fails) → RefundPayment + ReleaseInventory → CancelOrder`

Step Functions will orchestrate all of this for us.

---

## 2. Architecture Overview

**Components:**

- **Step Functions State Machine**: central Saga orchestrator  
- **Lambda functions**:  
  - `create-order` / `cancel-order`  
  - `charge-payment` / `refund-payment`  
  - `reserve-inventory` / `release-inventory`
- **DynamoDB tables**:  
  - `orders` – order status, amount, items  
  - `inventory` – reserved items (simplified model)
- **IAM roles and policies**:  
  - One role for Lambdas (logs + DynamoDB)  
  - One role for Step Functions (invoke Lambdas + logs)  

**Execution flow:**

1. A client (API Gateway, CLI, or console) triggers the **Step Functions** state machine with input like:

   ```json
   {
     "orderId": "order-123",
     "items": [{ "id": "item-1", "qty": 1 }],
     "amount": 100
   }
   ```

2. The state machine runs each Lambda in order and executes the **compensation** chain if something fails.

---

## 3. Project & Terraform Structure

A simple layout for the project:

```text
saga/
  main.tf
  iam.tf
  order-process.asl.json
  lambda/
    create-order/
      index.js
    cancel-order/
      index.js
    charge-payment/
      index.js
    refund-payment/
      index.js
    reserve-inventory/
      index.js
    release-inventory/
      index.js
```

- `main.tf` – core Terraform resources (Lambdas, DynamoDB, Step Functions)  
- `iam.tf` – IAM roles and policies  
- `order-process.asl.json` – Step Functions state machine definition (ASL)  
- `lambda/*/index.js` – business logic for each Saga step  

---

## 4. Defining Services and Tables in Terraform

In `main.tf`, start with locals for services and tables:

```hcl
locals {
  services = {
    create-order = {
      name        = "create-order"
      description = "Create Order"
      environment_variables = {
        TABLE_NAME = "orders"
      }
    }

    cancel-order = {
      name        = "cancel-order"
      description = "Cancel Order"
      environment_variables = {
        TABLE_NAME = "orders"
      }
    }

    charge-payment = {
      name                  = "charge-payment"
      description           = "Charge Payment"
      environment_variables = {}
    }

    refund-payment = {
      name                  = "refund-payment"
      description           = "Refund Payment"
      environment_variables = {}
    }

    reserve-inventory = {
      name        = "reserve-inventory"
      description = "Reserve Inventory"
      environment_variables = {
        TABLE_NAME = "inventory"
      }
    }

    release-inventory = {
      name        = "release-inventory"
      description = "Release Inventory"
      environment_variables = {
        TABLE_NAME = "inventory"
      }
    }
  }

  tables = {
    orders = {
      name     = "orders"
      hash_key = "orderId"
      attribute = {
        name = "orderId"
        type = "S"
      }
    }
    inventory = {
      name     = "inventory"
      hash_key = "itemId"
      attribute = {
        name = "itemId"
        type = "S"
      }
    }
  }
}
```

### 4.1. DynamoDB Tables

Still in `main.tf`, create the tables:

```hcl
resource "aws_dynamodb_table" "this" {
  for_each = local.tables

  name         = each.value.name
  hash_key     = each.value.hash_key
  billing_mode = "PAY_PER_REQUEST"

  dynamic "attribute" {
    for_each = each.value.attribute != null ? [each.value.attribute] : []
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }
}
```

---

## 5. IAM Roles for Saga Execution

Create `iam.tf` and define roles/policies.

### 5.1. Lambda Execution Role

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "saga-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "saga-lambda-policy"
  description = "Allow Lambda to log and access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.this["orders"].arn,
          aws_dynamodb_table.this["inventory"].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
```

### 5.2. Step Functions Role

```hcl
resource "aws_iam_role" "sfn_role" {
  name = "saga-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "sfn_policy" {
  name = "saga-sfn-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = ["*"] # tighten to your lambdas in production
      },
      {
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_policy_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}
```

---

## 6. Creating Lambda Functions with Terraform

Use the community Lambda module (or raw `aws_lambda_function`). Here’s an example with the module:

```hcl
module "services" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  for_each      = local.services
  function_name = each.value.name
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  # Use inline source (directory) during development
  source_path = "${path.module}/lambda/${each.value.name}"

  create_role = false
  lambda_role = aws_iam_role.lambda_role.arn

  environment_variables = each.value.environment_variables

  tags = {
    Name        = each.value.name
    Description = each.value.description
  }
}
```

This will:

- Create one Lambda per entry in `local.services`  
- Point each to `lambda/<service-name>/index.js`  

---

## 7. Defining the Saga in Step Functions (ASL)

Create `order-process.asl.json` with the Saga logic:

```json
{
  "Comment": "Order Saga: create order, charge payment, reserve inventory with compensations",
  "StartAt": "CreateOrder",
  "States": {
    "CreateOrder": {
      "Type": "Task",
      "Resource": "${create_order_arn}",
      "ResultPath": "$.createOrderResult",
      "Next": "ChargePayment",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "CancelOrder"
        }
      ]
    },
    "ChargePayment": {
      "Type": "Task",
      "Resource": "${charge_payment_arn}",
      "ResultPath": "$.chargePaymentResult",
      "Next": "ReserveInventory",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "CancelOrder"
        }
      ]
    },
    "ReserveInventory": {
      "Type": "Task",
      "Resource": "${reserve_inventory_arn}",
      "ResultPath": "$.reserveInventoryResult",
      "Next": "Success",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "RefundAndCancel"
        }
      ]
    },
    "RefundAndCancel": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "RefundPayment",
          "States": {
            "RefundPayment": {
              "Type": "Task",
              "Resource": "${refund_payment_arn}",
              "End": true
            }
          }
        },
        {
          "StartAt": "ReleaseInventory",
          "States": {
            "ReleaseInventory": {
              "Type": "Task",
              "Resource": "${release_inventory_arn}",
              "End": true
            }
          }
        }
      ],
      "Next": "CancelOrder"
    },
    "CancelOrder": {
      "Type": "Task",
      "Resource": "${cancel_order_arn}",
      "End": true
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
```

Wire this into Terraform in `main.tf`:

```hcl
resource "aws_sfn_state_machine" "orchestrator" {
  name     = "orchestrator-service"
  role_arn = aws_iam_role.sfn_role.arn

  definition = templatefile("${path.module}/order-process.asl.json", {
    create_order_arn      = module.services["create-order"].lambda_function_arn
    cancel_order_arn      = module.services["cancel-order"].lambda_function_arn
    charge_payment_arn    = module.services["charge-payment"].lambda_function_arn
    refund_payment_arn    = module.services["refund-payment"].lambda_function_arn
    reserve_inventory_arn = module.services["reserve-inventory"].lambda_function_arn
    release_inventory_arn = module.services["release-inventory"].lambda_function_arn
  })
}
```

---

## 8. Implementing Lambda Handlers (Node.js)

These handlers are intentionally simple and synchronous to make the pattern clear. In production, you’d integrate with real payment and inventory systems.

### 8.1. `create-order/index.js`

```javascript
const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const orderId = event.orderId;
  const items = event.items;
  const amount = event.amount;

  await ddb
    .put({
      TableName: table,
      Item: {
        orderId,
        items,
        amount,
        status: "PENDING",
        createdAt: new Date().toISOString()
      }
    })
    .promise();

  return { orderId, amount, status: "PENDING" };
};
```

### 8.2. `cancel-order/index.js`

```javascript
const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const orderId =
    event.orderId ||
    (event.createOrderResult && event.createOrderResult.orderId);

  await ddb
    .update({
      TableName: table,
      Key: { orderId },
      UpdateExpression: "SET #s = :s",
      ExpressionAttributeNames: { "#s": "status" },
      ExpressionAttributeValues: { ":s": "CANCELLED" }
    })
    .promise();

  return { orderId, status: "CANCELLED" };
};
```

### 8.3. `charge-payment/index.js` (mock)

```javascript
exports.handler = async (event) => {
  const amount =
    event.amount ||
    (event.createOrderResult && event.createOrderResult.amount);

  // Demo: fail large payments to trigger compensation
  if (amount > 1000) {
    throw new Error("Payment declined: amount too large");
  }

  return {
    charged: true,
    transactionId: "tx-" + Date.now(),
    amount
  };
};
```

### 8.4. `refund-payment/index.js` (mock)

```javascript
exports.handler = async (event) => {
  const txId =
    (event.chargePaymentResult &&
      event.chargePaymentResult.transactionId) ||
    "unknown";

  // In a real system, call your payment provider here
  return {
    refunded: true,
    transactionId: txId
  };
};
```

### 8.5. `reserve-inventory/index.js`

```javascript
const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const items =
    event.items || (event.createOrderResult && event.createOrderResult.items);

  // Example: artificially fail if a special item is requested
  if (items.some((item) => item.id === "OUT_OF_STOCK")) {
    throw new Error("Inventory not available");
  }

  for (const item of items) {
    await ddb
      .put({
        TableName: table,
        Item: {
          itemId: item.id,
          reservedQty: item.qty
        }
      })
      .promise();
  }

  return { reserved: true };
};
```

### 8.6. `release-inventory/index.js`

```javascript
const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const table = process.env.TABLE_NAME;

  const items =
    event.items || (event.createOrderResult && event.createOrderResult.items);

  for (const item of items) {
    await ddb
      .delete({
        TableName: table,
        Key: { itemId: item.id }
      })
      .promise();
  }

  return { released: true };
};
```

---

## 9. Deploying the Saga with Terraform

### 9.1. Prerequisites

- Terraform installed  
- AWS credentials configured (`AWS_PROFILE` or `~/.aws/credentials`)  
- Node.js installed (for Lambda dependencies, if needed)

### 9.2. Initialize and Apply

From the `saga/` directory:

```bash
terraform init
terraform plan
terraform apply
```

Terraform will:

- Create DynamoDB tables  
- Deploy all six Lambda functions  
- Create IAM roles/policies  
- Provision the Step Functions state machine  

---

## 10. Testing the Saga

### 10.1. Happy Path (all steps succeed)

In the AWS Console:

1. Open **Step Functions** → your `orchestrator-service` state machine  
2. Click **Start execution** and use:

   ```json
   {
     "orderId": "order-100",
     "items": [{ "id": "item-1", "qty": 1 }],
     "amount": 100
   }
   ```

3. The execution should succeed and end in the `Success` state.

Check:

- **DynamoDB `orders`** table:  
  - Order `order-100` exists, initially `PENDING` (you can extend logic to move it to `CONFIRMED`).  
- **DynamoDB `inventory`** table:  
  - `item-1` reserved for this order.

### 10.2. Triggering Payment Failure

Start another execution:

```json
{
  "orderId": "order-200",
  "items": [{ "id": "item-1", "qty": 1 }],
  "amount": 2000
}
```

- `charge-payment` will fail (`amount > 1000`)  
- The Saga transitions to `CancelOrder` as compensation  

Check:

- `orders` table: `order-200` should be `CANCELLED`  
- `inventory` table: no reservations for this order (because inventory step never ran)

### 10.3. Triggering Inventory Failure

Start execution:

```json
{
  "orderId": "order-300",
  "items": [{ "id": "OUT_OF_STOCK", "qty": 1 }],
  "amount": 100
}
```

- `create-order` and `charge-payment` succeed  
- `reserve-inventory` throws “Inventory not available”  
- Saga runs `RefundPayment` and `ReleaseInventory` (in parallel)  
- Then `CancelOrder`  

Check:

- `orders` table: `order-300` is `CANCELLED`  
- `inventory` table: no lingering reservation for `OUT_OF_STOCK`  
- CloudWatch logs: refund and release actions executed  

---


