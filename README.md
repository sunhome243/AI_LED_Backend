# AI LED Backend

This repository contains the Infrastructure as Code (IaC) for an AI-powered LED control system using AWS services and Terraform. The system processes audio and pattern inputs through AI to generate personalized lighting configurations, which are then sent to IoT devices.


## Components

### API Gateway
- REST API endpoints for audio and pattern processing
- WebSocket API for real-time communication with LED controllers

### Lambda Functions
- `audio_to_ai`: Processes audio files and sends to AI for emotion analysis
- `pattern_to_ai`: Processes pattern data for AI-based lighting suggestions
- `result_save_send`: Saves AI results and sends commands to devices
- `connection_manager`: Manages WebSocket connections

### DynamoDB Tables
- `AuthTable`: User authentication with UUID and PIN
- `IrCodeTable`: Stores IR codes for controlling LED devices
- `ResponseTable`: Records AI responses and user interactions
- `ConnectionIdTable`: Maps UUIDs to WebSocket connection IDs

### S3 Buckets
- Storage for response data and assets

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform v1.0.0+ installed
- Python 3.9+ for Lambda development

## Environment Variables

The following environment variables are required:

```
REGION_NAME=us-east-1
GOOGLE_GEMINI_API_KEY=your_api_key_here
BUCKET_NAME=prisim-led-proto-response-data
WEBSOCKET_URL=wss://your-api-gateway-id.execute-api.region.amazonaws.com/develop
RESULT_LAMBDA_NAME=result_save_send
```

## Setup Instructions

1. Clone this repository
```
git clone https://github.com/yourusername/AI_LED_Backend.git
cd AI_LED_Backend
```

2. Initialize Terraform
```
terraform init
```

3. Create a `terraform.tfvars` file with your configuration:
```
rest_api_name = "your-api-name"
stage_name = "develop"
lambda_role_arn = "arn:aws:iam::account_id:role/your_lambda_execution_role"
connection_table_name = "ConnectionIdTable"
gateway_role_arn = "arn:aws:iam::account_id:role/your_gateway_role"
```

## Deployment

1. Review the planned changes
```
terraform plan
```

2. Apply the configuration
```
terraform apply
```

3. To destroy the infrastructure when no longer needed
```
terraform destroy
```

## Module Structure

- `/modules/websocket`: WebSocket API Gateway and Lambda handler
- `/modules/networking`: REST API Gateway configuration
- `/modules/database`: DynamoDB tables and S3 bucket configurations

## Lambda Functions

The Lambda functions are located in the `/lambda` directory:

- `/lambda/websocket`: WebSocket connection management
- `/lambda/audio_to_ai`: Audio processing pipeline
- `/lambda/pattern_to_ai`: Pattern-based recommendation system
- `/lambda/result_save_send`: Result processing and device communication

## Authentication

The system uses a simple UUID and PIN authentication mechanism stored in DynamoDB.

## Contact

sunhome243@gmail.com