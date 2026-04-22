############   Worker service #################
###############################################
module "worker_service" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "worker-service"
  handler       = "index.handler"
  runtime       = "nodejs24.x"
  source_path   = "${path.module}/lambda/worker"

  tags = {
    Name = "Worker Service"
  }
}

############  Aggregator service #################
###############################################
module "aggregator_service" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "aggregator-service"
  handler       = "index.handler"
  runtime       = "nodejs24.x"
  source_path   = "${path.module}/lambda/aggregator"

  tags = {
    Name = "Worker Service"
  }
}

######  Scatter and Gather service  #################
#####################################################
resource "aws_sfn_state_machine" "scatter_gather_service" {
  role_arn = module.scatter_service_role.arn
  definition = templatefile("${path.module}/step-function/state-machine.asl.json", {
    worker_lambda_arn     = module.worker_service.lambda_function_arn
    aggregator_lambda_arn = module.aggregator_service.lambda_function_arn
  })
}

######  IAM role for scatter_gather_service ##########
###########################################################
module "scatter_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "scatter-gather-service-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["states.amazonaws.com"]
      }]
    }
  }

  policies = {
    Lambda = aws_iam_policy.sfn_function_lambda_policy.arn
  }

  tags = {
    Name = "Scatter Service IAM Role"
  }
}


############  IAM policy document for catter-gather-service-role ##########
############################################################################
resource "aws_iam_policy" "sfn_function_lambda_policy" {
  name   = "sfn-lambda-permission"
  policy = data.aws_iam_policy_document.step_function_lambda_policy_document.json
}

######  S3 Bucket for scatter-gather results  ##############################
############################################################################
module "scatter_gather_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "scatter-gather-results"

  force_destroy = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    Name = "Scatter Gather Results Bucket"
  }
}
