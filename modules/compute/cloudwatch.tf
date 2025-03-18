# Dynamic data sources for existing CloudWatch log groups
locals {
  # Define function names for log groups in a map
  log_group_functions = {
    "audio_to_ai"     = local.function_names.audio_to_ai
    "pattern_to_ai"   = local.function_names.pattern_to_ai
    "result_save_send" = local.function_names.result_save_send
    "isConnect"       = local.function_names.isConnect
    "ws_messenger"    = local.function_names.ws_messenger  
  }
}

# No data sources for CloudWatch log groups since we're not managing them

# Only create log groups if explicitly set to manage them
# This block will be effectively disabled with manage_log_groups = false
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = local.manage_log_groups ? local.log_group_functions : {}
  name              = "/aws/lambda/${each.value}"
  retention_in_days = 30
  
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
    ignore_changes        = [tags]
  }
}
