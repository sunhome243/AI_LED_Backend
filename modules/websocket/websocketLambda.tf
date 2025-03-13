locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
  
  # Calculate hash of WebSocket Lambda source files
  ws_messenger_files = [
    for file in fileset("${local.base_dir}/lambda/websocket", "**") : 
    "${local.base_dir}/lambda/websocket/${file}"
  ]
  
  ws_messenger_hash = sha256(join("", [
    for file in local.ws_messenger_files : filebase64(file)
  ]))
}

resource "aws_lambda_function" "ws_messenger_lambda" {
  filename         = data.archive_file.ws_messenger_zip.output_path
  function_name    = "ws-messenger"
  role             = var.lambda_role_arn
  handler          = "connection_manager.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = local.ws_messenger_hash
  
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
  output_file_mode = "0644"
}

resource "aws_cloudwatch_log_group" "ws_messenger_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ws_messenger_lambda.function_name}"
  retention_in_days = 30
}
