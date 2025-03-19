terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47.0"
    }
  }
  
  # S3 backend configuration for storing Terraform state
  backend "s3" {
    bucket  = "terraform-state-backend-20252"
    key     = "state/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-backend-20252"
  tags = {
    Name        = "terraform-state-backend-20252"
    Environment = "Dev"
  }
}

# ==============================================
# Module Initialization
# ==============================================

# 1. Database Module - Creates DynamoDB tables and S3 bucket
module "database" {
  source = "./modules/database"
}

# 2. IAM Module - Creates roles and policies for all resources
module "iam" {
  source     = "./modules/iam"
  depends_on = [module.database]

  # Database resource dependencies
  connection_table_arn = module.database.connection_table_arn
  auth_table_arn       = module.database.auth_table_arn
  ircode_table_arn     = module.database.ircode_table_arn
  response_bucket_name = module.database.response_bucket_name
  response_table_arn   = module.database.response_table_arn
}

# 3. WebSocket Module - Creates WebSocket API Gateway and handler
module "websocket" {
  source                = "./modules/websocket"
  depends_on            = [module.iam, module.database, null_resource.build_lambda_layer]
  lambda_role_arn       = module.iam.lambda_role_arn
  connection_table_name = module.database.connection_table_name
  api_gateway_role_arn  = module.iam.api_gateway_role_arn
  lambda_layer_arn      = aws_lambda_layer_version.lambda_dependencies.arn
}

# 4. Compute Module - Creates Lambda functions for business logic
module "compute" {
  source     = "./modules/compute"
  depends_on = [module.iam, module.database, module.websocket, null_resource.build_lambda_layer]

  # Required configuration and resource dependencies
  google_gemini_api_key = var.GOOGLE_GEMINI_API_KEY
  aws_region            = var.REGION_NAME
  lambda_role_arn       = module.iam.lambda_role_arn
  response_bucket_name  = module.database.response_bucket_name
  websocket_endpoint    = module.websocket.websocket_api_endpoint
  websocket_stage_name  = module.websocket.websocket_stage_name
  connection_table_name = module.database.connection_table_name
  lambda_layer_arn      = aws_lambda_layer_version.lambda_dependencies.arn
  lambda_layer_version  = aws_lambda_layer_version.lambda_dependencies.version
}

# 5. Networking Module - Creates REST API Gateway and integrations
module "networking" {
  source     = "./modules/networking"
  depends_on = [module.compute]

  # Lambda function dependencies
  pattern_to_ai_lambda_arn = module.compute.pattern_to_ai_lambda_arn
  audio_to_ai_lambda_arn   = module.compute.audio_to_ai_lambda_arn
  isConnect_lambda_arn     = module.compute.isConnect_lambda_arn
  
  # Lambda function names for permissions
  pattern_to_ai_function_name = module.compute.pattern_to_ai_function_name
  audio_to_ai_function_name   = module.compute.audio_to_ai_function_name
  isConnect_function_name     = module.compute.isConnect_function_name
  
  # IAM role for API Gateway
  gateway_role_arn         = module.iam.api_gateway_role_arn
}