variable "GOOGLE_GEMINI_API_KEY" {
  type        = string
  description = "API key for Google Gemini AI service"
  sensitive   = true
}

variable "REGION_NAME" {
  type        = string
  description = "AWS region where resources are deployed"
}