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
  description        = "IAM role for Lambda functions with necessary permissions"
}

# CloudWatch Logs permissions for all Lambda functions
resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "lambda_logging_policy"
  description = "Allow Lambda to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# API Gateway Management permissions
resource "aws_iam_policy" "apigateway_management_policy" {
  name        = "lambda_apigateway_management_policy"
  description = "Allow Lambda to use API Gateway Management API"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "execute-api:ManageConnections",
          "execute-api:Invoke"
        ]
        Effect   = "Allow"
        Resource = "*" # This will be attached later to specific API Gateway
      }
    ]
  })
}

# DynamoDB access permissions
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "Allow Lambda to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [
          var.auth_table_arn,
          var.ircode_table_arn,
          var.response_table_arn,
          var.connection_table_arn
        ]
      }
    ]
  })
}

# S3 access permissions
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  description = "Allow Lambda to write to S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.response_bucket_name}/*"
      }
    ]
  })
}

# Lambda invocation policy for API Gateway
resource "aws_iam_policy" "lambda_invoke_policy" {
  name        = "lambda_invoke_policy"
  description = "Allow API Gateway to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = "*"  # You can restrict this to specific Lambda ARNs for better security
      }
    ]
  })
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

# Specific policy for API Gateway CloudWatch logging
resource "aws_iam_policy" "api_gateway_logging_policy" {
  name        = "api_gateway_logging_policy"
  description = "Allow API Gateway to push logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Add new Lambda-to-Lambda invocation policy
resource "aws_iam_policy" "lambda_to_lambda_policy" {
  name        = "lambda_to_lambda_policy"
  description = "Allow Lambda functions to invoke other Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeAsync"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:lambda:*:*:function:*"  # Consider restricting to specific functions for better security
      }
    ]
  })
}

# Attach all policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_apigateway_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.apigateway_management_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

resource "aws_iam_role_policy_attachment" "api_gateway_logs_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

# Attach API Gateway specific logging policy
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = aws_iam_policy.api_gateway_logging_policy.arn
}

# Attach Lambda invoke permissions to API Gateway role
resource "aws_iam_role_policy_attachment" "api_gateway_lambda_invoke_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = aws_iam_policy.lambda_invoke_policy.arn
}

# Attach Lambda-to-Lambda invocation policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_to_lambda_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_to_lambda_policy.arn
}