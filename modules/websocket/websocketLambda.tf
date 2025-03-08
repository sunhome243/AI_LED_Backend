locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
}

resource "aws_lambda_function" "ws_messenger_lambda" {
  filename         = data.archive_file.ws_messenger_zip.output_path
  function_name    = "ws-messenger"
  role             = var.lambda_role_arn
  handler          = "connection_manager.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.ws_messenger_zip.output_base64sha256
  
  environment {
    variables = {
      CONNECTION_TABLE = var.connection_table_name
    }
  }
}

# Archive resource for Lambda code
data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/websocket/connection_manager.py"
  output_path = "${path.module}/archive/ws_messenger.zip"
}

resource "aws_cloudwatch_log_group" "ws_messenger_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ws_messenger_lambda.function_name}"
  retention_in_days = 30
}
