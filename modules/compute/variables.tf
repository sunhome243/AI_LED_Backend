# API Key variables
variable "google_gemini_api_key" {
  type        = string
  description = "API key for Google Gemini AI services"
  sensitive   = true
}

# Region variables
variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed"
  default     = "us-east-1"
}

# Lambda role and layer variables
variable "lambda_role_arn" {
  type        = string
  description = "ARN of the IAM role for Lambda functions (from IAM module)"
}

variable "lambda_layer_arn" {
  type        = string
  description = "ARN of the Lambda layer containing common dependencies"
}

variable "lambda_layer_version" {
  type        = string
  description = "Version number of the Lambda layer to force redeployment"
  default     = "1"
}

# DynamoDB table variables
variable "connection_table_name" {
  type        = string
  description = "Name of the WebSocket Connection DynamoDB table"
}

# S3 bucket variables
variable "response_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for response data"
}

# WebSocket endpoint variables
variable "websocket_endpoint" {
  type        = string
  description = "API endpoint for WebSocket API Gateway"
}

variable "websocket_stage_name" {
  type        = string
  description = "Stage name for WebSocket API Gateway"
}

# REST API variables
variable "rest_api_execution_arn" {
  type        = string
  description = "Execution ARN of the REST API Gateway"
  default     = ""
}