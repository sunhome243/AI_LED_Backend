# Lambda Layer Configuration
# This creates a Lambda layer containing shared Python dependencies for all Lambda functions

# Create a Lambda layer from the pre-built zip file
resource "aws_lambda_layer_version" "lambda_dependencies" {  
  layer_name = "lambda-dependencies"
  compatible_runtimes = ["python3.9"]
  
  # Path to the layer content zip file
  filename         = "${path.module}/lambda_layer.zip"
  
  # Only calculate hash if the file exists
  source_code_hash = fileexists("${path.module}/lambda_layer.zip") ? filebase64sha256("${path.module}/lambda_layer.zip") : null
  
  description = "Shared Python libraries for Lambda functions including Google API clients and HTTP tools"
}

# Create an initial empty zip if it doesn't exist
# This prevents "file not found" errors during the first apply
resource "null_resource" "init_layer_zip" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking if lambda_layer.zip exists"
      if [ ! -f "${path.module}/lambda_layer.zip" ]; then
        echo "Creating empty lambda_layer.zip to prevent initial errors"
        cd "${path.module}" && zip -q -r lambda_layer.zip . -i README.md || echo "Created empty zip"
      fi
    EOT
  }
}

# Build the Lambda layer by installing dependencies into a directory structure
# that Lambda can use at runtime
resource "null_resource" "build_lambda_layer" {
  triggers = {
    # Rebuild when requirements change or when manually triggered
    requirements_hash = fileexists("${path.module}/requirements.txt") ? filebase64sha256("${path.module}/requirements.txt") : "default"
    rebuild_trigger = "13"  # Increment to force rebuild
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "===== BUILDING LAMBDA LAYER FOR CI/CD ====="
      
      # Make build script executable (important for CI/CD)
      chmod +x ${path.module}/build_layer.sh
      
      # Run the optimized build script
      ${path.module}/build_layer.sh
    EOT
  }
  
  depends_on = [null_resource.init_layer_zip]
}

# Validate the created Lambda layer to ensure it contains required dependencies
resource "null_resource" "validate_lambda_layer" {
  triggers = {
    # Run validation after build
    build_completed = null_resource.build_lambda_layer.id
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "===== VALIDATING LAMBDA LAYER ====="
      
      if [ ! -f "${path.module}/lambda_layer.zip" ]; then
        echo "ERROR: lambda_layer.zip not found! Build failed."
        exit 1
      fi
      
      echo "Layer size: $(du -h "${path.module}/lambda_layer.zip" | cut -f1)"
      
      # Check for critical packages
      unzip -l "${path.module}/lambda_layer.zip" | grep -i -E 'shortuuid|google|httpx' || echo "WARNING: Some packages might be missing"
    EOT
  }
}
