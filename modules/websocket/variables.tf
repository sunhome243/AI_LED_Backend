variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda functions"
  type        = string
}

variable "connection_table_name" {
  description = "Name of the DynamoDB table for WebSocket connections"
  type        = string
}

variable "api_gateway_role_arn" {
  description = "ARN of the IAM role for API Gateway"
  type        = string
}

variable "lambda_layer_arn" {
  description = "ARN of the Lambda layer containing Python dependencies"
  type        = string
}