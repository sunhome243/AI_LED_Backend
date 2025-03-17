variable "GOOGLE_GEMINI_API_KEY" {
  type        = string
  description = "API key for Google Gemini AI service"
  sensitive   = true
}

variable "REGION_NAME" {
  type        = string
  description = "AWS region where resources are deployed"
}

variable "lambda_role_arn" {
  type        = string
  description = "ARN of the IAM role for Lambda functions"
}

variable "response_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for response data"
}

variable "websocket_endpoint" {
  type        = string
  description = "API endpoint for WebSocket API Gateway"
}

variable "websocket_stage_name" {
  type        = string
  description = "Stage name for WebSocket API Gateway"
}

variable "connection_table_name" {
  type        = string
  description = "Name of the WebSocket Connection DynamoDB table"
}

variable "rest_api_execution_arn" {
  type        = string
  description = "Execution ARN of the REST API Gateway"
  default     = ""
}

variable "lambda_layer_arn" {
  type        = string
  description = "ARN of the Lambda layer containing Python dependencies"
}