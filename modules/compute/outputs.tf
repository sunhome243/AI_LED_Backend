locals {
  # Helper to simplify function references - updated to use the correct resource
  function_outputs = {
    audio_to_ai     = aws_lambda_function.functions["audio_to_ai"]
    pattern_to_ai   = aws_lambda_function.functions["pattern_to_ai"]
    result_save_send = aws_lambda_function.functions["result_save_send"]
    isConnect       = aws_lambda_function.functions["isConnect"]
  }
}

# Lambda ARN outputs
output "lambda_arns" {
  value = {
    for key, function in aws_lambda_function.functions : key => function.arn
  }
  description = "Map of Lambda function ARNs"
}

# Individual ARN outputs for backward compatibility
output "audio_to_ai_lambda_arn" {
  value       = aws_lambda_function.functions["audio_to_ai"].arn
  description = "ARN of the audio-to-ai Lambda function"
}

output "pattern_to_ai_lambda_arn" {
  value       = aws_lambda_function.functions["pattern_to_ai"].arn
  description = "ARN of the pattern-to-ai Lambda function"
}

output "result_save_send_lambda_arn" {
  value       = aws_lambda_function.functions["result_save_send"].arn
  description = "ARN of the result-save-send Lambda function"
}

output "isConnect_lambda_arn" {
  value       = aws_lambda_function.functions["isConnect"].arn
  description = "ARN of the isConnect Lambda function"
}

# Lambda function name outputs
output "lambda_names" {
  value = {
    for key, function in aws_lambda_function.functions : key => function.function_name
  }
  description = "Map of Lambda function names"
}

# Individual function name outputs for backward compatibility
output "audio_to_ai_function_name" {
  value       = aws_lambda_function.functions["audio_to_ai"].function_name
  description = "Name of the audio-to-ai Lambda function"
}

output "pattern_to_ai_function_name" {
  value       = aws_lambda_function.functions["pattern_to_ai"].function_name
  description = "Name of the pattern-to-ai Lambda function"
}

output "result_save_send_function_name" {
  value       = aws_lambda_function.functions["result_save_send"].function_name
  description = "Name of the result-save-send Lambda function"
}

output "isConnect_function_name" {
  value       = aws_lambda_function.functions["isConnect"].function_name
  description = "Name of the isConnect Lambda function"
}

# Output for access to all Lambda functions
output "aws_lambda_function" {
  description = "All lambda functions created by this module"
  value       = aws_lambda_function.functions
}
