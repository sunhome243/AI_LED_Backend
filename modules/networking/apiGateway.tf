# REST API Gateway Configuration
# This defines the REST API Gateway resources for handling various API endpoints

# Main API Gateway resource
resource "aws_api_gateway_rest_api" "rest_api" {
  name = var.rest_api_name
  endpoint_configuration {
    types = ["EDGE"]
  }
}

# ==============================================
# API Resource Path Definitions
# ==============================================

# First-level resource paths
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

# Second-level resource paths
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

# Root-level resource for connection check
resource "aws_api_gateway_resource" "is_connect" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "is_connect"
}

# ==============================================
# API Method Definitions
# ==============================================

# HTTP methods for each resource endpoint
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

# CloudWatch configuration for API Gateway logging
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = var.gateway_role_arn
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api_gateway/${var.rest_api_name}"
  retention_in_days = 7
}

# ==============================================
# API Lambda Integrations
# ==============================================

# Pattern to AI Lambda integration
resource "aws_api_gateway_integration" "pattern_to_ai_api_int" {
  depends_on = [aws_api_gateway_method.pattern_to_ai_http_method]
  
  http_method             = aws_api_gateway_method.pattern_to_ai_http_method.http_method
  resource_id             = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.pattern_to_ai_lambda_arn}/invocations"
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# Audio to AI Lambda integration
resource "aws_api_gateway_integration" "audio_to_ai_api_int" {
  http_method             = aws_api_gateway_method.audio_to_ai_http_method.http_method
  resource_id             = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.audio_to_ai_lambda_arn}/invocations"
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# Is Connect Lambda integration
resource "aws_api_gateway_integration" "is_connect_api_int" {
  http_method             = aws_api_gateway_method.is_connect_http_method.http_method
  resource_id             = aws_api_gateway_resource.is_connect.id
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.isConnect_lambda_arn}/invocations"
  content_handling        = "CONVERT_TO_TEXT"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# ==============================================
# CORS Configuration - OPTIONS Methods
# ==============================================

# OPTIONS methods for CORS preflight requests
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
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
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
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Add integration responses for POST methods to set CORS headers
resource "aws_api_gateway_integration_response" "pattern_to_ai_integration_response" {
  depends_on = [
    aws_api_gateway_integration.pattern_to_ai_api_int,
    aws_api_gateway_method_response.pattern_to_ai_response
  ]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.pattern_to_ai_http_method.http_method
  status_code = aws_api_gateway_method_response.pattern_to_ai_response.status_code
  
  # For Lambda proxy integration, the actual response is managed by Lambda
  # but we can add headers
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "audio_to_ai_integration_response" {
  depends_on = [
    aws_api_gateway_integration.audio_to_ai_api_int,
    aws_api_gateway_method_response.audio_to_ai_response
  ]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  http_method = aws_api_gateway_method.audio_to_ai_http_method.http_method
  status_code = aws_api_gateway_method_response.audio_to_ai_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "is_connect_integration_response" {
  depends_on = [
    aws_api_gateway_integration.is_connect_api_int,
    aws_api_gateway_method_response.is_connect_response
  ]
  
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.is_connect.id
  http_method = aws_api_gateway_method.is_connect_http_method.http_method
  status_code = aws_api_gateway_method_response.is_connect_response.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

// Add Lambda permissions for API Gateway to invoke each Lambda function
resource "aws_lambda_permission" "pattern_to_ai_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.pattern_to_ai_function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN restricts which API Gateway endpoints can invoke the Lambda
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/${aws_api_gateway_method.pattern_to_ai_http_method.http_method}${aws_api_gateway_resource.pattern_to_ai_gateway_resource.path}"
}

resource "aws_lambda_permission" "audio_to_ai_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.audio_to_ai_function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/${aws_api_gateway_method.audio_to_ai_http_method.http_method}${aws_api_gateway_resource.audio_to_ai_gateway_resource.path}"
}

resource "aws_lambda_permission" "is_connect_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.isConnect_function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/${aws_api_gateway_method.is_connect_http_method.http_method}${aws_api_gateway_resource.is_connect.path}"
}

# API Gateway Deployment with improved dependency handling and timeouts
resource "aws_api_gateway_deployment" "deploy" {
    depends_on = [
      aws_api_gateway_integration.pattern_to_ai_api_int,
      aws_api_gateway_integration.audio_to_ai_api_int,
      aws_api_gateway_integration.is_connect_api_int,
      aws_api_gateway_integration_response.pattern_to_ai_integration_response,
      aws_api_gateway_integration_response.audio_to_ai_integration_response,
      aws_api_gateway_integration_response.is_connect_integration_response,
      aws_api_gateway_gateway_response.default_4xx,
      aws_api_gateway_gateway_response.default_5xx,
      aws_api_gateway_gateway_response.unauthorized,
      aws_api_gateway_gateway_response.access_denied
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

# Add Gateway Response configuration to handle CORS for error responses
resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  response_type = "DEFAULT_4XX"
  
  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "gatewayresponse.header.Access-Control-Expose-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  response_type = "DEFAULT_5XX"
  
  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "gatewayresponse.header.Access-Control-Expose-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }
}

# Update Gateway Response for Unauthorized errors specifically
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  response_type = "UNAUTHORIZED"
  
  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
  }
}

# Add ACCESS_DENIED response configuration
resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  response_type = "ACCESS_DENIED"
  
  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
  }
}

