# IAM role for Lambda execution
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
        Resource = "${aws_apigatewayv2_api.ws_messenger_api_gateway.execution_arn}/*"
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
          aws_dynamodb_table.user-auth-table.arn,
          aws_dynamodb_table.ircode-transition-table.arn,
          aws_dynamodb_table.response-table.arn,
          aws_dynamodb_table.connection_table.arn
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
        Resource = "arn:aws:s3:::${var.BUCKET_NAME}/*"
      }
    ]
  })
}

# CloudWatch Logs permissions
resource "aws_iam_policy" "lambda_logging" {
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

# Attach all policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_apigateway_attachment" {
  role       = aws_iam_role.iam_for_lambda.arn
  policy_arn = aws_iam_policy.apigateway_management_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.iam_for_lambda.arn
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.iam_for_lambda.arn
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attachment" {
  role       = aws_iam_role.iam_for_lambda.arn
  policy_arn = aws_iam_policy.lambda_logging.arn
}