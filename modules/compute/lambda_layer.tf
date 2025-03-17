# Create the layer directory structure immediately
resource "local_file" "layer_directory" {
  content     = "# This is a placeholder file for terraform planning phase"
  filename    = "${path.module}/layer_build/python/.placeholder"
  directory_permission = "0755"
  file_permission      = "0644"

  # Ensure parent directories exist
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/layer_build/python"
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  # Force execution
  lifecycle {
    create_before_destroy = true
  }
}

# Install Python dependencies only during apply phase
resource "null_resource" "install_dependencies" {
  depends_on = [local_file.layer_directory]
  
  # Rebuild when requirements change
  triggers = {
    requirements_hash = fileexists("${path.module}/layer_requirements.txt") ? sha256(file("${path.module}/layer_requirements.txt")) : "no-requirements-file"
    python_version = "3.9"
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo "Starting Lambda layer build process..."
      echo "Installing Python dependencies from requirements file..."
      pip install --no-cache-dir -r ${path.module}/layer_requirements.txt -t ${path.module}/layer_build/python
      
      # Remove unnecessary files to reduce layer size
      echo "Cleaning up unnecessary files..."
      find ${path.module}/layer_build -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true
      find ${path.module}/layer_build -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
      find ${path.module}/layer_build -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
      
      echo "Lambda layer build completed successfully"
    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}

# Create the layer ZIP file
data "archive_file" "lambda_layer_zip" {
  depends_on  = [local_file.layer_directory]
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/lambda_layer.zip"
  excludes    = [".placeholder"]
}

# Create the Lambda layer
resource "aws_lambda_layer_version" "dependencies_layer" {
  layer_name          = "shared-dependencies"
  filename            = data.archive_file.lambda_layer_zip.output_path
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
  
  description = "Shared dependencies for Lambda functions"
  
  # Add lifecycle configuration to handle updates more gracefully
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
