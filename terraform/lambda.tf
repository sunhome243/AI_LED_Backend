# Common configuration for Lambda functions
locals {
  lambda_common = {
    runtime  = "python3.12"
    role_arn = aws_iam_role.iam_for_lambda.arn
  }
}

# Audio processing Lambda function
resource "aws_lambda_function" "audio_to_ai_lambda" {
  filename         = "${path.module}/audio_to_ai.zip"
  function_name    = "audio_to_ai"
  role             = local.lambda_common.role_arn
  source_code_hash = data.archive_file.audio_to_ai_lambda.output_base64sha256
  runtime          = local.lambda_common.runtime

  environment {
    variables = {
      # Add specific environment variables as needed
      foo = "bar"
    }
  }
}

# Pattern processing Lambda function
resource "aws_lambda_function" "pattern_to_ai_lambda" {
  filename         = "${path.module}/pattern_to_ai.zip"
  function_name    = "pattern_to_ai"
  role             = local.lambda_common.role_arn
  source_code_hash = data.archive_file.pattern_to_ai_lambda.output_base64sha256
  runtime          = local.lambda_common.runtime

  environment {
    variables = {
      # Add specific environment variables as needed
      foo = "bar"
    }
  }
}

# Result processing and WebSocket communication Lambda function
resource "aws_lambda_function" "result_save_send_lambda" {
  filename         = "${path.module}/result_save_send.zip"
  function_name    = "result_save_send"
  role             = local.lambda_common.role_arn
  source_code_hash = data.archive_file.result_save_send_lambda.output_base64sha256
  runtime          = local.lambda_common.runtime

  environment {
    variables = {
      GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
      BUCKET_NAME           = var.BUCKET_NAME
      REGION_NAME           = var.REGION_NAME
      WEBSOCKET_URL         = "${aws_apigatewayv2_api.ws_messenger_api_gateway.api_endpoint}/${aws_apigatewayv2_stage.ws_messenger_api_stage.name}"
    }
  }
}