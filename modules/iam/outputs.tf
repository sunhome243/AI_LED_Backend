output "lambda_role_arn" {
  value       = aws_iam_role.iam_for_lambda.arn
  description = "ARN of the IAM role used for all Lambda functions with required permissions"
}

output "api_gateway_role_arn" {
  value       = aws_iam_role.api_gateway_role.arn
  description = "ARN of the IAM role used for API Gateway with CloudWatch logging permissions"
}
