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

# Add these variables for function names
variable "pattern_to_ai_function_name" {
  type        = string
  description = "Function name of pattern_to_ai lambda"
  default     = ""
}

variable "audio_to_ai_function_name" {
  type        = string
  description = "Function name of audio_to_ai lambda"
  default     = ""
}

variable "isConnect_function_name" {
  type        = string
  description = "Function name of isConnect lambda"
  default     = ""
}