locals {

  lambda_common = {
    runtime  = "python3.9"
    role_arn = aws_iam_role.iam_for_lambda.arn
  }

  # Define function names to be used consistently
  function_names = {
    audio_to_ai     = "audio-to-ai"
    pattern_to_ai   = "pattern-to-ai"
    result_save_send = "result-save-send"
    ws_messenger    = "ws-messenger"
  }

  # Lambda function configurations
  lambda_functions = {
    audio_to_ai = {
      source_path = "${local.base_dir}/lambda/audio_to_ai/audio_to_ai.py"
      handler     = "audio_to_ai.lambda_handler"
      environment = {
        GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
        REGION_NAME           = var.REGION_NAME
        RESULT_LAMBDA_NAME    = local.function_names.result_save_send
      }
    },
    pattern_to_ai = {
      source_path = "${local.base_dir}/lambda/pattern_to_ai/pattern_to_ai.py"
      handler     = "pattern_to_ai.lambda_handler"
      environment = {
        GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
        REGION_NAME           = var.REGION_NAME
        RESULT_LAMBDA_NAME    = local.function_names.result_save_send
      }
    },
    result_save_send = {
      source_path = "${local.base_dir}/lambda/result_save_send/result_save_send.py"
      handler     = "result_save_send.lambda_handler"
      environment = {
        GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
        BUCKET_NAME           = aws_s3_bucket.response-data.bucket
        REGION_NAME           = var.REGION_NAME
        WEBSOCKET_URL         = "${aws_apigatewayv2_api.ws_messenger_api_gateway.api_endpoint}/${aws_apigatewayv2_stage.ws_messenger_api_stage.name}"
      }
    },
    ws_messenger = {
      source_path = "${local.base_dir}/lambda/websocket/connection_manager.py"
      handler     = "connection_manager.lambda_handler"
      environment = {
        CONNECTION_TABLE = aws_dynamodb_table.connection_table.name
      }
    }
  }
}
