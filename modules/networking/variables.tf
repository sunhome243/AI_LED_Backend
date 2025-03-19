variable "aws_region" {
  default = "us-east-1"
  description = "AWS region where resources are deployed"
}

variable "rest_api_name" {
  description = "Name of the REST API Gateway"
  type        = string
  default     = "prism-api"
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "dev"
}

variable "gateway_role_arn" {
  type        = string
  description = "IAM role ARN for API Gateway CloudWatch logging"
}

variable "pattern_to_ai_lambda_arn" {
  type        = string
  description = "ARN of the pattern_to_ai Lambda function"
}

variable "audio_to_ai_lambda_arn" {
  type        = string
  description = "ARN of the audio_to_ai Lambda function"
}

variable "isConnect_lambda_arn" {
  type        = string
  description = "ARN of the isConnect Lambda function"
}

# AWS region data source
data "aws_region" "current" {}

variable "pattern_to_ai_function_name" {
  type        = string
  description = "Name of the pattern_to_ai Lambda function"
}

variable "audio_to_ai_function_name" {
  type        = string
  description = "Name of the audio_to_ai Lambda function"
}

variable "isConnect_function_name" {
  type        = string
  description = "Name of the isConnect Lambda function"
}