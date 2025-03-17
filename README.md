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

## API Reference

### REST API Endpoints

#### Pattern-to-AI API

- **Endpoint:** `POST /pattern_to_ai/create`
- **Description:** Generates "surprise me" lighting recommendations based on user's past responses and patterns.
- **Authentication:** Requires UUID and PIN
- **Request Body:**
  ```json
  {
    "uuid": "user-unique-identifier",
    "pin": "user-pin-code"
  }
  ```
- **Response:**
  ```json
  {
    "statusCode": 200,
    "body": ["Recommendation text explaining the lighting choice", "request-id"]
  }
  ```
- **Error Responses:**
  - 400: Invalid parameters
  - 401: Authentication failed
  - 404: No past response found
  - 500: Server error

#### Audio-to-AI API

- **Endpoint:** `POST /audio_to_ai/create`
- **Description:** Analyzes user's audio input to detect emotional state and generate appropriate lighting configuration.
- **Authentication:** Requires UUID and PIN
- **Request Body:**
  ```json
  {
    "uuid": "user-unique-identifier",
    "pin": "user-pin-code",
    "file": "base64-encoded-audio-file"
  }
  ```
- **Response:**
  ```json
  {
    "statusCode": 200,
    "body": ["Recommendation text explaining the lighting choice", "request-id"]
  }
  ```
- **Error Responses:**
  - 400: Invalid parameters or file format
  - 401: Authentication failed
  - 500: Server error

#### Connection Status API

- **Endpoint:** `POST /is_connect`
- **Description:** Checks if a device with the specified UUID is currently connected via WebSocket.
- **Request Body:**
  ```json
  {
    "uuid": "device-unique-identifier"
  }
  ```
- **Response:**
  ```json
  {
    "statusCode": 200,
    "body": {
      "connected": true|false,
      "message": "Arduino is connected|Arduino is not connected"
    }
  }
  ```
- **Error Responses:**
  - 400: Invalid parameters
  - 500: Server error

### WebSocket API

- **Endpoint:** `wss://your-api-gateway-id.execute-api.region.amazonaws.com/develop`
- **Description:** Provides real-time bidirectional communication between the backend and LED devices.

#### Connection Management

- **Connect:** `$connect?uuid=device-unique-identifier`
  - Establishes a WebSocket connection and associates the connection ID with the device UUID
  - Required query parameter: `uuid`
- **Disconnect:** `$disconnect`
  - Terminates the WebSocket connection and removes the connection mapping

#### Message Handling

- **Route:** `MESSAGE`
  - Used for bidirectional communication between the backend and devices
  - The LED devices receive lighting configurations in the following format:
    ```json
    {
      "rgbCode": [255, 0, 0],
      "dynamicIr": "IR_CODE_STRING",
      "enterDiy": "IR_CODE_STRING",
      "power": "IR_CODE_STRING",
      "rup": "IR_CODE_STRING",
      "rdown": "IR_CODE_STRING",
      "gup": "IR_CODE_STRING",
      "gdown": "IR_CODE_STRING",
      "bup": "IR_CODE_STRING",
      "bdown": "IR_CODE_STRING"
    }
    ```

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
