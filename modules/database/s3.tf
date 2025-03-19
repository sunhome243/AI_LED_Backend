# S3 bucket for storing response data from the PRISIM LED prototype
# This bucket contains user interaction responses and analytics data
resource "aws_s3_bucket" "response-data" {
  bucket = "prisim-led-proto-response-data"
  tags = {
    Name        = "prisim-led-proto-response-data"
    Environment = "Dev"
  }
}