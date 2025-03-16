output "audio_to_ai_lambda_arn" {
  value       = aws_lambda_function.audio_to_ai.arn
  description = "ARN of the audio_to_ai Lambda function"
}

output "pattern_to_ai_lambda_arn" {
  value       = aws_lambda_function.pattern_to_ai.arn
  description = "ARN of the pattern_to_ai Lambda function"
}

output "isConnect_lambda_arn" {
  value       = aws_lambda_function.isConnect.arn
  description = "ARN of the isConnect Lambda function"
}
