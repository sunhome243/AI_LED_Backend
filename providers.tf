# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Add the null provider for local resources
provider "null" {}

# Archive provider for creating zip files
provider "archive" {}

