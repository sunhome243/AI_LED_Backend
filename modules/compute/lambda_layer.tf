# Create a directory structure for the Lambda layer
resource "null_resource" "create_layer_structure" {
  triggers = {
    # Rebuild when requirements change
    requirements_hash = sha256(file("${path.module}/layer_requirements.txt"))
  }

  provisioner "local-exec" {
    command = <<-EOF
      mkdir -p ${path.module}/layer_build/python
      pip install -r ${path.module}/layer_requirements.txt -t ${path.module}/layer_build/python
      # Verify files were actually created
      if [ ! "$(ls -A ${path.module}/layer_build/python)" ]; then
        echo "ERROR: Dependencies installation failed - directory is empty"
        exit 1
      fi
    EOF
  }
}

# Create the layer ZIP file
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/lambda_layer.zip"
  
  depends_on = [null_resource.create_layer_structure]
}

# Create the Lambda layer
resource "aws_lambda_layer_version" "dependencies_layer" {
  layer_name          = "shared-dependencies"
  filename            = data.archive_file.lambda_layer_zip.output_path
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
  
  description = "Shared dependencies for Lambda functions"
  
  depends_on = [data.archive_file.lambda_layer_zip]
}
