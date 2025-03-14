resource "aws_apigatewayv2_api" "ws_messenger_api_gateway" {
  name                       = "ws-messenger-api-gateway"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "ws_messenger_api_integration" {
  api_id                    = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.ws_messenger_lambda.invoke_arn
  credentials_arn           = var.api_gateway_role_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
  passthrough_behavior      = "WHEN_NO_MATCH"
  integration_method        = "POST"
}

resource "aws_apigatewayv2_integration_response" "ws_messenger_api_integration_response" {
  api_id                   = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  integration_id           = aws_apigatewayv2_integration.ws_messenger_api_integration.id
  integration_response_key = "/200/"
}

resource "aws_apigatewayv2_route" "ws_messenger_api_default_route" {
  api_id    = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.ws_messenger_api_integration.id}"
}

resource "aws_apigatewayv2_route_response" "ws_messenger_api_default_route_response" {
  api_id             = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_id           = aws_apigatewayv2_route.ws_messenger_api_default_route.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_route" "ws_messenger_api_connect_route" {
  api_id    = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.ws_messenger_api_integration.id}"
  depends_on = [aws_apigatewayv2_route.ws_messenger_api_default_route]
}

resource "aws_apigatewayv2_route_response" "ws_messenger_api_connect_route_response" {
  api_id             = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_id           = aws_apigatewayv2_route.ws_messenger_api_connect_route.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_route" "ws_messenger_api_disconnect_route" {
  api_id    = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.ws_messenger_api_integration.id}"
  depends_on = [aws_apigatewayv2_route.ws_messenger_api_connect_route]
}

resource "aws_apigatewayv2_route_response" "ws_messenger_api_disconnect_route_response" {
  api_id             = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_id           = aws_apigatewayv2_route.ws_messenger_api_disconnect_route.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_route" "ws_messenger_api_message_route" {
  api_id    = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_key = "MESSAGE"
  target    = "integrations/${aws_apigatewayv2_integration.ws_messenger_api_integration.id}"
  depends_on = [aws_apigatewayv2_route.ws_messenger_api_disconnect_route]
}

resource "aws_apigatewayv2_route_response" "ws_messenger_api_message_route_response" {
  api_id             = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  route_id           = aws_apigatewayv2_route.ws_messenger_api_message_route.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_stage" "ws_messenger_api_stage" {
  api_id      = aws_apigatewayv2_api.ws_messenger_api_gateway.id
  name        = "develop"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

resource "aws_api_gateway_usage_plan" "websocket_usage_plan" {
  name        = "websocket-usage-plan"
  description = "Usage plan for WebSocket API"
  
  api_stages {
    api_id = aws_apigatewayv2_api.ws_messenger_api_gateway.id
    stage  = aws_apigatewayv2_stage.ws_messenger_api_stage.name
  }
  
  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
}

resource "aws_lambda_permission" "ws_messenger_lambda_permissions" {
  statement_id  = "AllowExecutionFromAPIGatewayWebsocket"  # Changed to make it unique
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ws_messenger_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws_messenger_api_gateway.execution_arn}/*/*"
  depends_on    = [
    aws_apigatewayv2_stage.ws_messenger_api_stage,
    aws_apigatewayv2_route.ws_messenger_api_default_route,
    aws_apigatewayv2_route.ws_messenger_api_connect_route,
    aws_apigatewayv2_route.ws_messenger_api_disconnect_route,
    aws_apigatewayv2_route.ws_messenger_api_message_route
  ]
}