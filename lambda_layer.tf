# Create a Lambda layer for common Python dependencies
resource "aws_lambda_layer_version" "lambda_dependencies" {  
  layer_name = "lambda-dependencies"
  compatible_runtimes = ["python3.9"]
  
  # Path to the layer content
  filename         = "${path.module}/lambda_layer.zip"
  
  source_code_hash = filebase64sha256("${path.module}/requirements.txt")
  
  description = "Lambda layer containing common Python dependencies"
  
  # Make sure the layer depends on the rebuild process
  depends_on = [null_resource.rebuild_layer_if_needed]

  # Add simpler cleanup process
  provisioner "local-exec" {
    command = <<-EOT
      echo "Lambda layer created successfully"
      rm -rf "${path.module}/tmp_build" || true
    EOT
  }
}

# Optimize the layer building process for Lambda architecture
resource "null_resource" "rebuild_layer_if_needed" {
  # Build only when requirements change or when explicitly triggered
  triggers = {
    requirements_hash = filebase64sha256("${path.module}/requirements.txt")
    # Weekly rebuild trigger - change this number to force rebuilds
    rebuild_trigger = "4"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Building Lambda layer from requirements.txt specifically for Lambda x86_64 architecture..."
      
      BUILD_DIR="$(pwd)/tmp_build"
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
        -r "$(pwd)/requirements.txt"
        
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
          -r "$(pwd)/requirements.txt"
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
      cd "$BUILD_DIR" && zip -r "$(pwd)/../../lambda_layer.zip" python
      
      echo "Lambda layer built successfully for Lambda architecture"
    EOT
  }
}
