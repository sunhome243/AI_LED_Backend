resource "aws_api_gateway_rest_api" "rest_api" {
  name = var.rest_api_name
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "pattern_to_ai" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "pattern_to_ai"
}

resource "aws_api_gateway_resource" "audio_to_ai" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "audio_to_ai"
}

resource "aws_api_gateway_resource" "pattern_to_ai_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.pattern_to_ai.id
  path_part   = "create"
}

resource "aws_api_gateway_resource" "audio_to_ai_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.audio_to_ai.id
  path_part   = "create"
}

resource "aws_api_gateway_resource" "is_connect" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "is_connect"
}

resource "aws_api_gateway_method" "pattern_to_ai_http_method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
}

resource "aws_api_gateway_method" "audio_to_ai_http_method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
}

resource "aws_api_gateway_method" "is_connect_http_method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.is_connect.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
}

# Integrations were moved to main.tf to break circular dependencies

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = var.gateway_role_arn
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api_gateway/${var.rest_api_name}"
  retention_in_days = 7
}

# API Gateway Integrations - moved from main.tf
resource "aws_api_gateway_integration" "pattern_to_ai_api_int" {
  depends_on = [aws_api_gateway_method.pattern_to_ai_http_method]
  
  http_method             = aws_api_gateway_method.pattern_to_ai_http_method.http_method
  resource_id             = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.pattern_to_ai_lambda_arn
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_integration" "audio_to_ai_api_int" {
  http_method             = aws_api_gateway_method.audio_to_ai_http_method.http_method
  resource_id             = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.audio_to_ai_lambda_arn
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_integration" "is_connect_api_int" {
  http_method             = aws_api_gateway_method.is_connect_http_method.http_method
  resource_id             = aws_api_gateway_resource.is_connect.id
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.isConnect_lambda_arn
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# CORS Configuration - OPTIONS Methods
resource "aws_api_gateway_method" "pattern_to_ai_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "audio_to_ai_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "is_connect_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.is_connect.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS Configuration - Mock Integrations for OPTIONS
resource "aws_api_gateway_integration" "pattern_to_ai_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.pattern_to_ai_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration" "audio_to_ai_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.audio_to_ai_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration" "is_connect_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.is_connect.id
  http_method = aws_api_gateway_method.is_connect_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# CORS Configuration - Method Responses for OPTIONS
resource "aws_api_gateway_method_response" "pattern_to_ai_options_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.pattern_to_ai_options_method.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "audio_to_ai_options_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.audio_to_ai_options_method.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "is_connect_options_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.is_connect.id
  http_method = aws_api_gateway_method.is_connect_options_method.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# CORS Configuration - Integration Responses for OPTIONS
resource "aws_api_gateway_integration_response" "pattern_to_ai_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.pattern_to_ai_options_method.http_method
  status_code = aws_api_gateway_method_response.pattern_to_ai_options_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "audio_to_ai_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.audio_to_ai_options_method.http_method
  status_code = aws_api_gateway_method_response.audio_to_ai_options_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "is_connect_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.is_connect.id
  http_method = aws_api_gateway_method.is_connect_options_method.http_method
  status_code = aws_api_gateway_method_response.is_connect_options_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Define method responses with explicit dependencies
resource "aws_api_gateway_method_response" "pattern_to_ai_response" {
  depends_on = [
    aws_api_gateway_method.pattern_to_ai_http_method,
    aws_api_gateway_integration.pattern_to_ai_api_int
  ]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.pattern_to_ai_http_method.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  # Add lifecycle block to prevent recreation
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_response" "audio_to_ai_response" {
  depends_on = [
    aws_api_gateway_method.audio_to_ai_http_method,
    aws_api_gateway_integration.audio_to_ai_api_int
  ]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.audio_to_ai_http_method.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_response" "is_connect_response" {
  depends_on = [
    aws_api_gateway_method.is_connect_http_method,
    aws_api_gateway_integration.is_connect_api_int
  ]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.is_connect.id
  http_method = aws_api_gateway_method.is_connect_http_method.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Deployment with improved dependency handling and timeouts
resource "aws_api_gateway_deployment" "deploy" {
    depends_on = [
      aws_api_gateway_integration.pattern_to_ai_api_int,
      aws_api_gateway_integration.audio_to_ai_api_int,
      aws_api_gateway_integration.is_connect_api_int
    ]
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    triggers = {
      # Improved trigger that uses all relevant resources
      redeployment = sha1(jsonencode([
        aws_api_gateway_resource.pattern_to_ai.id,
        aws_api_gateway_resource.audio_to_ai.id,
        aws_api_gateway_resource.is_connect.id,
        aws_api_gateway_method.pattern_to_ai_http_method.id,
        aws_api_gateway_method.audio_to_ai_http_method.id,
        aws_api_gateway_method.is_connect_http_method.id,
        aws_api_gateway_integration.pattern_to_ai_api_int.id,
        aws_api_gateway_integration.audio_to_ai_api_int.id,
        aws_api_gateway_integration.is_connect_api_int.id
      ]))
    }
  lifecycle {
    create_before_destroy = true
  }

  # Add sleep to ensure API Gateway resources are fully created
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

resource "aws_api_gateway_stage" "stage" {
  depends_on = [aws_api_gateway_deployment.deploy]
  
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = var.stage_name
}

# Configure method settings for the API Gateway
resource "aws_api_gateway_method_settings" "api_settings" {
  depends_on = [aws_api_gateway_stage.stage]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true
    metrics_enabled    = true
    logging_level      = "INFO"
  }
}

