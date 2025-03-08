variable "lambda_role_arn" {
  type        = string
  description = "ARN of the IAM role for Lambda functions"
}

variable "connection_table_name" {
  type        = string
  description = "Name of the WebSocket Connection DynamoDB table"
}