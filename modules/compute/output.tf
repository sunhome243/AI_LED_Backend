output "audio_to_ai_lambda_arn" {
  value       = aws_lambda_function.audio_to_ai.invoke_arn
  description = "Invoke ARN of the audio_to_ai Lambda function"
}

output "pattern_to_ai_lambda_arn" {
  value       = aws_lambda_function.pattern_to_ai.invoke_arn
  description = "Invoke ARN of the pattern_to_ai Lambda function"
}

output "isConnect_lambda_arn" {
  value       = aws_lambda_function.isConnect.invoke_arn
  description = "Invoke ARN of the isConnect Lambda function"
}

# Add these outputs for lambda permissions
output "audio_to_ai_function_name" {
  value       = aws_lambda_function.audio_to_ai.function_name
  description = "Function name of the audio_to_ai Lambda function"
}

output "pattern_to_ai_function_name" {
  value       = aws_lambda_function.pattern_to_ai.function_name
  description = "Function name of the pattern_to_ai Lambda function"
}

output "isConnect_function_name" {
  value       = aws_lambda_function.isConnect.function_name
  description = "Function name of the isConnect Lambda function"
}
