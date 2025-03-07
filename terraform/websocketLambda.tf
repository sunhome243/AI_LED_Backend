data "aws_iam_policy_document" "ws_messenger_lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }
  
  # Add DynamoDB permissions
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query"
    ]
    effect    = "Allow"
    resources = [aws_dynamodb_table.connection_table.arn]
  }
}

# Define the archive for WebSocket Lambda
data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/websocket/connection_manager.py"
  output_path = "${path.module}/ws_messenger.zip"
}

resource "aws_iam_policy" "ws_messenger_lambda_policy" {
  name   = "WsMessengerLambdaPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.ws_messenger_lambda_policy.json
}

resource "aws_iam_role" "ws_messenger_lambda_role" {
  name = "WsMessengerLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [aws_iam_policy.ws_messenger_lambda_policy.arn]
}

resource "aws_lambda_function" "ws_messenger_lambda" {
  filename         = data.archive_file.ws_messenger_zip.output_path
  function_name    = "ws-messenger"
  role             = aws_iam_role.ws_messenger_lambda_role.arn
  handler          = "connection_manager.lambda_handler"  # Updated handler
  runtime          = "python3.12"
  source_code_hash = data.archive_file.ws_messenger_zip.output_base64sha256
  
  environment {
    variables = {
      CONNECTION_TABLE = aws_dynamodb_table.connection_table.name
    }
  }
}

resource "aws_cloudwatch_log_group" "ws_messenger_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ws_messenger_lambda.function_name}"
  retention_in_days = 30
}