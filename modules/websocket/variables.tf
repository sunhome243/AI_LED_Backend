variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda WebSocket functions"
  type        = string
}

variable "connection_table_name" {
  description = "Name of the DynamoDB table for storing WebSocket connections"
  type        = string
}

variable "api_gateway_role_arn" {
  description = "ARN of the IAM role for WebSocket API Gateway"
  type        = string
}

variable "lambda_layer_arn" {
  description = "ARN of the Lambda layer containing shared Python dependencies"
  type        = string
}