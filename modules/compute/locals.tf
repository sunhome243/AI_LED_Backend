locals {
  lambda_common = {
    runtime  = "python3.9"
    role_arn = var.lambda_role_arn
  }

  # Define function names to be used consistently
  function_names = {
    audio_to_ai     = "audio-to-ai"
    pattern_to_ai   = "pattern-to-ai"
    result_save_send = "result-save-send"
    ws_messenger    = "ws-messenger"
    isConnect       = "is-connect"
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
        BUCKET_NAME           = var.response_bucket_name
        REGION_NAME           = var.REGION_NAME
        WEBSOCKET_URL         = replace(
          "${var.websocket_endpoint}/${var.websocket_stage_name}",
          "wss://", 
          ""
        )
      }
    },
    ws_messenger = {
      source_path = "${local.base_dir}/lambda/websocket/connection_manager.py"
      handler     = "connection_manager.lambda_handler"
      environment = {
        CONNECTION_TABLE = var.connection_table_name
      }
    },
    isConnect = {
      source_path = "${local.base_dir}/lambda/websocket/isConnect.py"
      handler     = "isConnect.lambda_handler" 
      environment = {
        CONNECTION_TABLE = var.connection_table_name
      }
    }
  }

  # Add conditional logic for managing CloudWatch Log Groups
  manage_log_groups = false
}
