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
  
  # Calculate hash of source files to detect changes more reliably
  # Use sha256 of concatenated files instead of filemd5 of the archive
  audio_to_ai_source_hash = sha256(join("", [for f in local.audio_to_ai_files : filesha256(f)]))
  pattern_to_ai_source_hash = sha256(join("", [for f in local.pattern_to_ai_files : filesha256(f)]))
  result_save_send_source_hash = sha256(join("", [for f in local.result_save_send_files : filesha256(f)]))
  ws_messenger_source_hash = sha256(join("", [for f in local.ws_messenger_files : filesha256(f)]))
  
  # Use archive output hash for Lambda functions
  audio_to_ai_hash = data.archive_file.audio_to_ai_lambda.output_base64sha256
  pattern_to_ai_hash = data.archive_file.pattern_to_ai_lambda.output_base64sha256
  result_save_send_hash = data.archive_file.result_save_send_lambda.output_base64sha256
  ws_messenger_hash = data.archive_file.ws_messenger_zip.output_base64sha256
}

# Ensure archive directory exists
resource "local_file" "ensure_archive_dir" {
  content     = ""
  filename    = "${path.module}/archive/.keep"
  file_permission = "0644"
}

# Create deployment packages for Lambda functions with explicit triggers based on source hash
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/audio_to_ai"
  output_path = "${path.module}/archive/audio_to_ai_${local.audio_to_ai_source_hash}.zip"
  depends_on  = [local_file.ensure_archive_dir]
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/pattern_to_ai"
  output_path = "${path.module}/archive/pattern_to_ai_${local.pattern_to_ai_source_hash}.zip"
  depends_on  = [local_file.ensure_archive_dir]
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/result_save_send"
  output_path = "${path.module}/archive/result_save_send_${local.result_save_send_source_hash}.zip"
  depends_on  = [local_file.ensure_archive_dir]
}

data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/websocket"
  output_path = "${path.module}/archive/ws_messenger_${local.ws_messenger_source_hash}.zip"
  depends_on  = [local_file.ensure_archive_dir]
}