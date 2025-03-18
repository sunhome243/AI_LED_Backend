# Common configuration for Lambda functions
locals {
  # Lambda 기본 설정
  default_memory = 256
  default_timeout = 30
  small_memory = 128
  small_timeout = 10
  
  # 단순화된 함수 정의
  functions_to_create = {
    "audio_to_ai" = {
      filename         = data.archive_file.audio_to_ai_lambda.output_path
      function_name    = local.function_names.audio_to_ai
      handler          = local.lambda_functions.audio_to_ai.handler
      source_code_hash = data.archive_file.audio_to_ai_lambda.output_base64sha256
      memory_size      = local.default_memory
      timeout          = local.default_timeout
      environment      = merge(local.lambda_functions.audio_to_ai.environment, {
        PYTHONPATH = "/opt/python/lib/python3.9/site-packages:/var/task"
        # Add layer version to force redeployment when layer changes
        LAMBDA_LAYER_VERSION = var.lambda_layer_version
      })
    },
    "pattern_to_ai" = {
      filename         = data.archive_file.pattern_to_ai_lambda.output_path
      function_name    = local.function_names.pattern_to_ai
      handler          = local.lambda_functions.pattern_to_ai.handler
      source_code_hash = data.archive_file.pattern_to_ai_lambda.output_base64sha256
      memory_size      = local.default_memory
      timeout          = local.default_timeout
      environment      = merge(local.lambda_functions.pattern_to_ai.environment, {
        PYTHONPATH = "/opt/python/lib/python3.9/site-packages:/var/task"
      })
    },
    "result_save_send" = {
      filename         = data.archive_file.result_save_send_lambda.output_path
      function_name    = local.function_names.result_save_send
      handler          = local.lambda_functions.result_save_send.handler
      source_code_hash = data.archive_file.result_save_send_lambda.output_base64sha256
      memory_size      = local.default_memory
      timeout          = local.default_timeout
      environment      = merge(local.lambda_functions.result_save_send.environment, {
        PYTHONPATH = "/opt/python/lib/python3.9/site-packages:/var/task"
      })
    },
    "isConnect" = {
      filename         = data.archive_file.isConnect_lambda.output_path
      function_name    = local.function_names.isConnect
      handler          = local.lambda_functions.isConnect.handler
      source_code_hash = data.archive_file.isConnect_lambda.output_base64sha256
      memory_size      = local.small_memory
      timeout          = local.small_timeout
      environment      = merge(local.lambda_functions.isConnect.environment, {
        PYTHONPATH = "/opt/python/lib/python3.9/site-packages:/var/task" 
      })
    }
  }
}

# Lambda 함수 생성 - 모든 함수를 동일한 방식으로 관리
resource "aws_lambda_function" "functions" {
  for_each = local.functions_to_create
  
  filename         = each.value.filename
  function_name    = each.value.function_name
  role             = local.lambda_common.role_arn
  handler          = each.value.handler
  runtime          = local.lambda_common.runtime
  source_code_hash = each.value.source_code_hash
  memory_size      = each.value.memory_size
  timeout          = each.value.timeout
  publish          = true
  layers           = [var.lambda_layer_arn]

  # Proper lifecycle configuration that allows Lambda updates
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      tags,
      # Do NOT ignore publish or source_code_hash to allow proper updates
    ]
  }

  environment {
    variables = each.value.environment
  }
  
  # Force redeployment by adding explicit layer dependency
  depends_on = [
    null_resource.check_archive_sizes,
    null_resource.force_lambda_update  # New dependency
  ]
}

# Create a resource to force Lambda redeployment when layer changes
resource "null_resource" "force_lambda_update" {
  # This trigger will change whenever the Lambda layer changes
  triggers = {
    layer_version = var.lambda_layer_version
    layer_arn = var.lambda_layer_arn
    # Added timestamp to force redeployment on apply
    deployment_time = timestamp()
  }
}