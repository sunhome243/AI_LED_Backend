variable "GOOGLE_GEMINI_API_KEY" {
  type        = string
  description = "API key for Google Gemini AI service"
  sensitive   = true
}

variable "BUCKET_NAME" {
  type        = string
  description = "S3 bucket name for storing application data"
}

variable "REGION_NAME" {
  type        = string
  description = "AWS region where resources are deployed"
}