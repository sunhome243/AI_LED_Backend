locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
  
  # Calculate hash of WebSocket Lambda source files
  ws_messenger_files = [
    for file in fileset("${local.base_dir}/lambda/websocket", "**") : 
    "${local.base_dir}/lambda/websocket/${file}"
  ]
  
  # More reliable source hash calculation
  ws_messenger_source_hash = sha256(join("", [for f in local.ws_messenger_files : filesha256(f)]))
}

resource "aws_lambda_function" "ws_messenger_lambda" {
  filename         = data.archive_file.ws_messenger_zip.output_path
  function_name    = "ws-messenger"
  role             = var.lambda_role_arn
  handler          = "connection_manager.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.ws_messenger_zip.output_base64sha256
  memory_size      = 128
  timeout          = 10
  
  environment {
    variables = {
      CONNECTION_TABLE = var.connection_table_name
    }
  }
}

# Resource removed to avoid duplication with the one in websocketGateway.tf

# Archive resource for Lambda code with unique filename based on hash
data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/websocket/connection_manager.py"
  output_path = "${path.module}/archive/ws_messenger_${local.ws_messenger_source_hash}.zip"
  output_file_mode = "0644"
}

resource "aws_cloudwatch_log_group" "ws_messenger_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ws_messenger_lambda.function_name}"
  retention_in_days = 30
}
