output "lambda_role_arn" {
  value       = aws_iam_role.iam_for_lambda.arn
  description = "ARN of the IAM role for Lambda functions"
}

output "api_gateway_role_arn" {
  value       = aws_iam_role.api_gateway_role.arn
  description = "ARN of the IAM role for API Gateway"
}
