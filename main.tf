terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47.0"
    }
  }
  
  # Backend configuration should be in the terraform block
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

# First create the database module
module "database" {
  source = "./modules/database"
}

# Then create IAM with database dependencies
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

# Create WebSocket module after database and IAM
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
  google_gemini_api_key = var.GOOGLE_GEMINI_API_KEY  # Add this line for the new variable name
  GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY  # Keep for backward compatibility
  aws_region            = var.REGION_NAME            # Add this line for the new variable name
  REGION_NAME           = var.REGION_NAME            # Keep for backward compatibility
  lambda_role_arn       = module.iam.lambda_role_arn
  response_bucket_name  = module.database.response_bucket_name
  websocket_endpoint    = module.websocket.websocket_api_endpoint
  websocket_stage_name  = module.websocket.websocket_stage_name
  connection_table_name = module.database.connection_table_name
  lambda_layer_arn      = aws_lambda_layer_version.lambda_dependencies.arn
}

module "networking" {
  source     = "./modules/networking"
  depends_on = [module.compute]  # Simplified dependency

  pattern_to_ai_lambda_arn = module.compute.pattern_to_ai_lambda_arn
  audio_to_ai_lambda_arn   = module.compute.audio_to_ai_lambda_arn
  isConnect_lambda_arn     = module.compute.isConnect_lambda_arn
  
  # Add function names
  pattern_to_ai_function_name = module.compute.pattern_to_ai_function_name
  audio_to_ai_function_name   = module.compute.audio_to_ai_function_name
  isConnect_function_name     = module.compute.isConnect_function_name
  
  gateway_role_arn         = module.iam.api_gateway_role_arn
}

# Import statements in the root module for Lambda functions
# These import statements replace the ones previously in the modules
# 수정된 형식으로 임포트 구문 작성 - 모듈의 리소스를 올바르게 참조하기 위해

# 각 Lambda 함수의 임포트 블록
# 주의: 임포트는 초기 1회만 필요하므로 주석 처리하고 필요할 때만 활성화
/*
# Import websocket messenger lambda
import {
  id = "ws-messenger"
  to = module.websocket.aws_lambda_function.ws_messenger_lambda
}

# Import compute module lambdas
import {
  id = "audio-to-ai"
  to = module.compute.aws_lambda_function.functions["audio_to_ai"]
}

import {
  id = "pattern-to-ai"
  to = module.compute.aws_lambda_function.functions["pattern_to_ai"]
}

import {
  id = "result-save-send"
  to = module.compute.aws_lambda_function.functions["result_save_send"]
}

import {
  id = "is-connect"
  to = module.compute.aws_lambda_function.functions["isConnect"]
}
*/