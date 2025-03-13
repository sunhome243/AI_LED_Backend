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
  
  # Calculate hash of source files to detect changes
  audio_to_ai_hash = sha256(join("", [
    for file in local.audio_to_ai_files : filebase64(file)
  ]))
  
  pattern_to_ai_hash = sha256(join("", [
    for file in local.pattern_to_ai_files : filebase64(file)
  ]))
  
  result_save_send_hash = sha256(join("", [
    for file in local.result_save_send_files : filebase64(file)
  ]))
  
  ws_messenger_hash = sha256(join("", [
    for file in local.ws_messenger_files : filebase64(file)
  ]))
}

# Create deployment packages for Lambda functions
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/audio_to_ai"
  output_path = "${path.module}/archive/audio_to_ai.zip"
  
  # This forces the archive to be regenerated when files change
  output_file_mode = "0644"
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_dir = "${local.base_dir}/lambda/pattern_to_ai"
  output_path = "${path.module}/archive/pattern_to_ai.zip"
  
  output_file_mode = "0644"
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_dir = "${local.base_dir}/lambda/result_save_send"
  output_path = "${path.module}/archive/result_save_send.zip"
  
  output_file_mode = "0644"
}

data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_dir = "${local.base_dir}/lambda/websocket"
  output_path = "${path.module}/archive/ws_messenger.zip"
  
  output_file_mode = "0644"
}