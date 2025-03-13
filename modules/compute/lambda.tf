# Common configuration for Lambda functions
locals {

}

# Generate Lambda functions dynamically based on the configuration in locals.tf
resource "aws_lambda_function" "audio_to_ai" {
  filename         = "${path.module}/archive/audio_to_ai.zip"
  function_name    = local.function_names.audio_to_ai
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.audio_to_ai.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = local.audio_to_ai_hash

  environment {
    variables = local.lambda_functions.audio_to_ai.environment
  }
}

resource "aws_lambda_function" "pattern_to_ai" {
  filename         = "${path.module}/archive/pattern_to_ai.zip"
  function_name    = local.function_names.pattern_to_ai
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.pattern_to_ai.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = local.pattern_to_ai_hash

  environment {
    variables = local.lambda_functions.pattern_to_ai.environment
  }
}

resource "aws_lambda_function" "result_save_send" {
  filename         = "${path.module}/archive/result_save_send.zip"
  function_name    = local.function_names.result_save_send
  role             = local.lambda_common.role_arn
  handler          = local.lambda_functions.result_save_send.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = local.result_save_send_hash

  environment {
    variables = local.lambda_functions.result_save_send.environment
  }
}