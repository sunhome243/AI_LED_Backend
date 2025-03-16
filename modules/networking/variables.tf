variable "aws_region" {
  default = "us-east-1"
}

variable "rest_api_name" {
  description = "The name of your API"
  type        = string
  default     = "prism-api"
}

variable "stage_name" {
  description = "The name of your API stage"
  type        = string
  default     = "dev"
}

variable "pattern_to_ai_lambda_arn" {
  type        = string
  description = "ARN of pattern_to_ai lambda function"
}

variable "audio_to_ai_lambda_arn" {
  type        = string
  description = "ARN of audio_to_ai lambda function"
}

variable "gateway_role_arn" {
  type        = string
  description = "gateway logging role arn"
}

variable "isConnect_lambda_arn" {
  type        = string
  description = "ARN of isConnect lambda function"
}