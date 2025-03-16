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

module "websocket" {
  source                = "./modules/websocket"
  depends_on            = [module.iam, module.database]
  lambda_role_arn       = module.iam.lambda_role_arn
  connection_table_name = module.database.connection_table_name
  api_gateway_role_arn  = module.iam.api_gateway_role_arn
}

module "compute" {
  source     = "./modules/compute"
  depends_on = [module.iam, module.database, module.websocket]

  # Pass required resources to compute module
  GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
  REGION_NAME           = var.REGION_NAME
  lambda_role_arn       = module.iam.lambda_role_arn
  response_bucket_name  = module.database.response_bucket_name
  websocket_endpoint    = module.websocket.websocket_api_endpoint
  websocket_stage_name  = module.websocket.websocket_stage_name
  connection_table_name = module.database.connection_table_name
}

module "networking" {
  source     = "./modules/networking"
  depends_on = [module.iam, module.database, module.compute]

  pattern_to_ai_lambda_arn = module.compute.pattern_to_ai_lambda_arn
  audio_to_ai_lambda_arn   = module.compute.audio_to_ai_lambda_arn
  isConnect_lambda_arn     = module.compute.isConnect_lambda_arn
  
  # Add these new variables
  pattern_to_ai_function_name = module.compute.pattern_to_ai_function_name
  audio_to_ai_function_name   = module.compute.audio_to_ai_function_name
  isConnect_function_name     = module.compute.isConnect_function_name
  
  gateway_role_arn         = module.iam.api_gateway_role_arn
}