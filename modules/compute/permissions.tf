resource "aws_lambda_permission" "isConnect_api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvokeIsConnect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.isConnect.function_name
  principal     = "apigateway.amazonaws.com"
  
  # The source ARN is the API Gateway's ARN with a wildcard for any method/resource
  source_arn    = "${var.rest_api_execution_arn}/*/*/*"
}
