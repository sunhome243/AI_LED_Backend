# Simplified Lambda layer creation process

# Create the layer directory structure
resource "null_resource" "prepare_lambda_layer" {
  triggers = {
    requirements_hash = filesha256("${path.module}/layer_requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOF
      # Create directory structure and install dependencies
      mkdir -p ${path.module}/layer_build/python
      pip install -r ${path.module}/layer_requirements.txt -t ${path.module}/layer_build/python --no-cache-dir
      
      # Quick check for essential packages
      if [ ! -d "${path.module}/layer_build/python/shortuuid" ]; then
        echo "ERROR: shortuuid package missing from installation"
        exit 1
      fi
      
      # Clean unnecessary files to reduce layer size
      find ${path.module}/layer_build/python -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}

# Create the layer ZIP file
data "archive_file" "lambda_layer_zip" {
  depends_on  = [null_resource.prepare_lambda_layer]
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/lambda_layer.zip"
}

# Create the Lambda layer
resource "aws_lambda_layer_version" "dependencies_layer" {
  layer_name          = "shared-dependencies"
  filename            = data.archive_file.lambda_layer_zip.output_path
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
  description         = "Shared dependencies for Lambda functions"
  
  lifecycle {
    create_before_destroy = true
  }
}

# Optional: Clean up temp files after successful deployment
resource "null_resource" "cleanup_temp_files" {
  triggers = {
    layer_version = aws_lambda_layer_version.dependencies_layer.id
  }

  provisioner "local-exec" {
    command = "rm -f ${path.module}/lambda_layer.zip"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [aws_lambda_layer_version.dependencies_layer]
}
