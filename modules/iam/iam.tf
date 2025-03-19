# Common IAM role for all Lambda functions
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "IAM role for Lambda functions with permissions for DynamoDB, S3, CloudWatch, and API Gateway"
}

# Reference existing CloudWatch Logs permissions policy instead of creating it
data "aws_iam_policy" "lambda_logging_policy" {
  name = "lambda_logging_policy"
}

# Reference existing API Gateway Management policy
data "aws_iam_policy" "apigateway_management_policy" {
  name = "lambda_apigateway_management_policy"
}

# Reference existing DynamoDB access policy
data "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"
}

# Reference existing S3 access policy
data "aws_iam_policy" "lambda_s3_policy" {
  name = "lambda_s3_policy"
}

# Reference existing Lambda invocation policy
data "aws_iam_policy" "lambda_invoke_policy" {
  name = "lambda_invoke_policy"
}

resource "aws_iam_role" "api_gateway_role" {
  name = "api_gateway_cloudwatch_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com",
        },
        Action    = "sts:AssumeRole",
      },
    ],
  })
}

# Reference existing API Gateway CloudWatch logging policy
data "aws_iam_policy" "api_gateway_logging_policy" {
  name = "api_gateway_logging_policy"
}

# Reference existing Lambda-to-Lambda invocation policy
data "aws_iam_policy" "lambda_to_lambda_policy" {
  name = "lambda_to_lambda_policy"
}

# Attach all policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_apigateway_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = data.aws_iam_policy.apigateway_management_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = data.aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = data.aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = data.aws_iam_policy.lambda_logging_policy.arn
}

resource "aws_iam_role_policy_attachment" "api_gateway_logs_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = data.aws_iam_policy.lambda_logging_policy.arn
}

# Attach API Gateway specific logging policy
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = data.aws_iam_policy.api_gateway_logging_policy.arn
}

# Attach Lambda invoke permissions to API Gateway role
resource "aws_iam_role_policy_attachment" "api_gateway_lambda_invoke_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = data.aws_iam_policy.lambda_invoke_policy.arn
}

# Attach Lambda-to-Lambda invocation policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_to_lambda_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = data.aws_iam_policy.lambda_to_lambda_policy.arn
}