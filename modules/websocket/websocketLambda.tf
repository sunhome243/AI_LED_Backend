# Add the missing null_resource for creating the archive directory
resource "null_resource" "ensure_ws_archive_dir" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/archive"
  }
}

locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
  
  # Calculate hash of WebSocket Lambda source files
  ws_messenger_files = [
    for file in fileset("${local.base_dir}/lambda/websocket", "**") : 
    "${local.base_dir}/lambda/websocket/${file}"
  ]
  
  # More reliable source hash calculation
  ws_messenger_source_hash = sha256(join("", [for f in local.ws_messenger_files : filesha256(f)]))
  
  # CloudWatch 로그 관리 여부 설정
  manage_ws_log_group = false
}

resource "aws_lambda_function" "ws_messenger_lambda" {
  filename         = data.archive_file.ws_messenger_zip.output_path
  function_name    = "ws-messenger"
  role             = var.lambda_role_arn
  handler          = "connection_manager.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.ws_messenger_zip.output_base64sha256
  memory_size      = 128
  timeout          = 10
  layers           = [var.lambda_layer_arn]
  
  # Enhanced lifecycle configuration to handle existing functions better
  lifecycle {
    create_before_destroy = true
    # Prevent issues with pre-existing functions
    ignore_changes = [
      tags,
      # For existing functions, ignore source_code_hash to avoid conflicts
      source_code_hash,
      # Also ignore these to maintain existing settings
      memory_size,
      timeout,
      layers
    ]
  }
  
  environment {
    variables = {
      CONNECTION_TABLE = var.connection_table_name
    }
  }
}

# Archive resource for Lambda code with unique filename based on hash
data "archive_file" "ws_messenger_zip" {
  type        = "zip"
  source_dir  = "${local.base_dir}/lambda/websocket"  # Changed to source_dir for better handling
  output_path = "${path.module}/archive/ws_messenger_${local.ws_messenger_source_hash}.zip"
  output_file_mode = "0644"
  depends_on  = [null_resource.ensure_ws_archive_dir]
  
  # Explicitly exclude isConnect.py to avoid conflict with compute module
  excludes = ["isConnect.py"]
}

# CloudWatch 로그 그룹을 데이터 소스로 먼저 조회
data "aws_cloudwatch_log_group" "ws_messenger_logs" {
  count = local.manage_ws_log_group ? 0 : 1
  name  = "/aws/lambda/ws-messenger"
}

# 기존 로그 그룹이 없을 경우에만 생성
resource "aws_cloudwatch_log_group" "ws_messenger_logs" {
  count             = local.manage_ws_log_group ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.ws_messenger_lambda.function_name}"
  retention_in_days = 30
  
  # Add lifecycle block to handle existing log groups
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false  # Change from true to false to allow destruction
    ignore_changes        = [tags]
  }
}
