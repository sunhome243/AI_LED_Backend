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
  
  # Add isConnect files to file detection
  isConnect_files = [
    "${local.base_dir}/lambda/websocket/isConnect.py"
  ]
  
  # Calculate hash of source files to detect changes more reliably
  audio_to_ai_source_hash = sha256(join("", [for f in local.audio_to_ai_files : filesha256(f)]))
  pattern_to_ai_source_hash = sha256(join("", [for f in local.pattern_to_ai_files : filesha256(f)]))
  result_save_send_source_hash = sha256(join("", [for f in local.result_save_send_files : filesha256(f)]))
  isConnect_source_hash = sha256(join("", [for f in local.isConnect_files : filesha256(f)]))
}

# Ensure archive directory exists
resource "local_file" "ensure_archive_dir" {
  content     = ""
  filename    = "${path.module}/archive/.keep"
  file_permission = "0644"
  depends_on  = [null_resource.ensure_archive_dir]
}

# package only the necessary files for each Lambda function
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

data "archive_file" "isConnect_lambda" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/websocket/isConnect.py"
  output_path = "${path.module}/archive/isConnect_${local.isConnect_source_hash}.zip"
  depends_on  = [local_file.ensure_archive_dir]
}