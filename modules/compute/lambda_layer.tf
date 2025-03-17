# Create a directory structure for the Lambda layer
resource "null_resource" "create_layer_structure" {
  triggers = {
    # Rebuild when requirements change or Python version changes
    requirements_hash = sha256(file("${path.module}/layer_requirements.txt"))
    python_version = "3.9" # Update this when changing Python version
  }

  provisioner "local-exec" {
    # Enhanced logging and error handling with more cross-platform compatibility
    command = <<-EOF
      echo "Starting Lambda layer build process..."
      echo "Cleaning previous build directory..."
      rm -rf ${path.module}/layer_build
      
      echo "Creating new build directory structure..."
      mkdir -p ${path.module}/layer_build/python
      
      echo "Installing Python dependencies from requirements file..."
      pip install --no-cache-dir -r ${path.module}/layer_requirements.txt -t ${path.module}/layer_build/python
      
      # Remove unnecessary files to reduce layer size
      echo "Cleaning up unnecessary files..."
      find ${path.module}/layer_build -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true
      find ${path.module}/layer_build -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
      find ${path.module}/layer_build -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
      
      # Verify files were actually created
      if [ ! "$(ls -A ${path.module}/layer_build/python)" ]; then
        echo "ERROR: Dependencies installation failed - directory is empty"
        exit 1
      fi
      
      echo "Lambda layer build completed successfully"
    EOF
  }
}

# Create an empty layer_build directory to ensure it exists for plan phase
resource "null_resource" "ensure_directory_exists" {
  triggers = {
    # Use a more reliable way to force execution when needed
    build_needed = fileexists("${path.module}/layer_build/python/.placeholder") ? "exists" : "create"
  }

  provisioner "local-exec" {
    command = <<-EOF
      mkdir -p ${path.module}/layer_build/python
      touch ${path.module}/layer_build/python/.placeholder
    EOF
  }

  # Run this before other resources are evaluated
  lifecycle {
    create_before_destroy = true
  }
}

# Create the layer ZIP file
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/lambda_layer.zip"
  excludes    = [".placeholder"]  # Don't include placeholder files in the archive
  
  depends_on = [
    null_resource.create_layer_structure,
    null_resource.ensure_directory_exists
  ]
}

# Create the Lambda layer
resource "aws_lambda_layer_version" "dependencies_layer" {
  layer_name          = "shared-dependencies"
  filename            = data.archive_file.lambda_layer_zip.output_path
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
  
  description = "Shared dependencies for Lambda functions"
  
  depends_on = [data.archive_file.lambda_layer_zip]
  
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
  }

  depends_on = [aws_lambda_layer_version.dependencies_layer]
}
