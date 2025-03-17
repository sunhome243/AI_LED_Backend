terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47.0"
    }
  }
}

# Configure the Terraform State backend
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-backend-20252"
  tags = {
    Name        = "terraform-state-backend-20252"
    Environment = "Dev"
  }
}

terraform {
  backend "s3" {
    bucket  = "terraform-state-backend-20252"
    key     = "state/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# Lambda layer to hold Python dependencies - moved from lambda_layer.tf to break cycle
resource "null_resource" "install_dependencies" {
  triggers = {
    requirements_audio = filesha256("${path.module}/lambda/audio_to_ai/requirements.txt")
    requirements_pattern = filesha256("${path.module}/lambda/pattern_to_ai/requirements.txt")
    requirements_result = filesha256("${path.module}/lambda/result_save_send/requirements.txt")
    requirements_websocket = filesha256("${path.module}/lambda/websocket/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${path.module}/layer
      mkdir -p ${path.module}/layer/python
      pip install -r ${path.module}/lambda/audio_to_ai/requirements.txt --platform manylinux2014_x86_64 --target ${path.module}/layer/python --only-binary=:all: --implementation cp --python-version 3.9 --no-deps
      pip install -r ${path.module}/lambda/pattern_to_ai/requirements.txt --platform manylinux2014_x86_64 --target ${path.module}/layer/python --only-binary=:all: --implementation cp --python-version 3.9 --no-deps
      pip install -r ${path.module}/lambda/result_save_send/requirements.txt --platform manylinux2014_x86_64 --target ${path.module}/layer/python --only-binary=:all: --implementation cp --python-version 3.9 --no-deps
      pip install -r ${path.module}/lambda/websocket/requirements.txt --platform manylinux2014_x86_64 --target ${path.module}/layer/python --only-binary=:all: --implementation cp --python-version 3.9 --no-deps
      
      # Install core dependencies separately to ensure all requirements are met
      pip install pydantic pydantic-core --platform manylinux2014_x86_64 --target ${path.module}/layer/python --only-binary=:all: --implementation cp --python-version 3.9
    EOT
  }
}

resource "local_file" "ensure_layer_dir" {
  content     = ""
  filename    = "${path.module}/layer/.keep"
  file_permission = "0644"
  depends_on  = [null_resource.install_dependencies]
}

data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/lambda_layer.zip"
  depends_on  = [local_file.ensure_layer_dir]
}

resource "aws_lambda_layer_version" "lambda_dependencies" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "ai_led_dependencies"
  compatible_runtimes = ["python3.9"]
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256
}

# Get the current AWS account ID for ARN construction
data "aws_caller_identity" "current" {}

# Create API Gateway with Lambda integrations - improve creation order
module "networking" {
  source     = "./modules/networking"
  depends_on = [module.compute] # Simplify dependencies to just compute module
  
  # Pass IAM role ARN for API Gateway CloudWatch logging
  gateway_role_arn = module.iam.api_gateway_role_arn
  
  # API Gateway configuration
  rest_api_name    = "prism-api"
  stage_name       = "dev"
  
  # Pass Lambda ARNs from compute module for integrations
  pattern_to_ai_lambda_arn = module.compute.pattern_to_ai_lambda_arn
  audio_to_ai_lambda_arn   = module.compute.audio_to_ai_lambda_arn
  isConnect_lambda_arn     = module.compute.isConnect_lambda_arn
}

module "database" {
  source = "./modules/database"
}

module "iam" {
  source     = "./modules/iam"
  depends_on = [module.database]

  # Pass the database resources to IAM module
  connection_table_arn = module.database.connection_table_arn
  auth_table_arn       = module.database.auth_table_arn
  ircode_table_arn     = module.database.ircode_table_arn
  response_bucket_name = module.database.response_bucket_name
  response_table_arn   = module.database.response_table_arn
}

# Create WebSocket module after Lambda layer is created
module "websocket" {
  source                = "./modules/websocket"
  depends_on            = [module.iam, module.database, aws_lambda_layer_version.lambda_dependencies]
  lambda_role_arn       = module.iam.lambda_role_arn
  connection_table_name = module.database.connection_table_name
  api_gateway_role_arn  = module.iam.api_gateway_role_arn
  lambda_layer_arn      = aws_lambda_layer_version.lambda_dependencies.arn
}

# Now create compute module after WebSocket is created
module "compute" {
  source     = "./modules/compute"
  depends_on = [module.iam, module.database, module.websocket, aws_lambda_layer_version.lambda_dependencies]

  # Pass required resources to compute module
  GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
  REGION_NAME           = var.REGION_NAME
  lambda_role_arn       = module.iam.lambda_role_arn
  response_bucket_name  = module.database.response_bucket_name
  websocket_endpoint    = module.websocket.websocket_api_endpoint
  websocket_stage_name  = module.websocket.websocket_stage_name
  connection_table_name = module.database.connection_table_name
  lambda_layer_arn      = aws_lambda_layer_version.lambda_dependencies.arn
}

# Lambda permissions for API Gateway - these connect the compute and networking modules
resource "aws_lambda_permission" "pattern_to_ai_api_permission" {
  depends_on = [module.compute, module.networking]
  
  statement_id  = "AllowAPIGatewayToInvokePatternToAi"
  action        = "lambda:InvokeFunction"
  function_name = module.compute.pattern_to_ai_function_name
  principal     = "apigateway.amazonaws.com"
  # Use the path outputs from networking module to construct source ARNs
  source_arn    = "arn:aws:execute-api:${var.REGION_NAME}:${data.aws_caller_identity.current.account_id}:${module.networking.rest_api_id}/*/*/${module.networking.pattern_to_ai_path}"
}

resource "aws_lambda_permission" "audio_to_ai_api_permission" {
  depends_on = [module.compute, module.networking]
  
  statement_id  = "AllowAPIGatewayToInvokeAudioToAi"
  action        = "lambda:InvokeFunction"
  function_name = module.compute.audio_to_ai_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.REGION_NAME}:${data.aws_caller_identity.current.account_id}:${module.networking.rest_api_id}/*/*/${module.networking.audio_to_ai_path}"
}

resource "aws_lambda_permission" "isConnect_api_permission" {
  depends_on = [module.compute, module.networking]
  
  statement_id  = "AllowAPIGatewayToInvokeIsConnect"
  action        = "lambda:InvokeFunction"
  function_name = module.compute.isConnect_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.REGION_NAME}:${data.aws_caller_identity.current.account_id}:${module.networking.rest_api_id}/*/*/${module.networking.is_connect_path}"
}