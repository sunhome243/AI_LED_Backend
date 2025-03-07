terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.47.0"
    }
  }
}

# Configure the Terraform State backend
terraform {
  backend "s3" {
    bucket = "terraform-state-backend-20252"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

module "compute" {
  source = "./modules/compute"
  
  # Pass root variables to the module
  GOOGLE_GEMINI_API_KEY = var.GOOGLE_GEMINI_API_KEY
  REGION_NAME           = var.REGION_NAME
  
  # Any other variables the module requires
}