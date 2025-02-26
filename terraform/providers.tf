# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
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