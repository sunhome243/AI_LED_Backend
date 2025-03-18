# 이 파일은 기존 리소스를 임포트하기 위한 코드입니다.
# 리소스 가져오기를 완료한 후에는 이 파일을 삭제하거나 주석 처리하세요.
# Terraform 1.5.0 이상 필요

/*
# Websocket Lambda 함수 임포트
import {
  id = "ws-messenger"
  to = module.websocket.aws_lambda_function.ws_messenger_lambda
}

# 컴퓨트 모듈 Lambda 함수 임포트
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
