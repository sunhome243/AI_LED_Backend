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
  
  # Add isConnect files to file detection
  isConnect_files = [
    for file in fileset("${local.base_dir}/lambda/websocket", "**") : 
    "${local.base_dir}/lambda/websocket/${file}" if file == "isConnect.py"
  ]
  
  # Calculate hash of source files to detect changes more reliably
  # Use sha256 of concatenated files instead of filemd5 of the archive
  audio_to_ai_source_hash = sha256(join("", [for f in local.audio_to_ai_files : filesha256(f)]))
  pattern_to_ai_source_hash = sha256(join("", [for f in local.pattern_to_ai_files : filesha256(f)]))
  result_save_send_source_hash = sha256(join("", [for f in local.result_save_send_files : filesha256(f)]))
  ws_messenger_source_hash = sha256(join("", [for f in local.ws_messenger_files : filesha256(f)]))
  
  # Calculate hash for isConnect
  isConnect_source_hash = sha256(join("", [for f in local.isConnect_files : filesha256(f)]))
}

# Create archive directory with proper permissions
resource "null_resource" "ensure_archive_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/archive && chmod 755 ${path.module}/archive"
  }
}

# package only the necessary files for each Lambda function
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/audio_to_ai"
  output_path = "${path.module}/archive/audio_to_ai_${local.audio_to_ai_source_hash}.zip"
  depends_on  = [null_resource.ensure_archive_dir, aws_lambda_layer_version.dependencies_layer]
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/pattern_to_ai"
  output_path = "${path.module}/archive/pattern_to_ai_${local.pattern_to_ai_source_hash}.zip"
  depends_on  = [null_resource.ensure_archive_dir, aws_lambda_layer_version.dependencies_layer]
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/result_save_send"
  output_path = "${path.module}/archive/result_save_send_${local.result_save_send_source_hash}.zip"
  depends_on  = [null_resource.ensure_archive_dir]
}

data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/websocket"
  output_path = "${path.module}/archive/ws_messenger_${local.ws_messenger_source_hash}.zip"
  depends_on  = [null_resource.ensure_archive_dir]
}

data "archive_file" "isConnect_lambda" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/websocket/isConnect.py"
  output_path = "${path.module}/archive/isConnect_${local.isConnect_source_hash}.zip"
  depends_on  = [null_resource.ensure_archive_dir]
}