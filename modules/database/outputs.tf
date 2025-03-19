# DynamoDB Table ARN Outputs
output "auth_table_arn" {
  value       = aws_dynamodb_table.user-auth-table.arn
  description = "ARN of the Authentication DynamoDB table (AuthTable)"
}

output "ircode_table_arn" {
  value       = aws_dynamodb_table.ircode-transition-table.arn
  description = "ARN of the IR Code DynamoDB table (IrCodeTable)"
}

output "response_table_arn" {
  value       = aws_dynamodb_table.response-table.arn
  description = "ARN of the User Response DynamoDB table (ResponseTable)"
}

output "connection_table_arn" {
  value       = aws_dynamodb_table.connection_table.arn
  description = "ARN of the WebSocket Connection DynamoDB table (ConnectionIdTable)"
}

output "connection_table_name" {
  value       = aws_dynamodb_table.connection_table.name
  description = "Name of the WebSocket Connection DynamoDB table (ConnectionIdTable)"
}

# S3 Bucket Output
output "response_bucket_name" {
  value       = aws_s3_bucket.response-data.bucket
  description = "Name of the S3 bucket for storing user response data (prisim-led-proto-response-data)"
}
