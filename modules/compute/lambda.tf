# Common configuration for Lambda functions
locals {

}

# Generate Lambda functions dynamically based on the configuration in locals.tf
resource "aws_lambda_function" "audio_to_ai" {
  filename         = data.archive_file.audio_to_ai_lambda.output_path
  function_name    = local.function_names.audio_to_ai
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.audio_to_ai.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = data.archive_file.audio_to_ai_lambda.output_base64sha256
  memory_size      = 128
  timeout          = 30
  
  # Ensure layer is attached and dependency is explicit
  layers           = [aws_lambda_layer_version.dependencies_layer.arn]
  depends_on       = [aws_lambda_layer_version.dependencies_layer]

  environment {
    variables = local.lambda_functions.audio_to_ai.environment
  }
}

resource "aws_lambda_function" "pattern_to_ai" {
  filename         = data.archive_file.pattern_to_ai_lambda.output_path
  function_name    = local.function_names.pattern_to_ai
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.pattern_to_ai.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = data.archive_file.pattern_to_ai_lambda.output_base64sha256
  memory_size      = 128
  timeout          = 30
  
  # Ensure layer is attached and dependency is explicit
  layers           = [aws_lambda_layer_version.dependencies_layer.arn]
  depends_on       = [aws_lambda_layer_version.dependencies_layer]

  environment {
    variables = local.lambda_functions.pattern_to_ai.environment
  }
}

resource "aws_lambda_function" "result_save_send" {
  filename         = data.archive_file.result_save_send_lambda.output_path
  function_name    = local.function_names.result_save_send
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.result_save_send.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = data.archive_file.result_save_send_lambda.output_base64sha256
  memory_size      = 256  # Increase memory for better performance
  timeout          = 30   # Increase timeout to handle async operations
  
  # Ensure layer is attached and dependency is explicit
  layers           = [aws_lambda_layer_version.dependencies_layer.arn]
  depends_on       = [aws_lambda_layer_version.dependencies_layer]

  environment {
    variables = local.lambda_functions.result_save_send.environment
  }
}

resource "aws_lambda_function" "isConnect" {
  filename         = data.archive_file.isConnect_lambda.output_path
  function_name    = local.function_names.isConnect
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.isConnect.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = data.archive_file.isConnect_lambda.output_base64sha256
  memory_size      = 128
  timeout          = 10

  environment {
    variables = local.lambda_functions.isConnect.environment
  }
}

# Create CloudWatch log group for the isConnect function
resource "aws_cloudwatch_log_group" "isConnect_logs" {
  name              = "/aws/lambda/${aws_lambda_function.isConnect.function_name}"
  retention_in_days = 30
}