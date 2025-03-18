locals {
  # Define the path to the directory that contains both lambda and modules directories
  base_dir = abspath("${path.root}")
  
  # Define source directories and their destinations in a map format
  lambda_sources = {
    "audio_to_ai" = {
      source_dir = "${local.base_dir}/lambda/audio_to_ai"
      files_pattern = "**"
    },
    "pattern_to_ai" = {
      source_dir = "${local.base_dir}/lambda/pattern_to_ai"
      files_pattern = "**"
    },
    "result_save_send" = {
      source_dir = "${local.base_dir}/lambda/result_save_send"
      files_pattern = "**"
    },
    "isConnect" = {
      source_dir = "${local.base_dir}/lambda/websocket"
      files_pattern = "isConnect.py"
      special_handling = true
    }
  }
  
  # Calculate file lists and hashes dynamically
  file_lists = {
    for key, config in local.lambda_sources : key => [
      for file in fileset(config.source_dir, config.files_pattern) : 
      "${config.source_dir}/${file}"
    ]
  }
  
  # Calculate hash of source files to detect changes more reliably
  source_hashes = {
    for key, files in local.file_lists : key => 
      sha256(join("", [for f in files : filesha256(f)]))
  }
  
  # Define maximum size warning threshold (5MB)
  max_size_warning = 5 * 1024 * 1024
  
  # Output archive paths for debugging
  archive_paths = {
    for key in keys(local.lambda_sources) : key => 
      "${path.module}/archive/${key}_${local.source_hashes[key]}.zip"
  }
}

# Create archive directory explicitly before any operations
resource "null_resource" "ensure_archive_dir" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/archive ${path.module}/isConnect_tmp"
  }
}

# Special handling for isConnect file
resource "null_resource" "prepare_isConnect_dir" {
  triggers = {
    source_hash = local.source_hashes["isConnect"]
    # Force execution every time
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating isConnect_tmp directory..."
      mkdir -p ${path.module}/isConnect_tmp
      if [ -f "${local.base_dir}/lambda/websocket/isConnect.py" ]; then
        cp ${local.base_dir}/lambda/websocket/isConnect.py ${path.module}/isConnect_tmp/
        echo "Copied isConnect.py to temporary directory"
      else
        echo "WARNING: isConnect.py not found at expected location"
        # Create an empty file to prevent archive failure
        echo "# Placeholder file" > ${path.module}/isConnect_tmp/isConnect.py
      fi
      echo "Prepared isConnect directory for packaging"
      ls -la ${path.module}/isConnect_tmp/
    EOT
  }
  
  depends_on = [null_resource.ensure_archive_dir]
}

# Regular Lambda archives
data "archive_file" "audio_to_ai_lambda" {
  type        = "zip"
  source_dir  = local.lambda_sources.audio_to_ai.source_dir
  output_path = local.archive_paths.audio_to_ai
  depends_on  = [null_resource.ensure_archive_dir]
}

data "archive_file" "pattern_to_ai_lambda" {
  type        = "zip"
  source_dir  = local.lambda_sources.pattern_to_ai.source_dir
  output_path = local.archive_paths.pattern_to_ai
  depends_on  = [null_resource.ensure_archive_dir]
}

data "archive_file" "result_save_send_lambda" {
  type        = "zip"
  source_dir  = local.lambda_sources.result_save_send.source_dir
  output_path = local.archive_paths.result_save_send
  depends_on  = [null_resource.ensure_archive_dir]
}

# Special isConnect archive
data "archive_file" "isConnect_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/isConnect_tmp"
  output_path = local.archive_paths.isConnect
  depends_on  = [null_resource.prepare_isConnect_dir]
}

# Consolidated size check
resource "null_resource" "check_archive_sizes" {
  triggers = {
    # Track all hash changes
    hashes = join(",", [for key, hash in local.source_hashes : "${key}=${hash}"])
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking Lambda archive sizes..."
      
      # Check all archives in a loop
      check_size() {
        local file=$1
        local name=$2
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
        echo "$name archive size: $size bytes"
        if [ $size -gt ${local.max_size_warning} ]; then
          echo "WARNING: $name archive is larger than 5MB which may slow down deployments"
        fi
      }

      check_size "${local.archive_paths.audio_to_ai}" "audio_to_ai"
      check_size "${local.archive_paths.pattern_to_ai}" "pattern_to_ai"
      check_size "${local.archive_paths.result_save_send}" "result_save_send" 
      check_size "${local.archive_paths.isConnect}" "isConnect"
      
      echo "Archive size check complete!"
    EOT
  }
  
  depends_on = [
    data.archive_file.audio_to_ai_lambda,
    data.archive_file.pattern_to_ai_lambda,
    data.archive_file.result_save_send_lambda,
    data.archive_file.isConnect_lambda
  ]
}

# Consolidated cleanup
resource "null_resource" "cleanup_resources" {
  triggers = {
    # Run on every apply
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Cleaning up resources..."
      # Clean up old archives
      find ${path.module}/archive -name "*.zip" -type f -mtime +1 -delete || echo "No old archives to clean"
      # Clean up isConnect tmp directory after use
      rm -rf ${path.module}/isConnect_tmp || true
      echo "Cleanup complete!"
    EOT
  }
  
  depends_on = [null_resource.check_archive_sizes]
}