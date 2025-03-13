locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
}

# Create deployment packages for Lambda functions
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/audio_to_ai"
  output_path = "${path.module}/archive/audio_to_ai.zip"
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_dir = "${local.base_dir}/lambda/pattern_to_ai"
  output_path = "${path.module}/archive/pattern_to_ai.zip"
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_dir = "${local.base_dir}/lambda/result_save_send"
  output_path = "${path.module}/archive/result_save_send.zip"
}

data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_dir = "${local.base_dir}/lambda/websocket"
  output_path = "${path.module}/archive/ws_messenger.zip"
}