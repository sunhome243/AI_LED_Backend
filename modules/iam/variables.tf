variable "auth_table_arn" {
  type        = string
  description = "ARN of the Auth DynamoDB table"
}

variable "ircode_table_arn" {
  type        = string
  description = "ARN of the IR Code DynamoDB table"
}

variable "response_table_arn" {
  type        = string
  description = "ARN of the Response DynamoDB table"
}

variable "connection_table_arn" {
  type        = string
  description = "ARN of the WebSocket Connection DynamoDB table"
}

variable "response_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for response data"
}
