locals {
  # Define the path to the parent directory that contains both lambda and terraform directories
  base_dir = abspath("${path.root}/..")
}

# Create deployment packages for Lambda functions
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/audio_to_ai/audio_to_ai.py"
  output_path = "${path.module}/archive/audio_to_ai.zip"
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/pattern_to_ai/pattern_to_ai.py"
  output_path = "${path.module}/archive/pattern_to_ai.zip"
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/result_save_send/result_save_send.py"
  output_path = "${path.module}/archive/result_save_send.zip"
}

data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_file = "${local.base_dir}/lambda/websocket/connection_manager.py"
  output_path = "${path.module}/archive/ws_messenger.zip"
}