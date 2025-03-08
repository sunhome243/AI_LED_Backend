# S3 for response data
resource "aws_s3_bucket" "response-data" {
  bucket = "prisim-led-proto-response-data"
  tags = {
    Name = "prisim-led-proto-response-data"
    Environment = "Dev"
  }
}