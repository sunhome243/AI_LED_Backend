
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
  description = "pattern to ai lambda_arn"
}

variable "audio_to_ai_lambda_arn" {
  type        = string
  description = "audio to ai lambda arn"
}

variable "gateway_role_arn" {
  type        = string
  description = "gateway logging role arn"
}