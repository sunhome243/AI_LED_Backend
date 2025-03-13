locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
  
  # Define file change detection for each Lambda function
  audio_to_ai_files = [
    for file in fileset("${local.base_dir}/lambda/audio_to_ai", "**") : 
    "${local.base_dir}/lambda/audio_to_ai/${file}"
  ]
  
  pattern_to_ai_files = [
    for file in fileset("${local.base_dir}/lambda/pattern_to_ai", "**") : 
    "${local.base_dir}/lambda/pattern_to_ai/${file}"
  ]
  
  result_save_send_files = [
    for file in fileset("${local.base_dir}/lambda/result_save_send", "**") : 
    "${local.base_dir}/lambda/result_save_send/${file}"
  ]
  
  ws_messenger_files = [
    for file in fileset("${local.base_dir}/lambda/websocket", "**") : 
    "${local.base_dir}/lambda/websocket/${file}"
  ]
  
  # Calculate hash of source files to detect changes - using filemd5 for more reliable hashes
  audio_to_ai_hash = filemd5(data.archive_file.audio_to_ai_lambda.output_path)
  pattern_to_ai_hash = filemd5(data.archive_file.pattern_to_ai_lambda.output_path)
  result_save_send_hash = filemd5(data.archive_file.result_save_send_lambda.output_path)
  ws_messenger_hash = filemd5(data.archive_file.ws_messenger_zip.output_path)
}

# Ensure archive directory exists
resource "local_file" "ensure_archive_dir" {
  content     = ""
  filename    = "${path.module}/archive/.keep"
  file_permission = "0644"
}

# Create deployment packages for Lambda functions
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/audio_to_ai"
  output_path = "${path.module}/archive/audio_to_ai.zip"
  depends_on  = [local_file.ensure_archive_dir]
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/pattern_to_ai"
  output_path = "${path.module}/archive/pattern_to_ai.zip"
  depends_on  = [local_file.ensure_archive_dir]
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/result_save_send"
  output_path = "${path.module}/archive/result_save_send.zip"
  depends_on  = [local_file.ensure_archive_dir]
}

data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/websocket"
  output_path = "${path.module}/archive/ws_messenger.zip"
  depends_on  = [local_file.ensure_archive_dir]
}