output "websocket_api_endpoint" {
  value = aws_apigatewayv2_api.ws_messenger_api_gateway.api_endpoint
  description = "API endpoint for WebSocket API Gateway"
}

output "websocket_stage_name" {
  value = aws_apigatewayv2_stage.ws_messenger_api_stage.name
  description = "Stage name for WebSocket API Gateway"
}

output "websocket_execution_arn" {
  value = aws_apigatewayv2_api.ws_messenger_api_gateway.execution_arn
  description = "Execution ARN for WebSocket API Gateway"
}

