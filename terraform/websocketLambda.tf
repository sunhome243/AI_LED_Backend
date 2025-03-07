resource "aws_lambda_function" "ws_messenger_lambda" {
  filename         = data.archive_file.ws_messenger_zip.output_path
  function_name    = "ws-messenger"
  role             = local.lambda_common.role_arn
  handler          = "connection_manager.lambda_handler"
  runtime          = local.lambda_common.runtime
  source_code_hash = data.archive_file.ws_messenger_zip.output_base64sha256
  
  environment {
    variables = {
      CONNECTION_TABLE = aws_dynamodb_table.connection_table.name
    }
  }
}
