#!/bin/bash
# CI/CD compatible script to build Lambda layer with correct architecture

set -e  # Exit on error

echo "===== BUILDING OPTIMIZED LAMBDA LAYER FOR AWS LAMBDA x86_64 ARCHITECTURE ====="

# Get script directory regardless of where it's called from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR"

# Create build directory
BUILD_DIR="$SCRIPT_DIR/layer_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/python/lib/python3.9/site-packages"

# Display versions for debugging in CI/CD logs
python --version
pip --version

echo "Installing dependencies with Lambda architecture compatibility (manylinux2014_x86_64)..."
# First try with flexible version resolution
cat requirements.txt | sed 's/multidict==6.0.4/multidict>=6.0.4/g' > requirements_fixed.txt

pip install \
  -r requirements_fixed.txt \
  --platform manylinux2014_x86_64 \
  --target "$BUILD_DIR/python/lib/python3.9/site-packages" \
  --only-binary=:all: \
  --no-cache-dir

# Check if the installation succeeded
if [ $? -ne 0 ]; then
  echo "WARNING: Some packages may not have manylinux2014_x86_64 binaries available."
  echo "Attempting to install critical packages individually..."
  
  # Install critical packages individually with architecture constraints
  pip install \
    "shortuuid==1.0.13" \
    --platform manylinux2014_x86_64 \
    --target "$BUILD_DIR/python/lib/python3.9/site-packages" \
    --only-binary=:all: \
    --no-cache-dir
    
  pip install \
    "httpx>=0.28.1,<1.0.0" \
    --platform manylinux2014_x86_64 \
    --target "$BUILD_DIR/python/lib/python3.9/site-packages" \
    --only-binary=:all: \
    --no-cache-dir
  
  # Some Google packages may need standard installation
  echo "Installing Google packages (may not have manylinux binaries)..."
  pip install \
    "google-genai==1.5.0" \
    "google-auth==2.28.0" \
    --target "$BUILD_DIR/python/lib/python3.9/site-packages" \
    --no-cache-dir
fi

echo "Verifying package installation..."
for package in shortuuid google httpx boto3; do
  if [ -d "$BUILD_DIR/python/lib/python3.9/site-packages/$package" ] || \
     [ -d "$BUILD_DIR/python/lib/python3.9/site-packages/${package//-/_}" ]; then
    echo "✓ $package found"
  else
    echo "✗ $package NOT FOUND - may cause issues"
  fi
done

echo "Removing unnecessary files to reduce size..."
# Remove tests, examples, and other unnecessary files
find "$BUILD_DIR" -type d -name "tests" -exec rm -rf {} \; 2>/dev/null || true
find "$BUILD_DIR" -type d -name "examples" -exec rm -rf {} \; 2>/dev/null || true
find "$BUILD_DIR" -type d -name "__pycache__" -exec rm -rf {} \; 2>/dev/null || true
find "$BUILD_DIR" -name "*.pyc" -delete 2>/dev/null || true
find "$BUILD_DIR" -name "*.pyo" -delete 2>/dev/null || true

# Create the zip file
echo "Creating optimized layer zip..."
cd "$BUILD_DIR" && zip -r "$SCRIPT_DIR/lambda_layer.zip" python -x "*.pyc" "__pycache__/*"

# Check the final size and contents
echo "Layer size: $(du -h "$SCRIPT_DIR/lambda_layer.zip" | cut -f1)"
echo "Key packages:"
unzip -l "$SCRIPT_DIR/lambda_layer.zip" | grep -E "shortuuid|google|httpx|boto3"

# Clean up
cd "$SCRIPT_DIR"
rm -rf "$BUILD_DIR"

echo "===== LAMBDA LAYER BUILD COMPLETE ====="
