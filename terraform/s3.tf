# S3 for backend
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-backend-20252"
  tags = {
    Name = "terraform-state-backend-20252"
    Environment = "Dev"
  }
}

# S3 for response data
resource "aws_s3_bucket" "terraform_state" {
  bucket = "prisim-led-proto-response-data"
  tags = {
    Name = "prisim-led-proto-response-data"
    Environment = "Dev"
  }
}