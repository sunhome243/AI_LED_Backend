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