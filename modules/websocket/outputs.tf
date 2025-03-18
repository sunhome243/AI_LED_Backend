output "websocket_api_endpoint" {
  value = aws_apigatewayv2_api.ws_messenger_api_gateway.api_endpoint
  description = "The WebSocket API Gateway endpoint"
}

output "websocket_stage_name" {
  # Update to use the correct resource name for the API Gateway stage
  value = "production"  # Using a hardcoded value as fallback
  description = "The WebSocket API Gateway stage name"
}

output "websocket_execution_arn" {
  value = aws_apigatewayv2_api.ws_messenger_api_gateway.execution_arn
  description = "Execution ARN for WebSocket API Gateway"
}

output "aws_lambda_function" {
  description = "The websocket Lambda function resource"
  value = {
    ws_messenger_lambda = aws_lambda_function.ws_messenger_lambda
  }
}

