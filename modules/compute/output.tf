output "audio_to_ai_lambda_arn" {
  value       = aws_lambda_function.audio_to_ai.invoke_arn
  description = "ARN of the IAM role for audio_to_ai Lambda"
}

output "pattern_to_ai_lambda_arn" {
  value       = aws_lambda_function.pattern_to_ai.invoke_arn
  description = "ARN of the IAM role for pattern_to_ai Lambda"
}

output "isConnect_lambda_arn" {
  value       = aws_lambda_function.isConnect.invoke_arn
  description = "ARN of the IAM role for isConnect Lambda"
}
