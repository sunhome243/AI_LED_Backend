resource "null_resource" "install_dependencies" {
  triggers = {
    ai_requirements_hash = sha256(file("${local.base_dir}/lambda/pattern_to_ai/requirements.txt"))
  }

  provisioner "local-exec" {
    command = <<EOT
      # create new directory for the layer
      mkdir -p "${path.module}/layer/python"
      # install dependencies directly from requirements.txt
      pip install -r "${local.base_dir}/lambda/pattern_to_ai/requirements.txt" -t "${path.module}/layer/python/"
    EOT
  }
}

# create lambda layer zip file
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/archive/lambda_layer_${sha256(
    fileexists("${local.base_dir}/lambda/pattern_to_ai/requirements.txt") ? file("${local.base_dir}/lambda/pattern_to_ai/requirements.txt") : ""
  )}.zip"
  depends_on  = [null_resource.install_dependencies]
}

# Create lambda layer
resource "aws_lambda_layer_version" "dependencies_layer" {
  layer_name          = "shared-dependencies"
  filename            = data.archive_file.lambda_layer_zip.output_path
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9"]
  
  description = "Shared dependencies layer for Lambda functions (protobuf, shortuuid, google-generativeai)"
}
