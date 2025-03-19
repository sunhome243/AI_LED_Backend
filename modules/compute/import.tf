# Resource import configuration file
# Used for importing existing AWS resources into Terraform state
# Requires Terraform 1.5.0+
# Comment out this entire file after successful import

/*
# WebSocket Lambda function import
import {
  id = "ws-messenger"
  to = module.websocket.aws_lambda_function.ws_messenger_lambda
}

# Compute module Lambda function imports
import {
  id = "audio-to-ai"
  to = module.compute.aws_lambda_function.functions["audio_to_ai"]
}

import {
  id = "pattern-to-ai"
  to = module.compute.aws_lambda_function.functions["pattern_to_ai"]
}

import {
  id = "result-save-send"
  to = module.compute.aws_lambda_function.functions["result_save_send"]
}

import {
  id = "is-connect"
  to = module.compute.aws_lambda_function.functions["isConnect"]
}
*/
