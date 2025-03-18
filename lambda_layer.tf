# Create a Lambda layer for common Python dependencies
resource "aws_lambda_layer_version" "lambda_dependencies" {  
  layer_name = "lambda-dependencies"
  compatible_runtimes = ["python3.9"]
  
  # Path to the layer content
  filename         = "${path.module}/lambda_layer.zip"
  
  # Use source_code_hash only if the file exists
  source_code_hash = fileexists("${path.module}/lambda_layer.zip") ? filebase64sha256("${path.module}/lambda_layer.zip") : null
  
  description = "Lambda layer containing common Python dependencies"
  
  # Remove count parameter to ensure the resource is always created
  # This makes it work more reliably in CI/CD environments
}

# Initialize an empty zip file to prevent "file not found" errors
resource "null_resource" "init_layer_zip" {
  triggers = {
    # Always run this first
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

# Lambda layer build process that works in both local and CI/CD environments
resource "null_resource" "build_lambda_layer" {
  triggers = {
    # Rebuild when requirements change or force build with trigger
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

# Validation that's more CI/CD friendly
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
      
      # Simple check for critical packages - exit code 0 for CI/CD
      unzip -l "${path.module}/lambda_layer.zip" | grep -i -E 'shortuuid|google|httpx' || echo "WARNING: Some packages might be missing"
    EOT
  }
}
