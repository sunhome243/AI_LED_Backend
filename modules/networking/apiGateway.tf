resource "aws_api_gateway_rest_api" "rest_api" {
  name = "${var.rest_api_name}"
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

resource "aws_api_gateway_integration" "pattern_to_ai_api_int" {
  http_method = aws_api_gateway_method.pattern_to_ai_http_method.http_method
  resource_id = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = var.pattern_to_ai_lambda_arn
}

resource "aws_api_gateway_integration" "audio_to_ai_api_int" {
  http_method = aws_api_gateway_method.audio_to_ai_http_method.http_method
  resource_id = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = var.audio_to_ai_lambda_arn
}

resource "aws_api_gateway_integration" "is_connect_api_int" {
  http_method = aws_api_gateway_method.is_connect_http_method.http_method
  resource_id = aws_api_gateway_resource.is_connect.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = var.isConnect_lambda_arn
}

resource "aws_api_gateway_deployment" "deploy" {
    depends_on = [
      aws_api_gateway_integration.pattern_to_ai_api_int,
      aws_api_gateway_integration.audio_to_ai_api_int,
      aws_api_gateway_integration.is_connect_api_int
    ]
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    triggers = {
    redeployment = sha1(jsonencode([
        aws_api_gateway_rest_api.rest_api.body,
        aws_api_gateway_rest_api.rest_api.root_resource_id,
        aws_api_gateway_method.pattern_to_ai_http_method.id,
        aws_api_gateway_integration.pattern_to_ai_api_int.id,
        aws_api_gateway_method.audio_to_ai_http_method.id,
        aws_api_gateway_integration.audio_to_ai_api_int.id,
        aws_api_gateway_method.is_connect_http_method.id,
        aws_api_gateway_integration.is_connect_api_int.id,
    ]))
  }
  lifecycle {
        create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "${var.stage_name}"
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = var.gateway_role_arn
}

resource "aws_api_gateway_method_settings" "audio_to_ai_method_settings" {
  depends_on = [aws_api_gateway_account.api_gateway_account]
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled = true
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api_gateway/${var.rest_api_name}"
  retention_in_days = 7
}

# Permission for API Gateway to invoke the isConnect Lambda function
resource "aws_lambda_permission" "isConnect_api_permission" {
  statement_id  = "AllowAPIGatewayToInvokeIsConnect"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.isConnect_lambda_arn)[6]  # Extract function name from ARN
  principal     = "apigateway.amazonaws.com"
  # More specific source ARN for this endpoint
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/${aws_api_gateway_method.is_connect_http_method.http_method}${aws_api_gateway_resource.is_connect.path}"
  depends_on    = [aws_api_gateway_integration.is_connect_api_int]
}

# Add these Lambda permissions for all Lambda functions to ensure they can be invoked by API Gateway
resource "aws_lambda_permission" "pattern_to_ai_api_permission" {
  statement_id  = "AllowAPIGatewayToInvokePatternToAi"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.pattern_to_ai_lambda_arn)[6]  # Extract function name from ARN
  principal     = "apigateway.amazonaws.com"
  # More specific source ARN for this endpoint
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/${aws_api_gateway_method.pattern_to_ai_http_method.http_method}${aws_api_gateway_resource.pattern_to_ai_gateway_resource.path}"
  depends_on    = [aws_api_gateway_integration.pattern_to_ai_api_int]
}

resource "aws_lambda_permission" "audio_to_ai_api_permission" {
  statement_id  = "AllowAPIGatewayToInvokeAudioToAi"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.audio_to_ai_lambda_arn)[6]  # Extract function name from ARN
  principal     = "apigateway.amazonaws.com"
  # More specific source ARN for this endpoint
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/${aws_api_gateway_method.audio_to_ai_http_method.http_method}${aws_api_gateway_resource.audio_to_ai_gateway_resource.path}"
  depends_on    = [aws_api_gateway_integration.audio_to_ai_api_int]
}

