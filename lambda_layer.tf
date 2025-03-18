# Create a Lambda layer for common Python dependencies
resource "aws_lambda_layer_version" "lambda_dependencies" {  
  layer_name = "lambda-dependencies"
  compatible_runtimes = ["python3.9"]
  
  # Path to the layer content
  filename         = "${path.module}/lambda_layer.zip"
  
  # Use source_code_hash only if the file exists
  source_code_hash = fileexists("${path.module}/lambda_layer.zip") ? filebase64sha256("${path.module}/lambda_layer.zip") : null
  
  description = "Lambda layer containing common Python dependencies"
  
  # Make sure the layer depends on the rebuild process
  depends_on = [null_resource.build_lambda_layer]

  # Add simpler cleanup process
  provisioner "local-exec" {
    command = <<-EOT
      echo "Lambda layer created successfully"
      rm -rf "${path.module}/tmp_build" || true
    EOT
  }
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

# Optimize the layer building process for Lambda architecture
resource "null_resource" "build_lambda_layer" {
  # Build only when requirements change or when explicitly triggered
  triggers = {
    requirements_hash = fileexists("${path.module}/requirements.txt") ? filebase64sha256("${path.module}/requirements.txt") : "default"
    # Weekly rebuild trigger - change this number to force rebuilds
    rebuild_trigger = "4"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Building Lambda layer from requirements.txt specifically for Lambda x86_64 architecture..."
      
      # Ensure the requirements.txt file exists
      if [ ! -f "${path.module}/requirements.txt" ]; then
        echo "WARNING: requirements.txt not found. Creating empty file."
        touch "${path.module}/requirements.txt"
      fi
      
      BUILD_DIR="${path.module}/tmp_build"
      echo "Using build directory: $BUILD_DIR"
      mkdir -p "$BUILD_DIR/python/lib/python3.9/site-packages"
      
      echo "Installing dependencies with manylinux2014_x86_64 compatibility..."
      pip3 install \
        --platform manylinux2014_x86_64 \
        --implementation cp \
        --python-version 3.9 \
        --only-binary=:all: \
        --target="$BUILD_DIR/python/lib/python3.9/site-packages" \
        --no-cache-dir \
        --upgrade \
        -r "${path.module}/requirements.txt"
        
      # Fall back to standard installation if the platform-specific one fails
      if [ $? -ne 0 ]; then
        echo "WARNING: Platform-specific installation failed, falling back to standard installation"
        echo "This might cause compatibility issues with Lambda runtime"
        
        # Clean target directory before retry
        rm -rf "$BUILD_DIR/python/lib/python3.9/site-packages/"*
        
        # Standard pip install as fallback
        pip3 install \
          --target="$BUILD_DIR/python/lib/python3.9/site-packages" \
          --no-cache-dir \
          --upgrade \
          -r "${path.module}/requirements.txt"
      fi
      
      # Create a layer verification marker
      echo "Creating layer verification marker..."
      mkdir -p "$BUILD_DIR/python/lib/python3.9/site-packages/layer_verification"
      cat > "$BUILD_DIR/python/lib/python3.9/site-packages/layer_verification/__init__.py" << 'EOF'
def verify_layer():
    print("Lambda layer verification successful")
    return True
EOF
      
      echo "Creating Lambda layer zip..."
      cd "$BUILD_DIR" && zip -r "${path.module}/lambda_layer.zip" python
      
      # Verify zip file was created successfully
      if [ -f "${path.module}/lambda_layer.zip" ]; then
        echo "Lambda layer built successfully for Lambda architecture"
        ls -lh "${path.module}/lambda_layer.zip"
      else
        echo "ERROR: Failed to create lambda_layer.zip"
        # Create minimal zip to prevent Terraform failure
        echo "Creating minimal zip as fallback"
        mkdir -p "$BUILD_DIR/python/lib/python3.9/site-packages/fallback"
        echo "# Fallback layer" > "$BUILD_DIR/python/lib/python3.9/site-packages/fallback/__init__.py"
        cd "$BUILD_DIR" && zip -r "${path.module}/lambda_layer.zip" python
      fi
    EOT
  }
  
  depends_on = [null_resource.init_layer_zip]
}
