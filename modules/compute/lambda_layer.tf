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
      
      # Show the contents of the requirements file
      echo "Requirements file contents:"
      cat ${path.module}/layer_requirements.txt
      
      # Install dependencies with pip using a more reliable approach
      echo "Installing dependencies..."
      python -m pip install \
        --no-cache-dir \
        --upgrade \
        -r ${path.module}/layer_requirements.txt \
        --target ${path.module}/layer_build/python
      
      # Check if installation was successful
      if [ $? -ne 0 ]; then
        echo "Error: Failed to install Python dependencies"
        exit 1
      fi
      
      # List the installed dependencies to verify they were installed
      echo "Installed dependencies:"
      ls -la ${path.module}/layer_build/python
      
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
    command = "rm -rf ${path.module}/lambda_layer.zip ${path.module}/layer_build"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [aws_lambda_layer_version.dependencies_layer]
}
