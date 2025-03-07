locals {
  base_dir = path.root
  
  # Lambda function configurations
  lambda_functions = {
    audio_to_ai = {
      source_path = "${local.base_dir}/lambda/audio_to_ai/audio_to_ai.py"
      handler     = "audio_to_ai.lambda_handler"
      environment = {
        foo = "bar"
      }
    },
    pattern_to_ai = {
      source_path = "${local.base_dir}/lambda/pattern_to_ai/pattern_to_ai.py"
      handler     = "pattern_to_ai.lambda_handler"
      environment = {
        foo = "bar"
      }
    },
    result_save_send = {
      source_path = "${local.base_dir}/lambda/result_save_send/result_save_send.py"
      handler     = "result_save_send.lambda_handler"
      environment = {
        GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
        BUCKET_NAME           = var.BUCKET_NAME
        REGION_NAME           = var.REGION_NAME
        WEBSOCKET_URL         = "${aws_apigatewayv2_api.ws_messenger_api_gateway.api_endpoint}/${aws_apigatewayv2_stage.ws_messenger_api_stage.name}"
      }
    }
  }
}
