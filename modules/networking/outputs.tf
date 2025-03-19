output "rest_api_id" {
  value       = aws_api_gateway_rest_api.rest_api.id
  description = "ID of the REST API Gateway"
}

output "pattern_to_ai_resource_id" {
  value       = aws_api_gateway_resource.pattern_to_ai_gateway_resource.id
  description = "Resource ID for pattern_to_ai endpoint"
}

output "audio_to_ai_resource_id" {
  value       = aws_api_gateway_resource.audio_to_ai_gateway_resource.id
  description = "Resource ID for audio_to_ai endpoint"
}

output "is_connect_resource_id" {
  value       = aws_api_gateway_resource.is_connect.id
  description = "Resource ID for is_connect endpoint"
}

output "rest_api_execution_arn" {
  value       = aws_api_gateway_rest_api.rest_api.execution_arn
  description = "Execution ARN of the REST API Gateway"
}

# Add output for HTTP methods to use in integrations
output "pattern_to_ai_method" {
  value       = aws_api_gateway_method.pattern_to_ai_http_method.http_method
  description = "HTTP method for pattern_to_ai endpoint"
}

output "audio_to_ai_method" {
  value       = aws_api_gateway_method.audio_to_ai_http_method.http_method
  description = "HTTP method for audio_to_ai endpoint"
}

output "is_connect_method" {
  value       = aws_api_gateway_method.is_connect_http_method.http_method
  description = "HTTP method for is_connect endpoint"
}

# Add outputs for deployment and stage
output "api_gateway_deployment_id" {
  value       = aws_api_gateway_deployment.deploy.id
  description = "ID of the API Gateway deployment"
}

output "api_gateway_stage_name" {
  value       = aws_api_gateway_stage.stage.stage_name
  description = "Name of the API Gateway stage"
}

output "api_gateway_invoke_url" {
  value       = aws_api_gateway_stage.stage.invoke_url
  description = "Base URL for invoking the API Gateway"
}

# Add outputs for resource paths
output "pattern_to_ai_path" {
  value       = "${aws_api_gateway_resource.pattern_to_ai.path_part}/${aws_api_gateway_resource.pattern_to_ai_gateway_resource.path_part}"
  description = "Full path for pattern_to_ai endpoint"
}

output "audio_to_ai_path" {
  value       = "${aws_api_gateway_resource.audio_to_ai.path_part}/${aws_api_gateway_resource.audio_to_ai_gateway_resource.path_part}"
  description = "Full path for audio_to_ai endpoint"
}

output "is_connect_path" {
  value       = aws_api_gateway_resource.is_connect.path_part
  description = "Path for is_connect endpoint"
}