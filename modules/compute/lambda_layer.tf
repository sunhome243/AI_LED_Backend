# Simplified Lambda layer creation without Docker

# Generate a requirements file from our specified dependencies
resource "local_file" "python_requirements" {
  content  = file("${path.module}/layer_requirements.txt")
  filename = "${path.module}/build_requirements.txt"
}

# Create the layer directory structure
resource "null_resource" "prepare_lambda_layer" {
  triggers = {
    requirements_hash = filesha256("${path.module}/layer_requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOF
      # Create directory structure
      echo "Creating layer structure..."
      mkdir -p ${path.module}/layer_build/python
      
      # Install dependencies with pip using --platform to target Lambda environment
      echo "Installing dependencies..."
      pip install \
        --platform manylinux2014_x86_64 \
        --target=${path.module}/layer_build/python \
        --implementation cp \
        --python-version 3.9 \
        --only-binary=:all: \
        --upgrade \
        -r ${path.module}/layer_requirements.txt
      
      # Quick check for essential packages
      if [ ! -d "${path.module}/layer_build/python/pydantic" ]; then
        echo "WARNING: pydantic package may be missing"
      fi
      
      # Check specifically for pydantic_core
      if [ -d "${path.module}/layer_build/python/pydantic_core" ]; then
        echo "pydantic_core is present"
        ls -la ${path.module}/layer_build/python/pydantic_core/
      else
        echo "WARNING: pydantic_core directory not found"
      fi
      
      # Clean unnecessary files to reduce layer size
      find ${path.module}/layer_build/python -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
      find ${path.module}/layer_build/python -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true
      find ${path.module}/layer_build/python -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
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
