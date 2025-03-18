import json
import os
import logging
import base64
import shortuuid
from datetime import datetime
from boto3.session import Session
from google import genai
from gemini_config import get_gemini_config
from constants import VALID_DYNAMIC_MODES


class AuthenticationError(Exception):
    """Custom exception for authentication failures"""
    pass


class AIProcessingError(Exception):
    """Custom exception for AI processing failures"""
    pass


# Initialize the logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients outside of the handler
region_name = os.environ.get('REGION_NAME', 'us-east-1')

# Create a session to use for clients
boto_session = Session(region_name=region_name)

# Generate clients
dynamodb = boto_session.resource('dynamodb')
lambda_client = boto_session.client('lambda')

# Generate unique request ID for tracing
request_id = shortuuid.uuid()

# Gemini API initialization
google_gemini_api_key = os.environ.get('GOOGLE_GEMINI_API_KEY')
if not google_gemini_api_key:
    raise EnvironmentError(
        "GOOGLE_GEMINI_API_KEY environment variable is not set")
client = genai.Client(api_key=google_gemini_api_key)


# CORS headers to include in all responses
CORS_HEADERS = {
    'Content-Type': "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS, POST, GET",
    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
}


def auth_user(uuid, pin):
    """
    Authenticate user by comparing the provided pin with the stored pin in DynamoDB.

    Args:
        uuid (str): The unique identifier for the user.
        pin (str): The pin provided by the user.

    Raises:
        AuthenticationError: If the authentication fails.

    Returns:
        bool: True if authentication is successful.
    """
    table = dynamodb.Table("AuthTable")

    try:
        # Query using both the hash key (uuid) and range key (pin)
        response = table.get_item(Key={'uuid': uuid, 'pin': pin})

        # If the item exists, authentication is successful
        if 'Item' in response:
            return True
        else:
            logger.warning(f"Invalid UUID/PIN combination for UUID: {uuid}")
            raise AuthenticationError("Invalid UUID/PIN combination")

    except Exception as e:
        logger.error(f"Failed to authenticate user: {str(e)}")
        raise AuthenticationError("Authentication failed")


def store_wav_file(uuid, file):
    """
    Store a binary audio file to a temporary location in Lambda's ephemeral storage.

    Creates a temporary WAV file named after the user's UUID to be used for
    audio processing with the Gemini AI model.

    Args:
        uuid (str): The unique identifier for the user.
        file (bytes): The binary audio data to store.

    Returns:
        str: The path to the stored temporary wav file.

    Raises:
        IOError: If file writing fails
    """
    # Create a temporary file path using the user's UUID
    wav_file = f"/tmp/{uuid}.wav"
    try:
        # Write binary data to file
        with open(wav_file, "wb") as f:
            f.write(file)
        return wav_file
    except Exception as e:
        logger.error(f"Failed to write audio file: {str(e)}")
        raise IOError(f"Failed to write audio file: {str(e)}")


def get_genai_response(file):
    """
    Generate a response using the Gemini AI model based on the uploaded audio file.

    This function:
    1. Reads the audio file as binary data
    2. Configures and sends a prompt to process the audio content
    3. Returns the AI-generated response for lighting configuration

    Args:
        file (str): Path to the audio file to be uploaded for processing.

    Returns:
        dict: The response from the Gemini AI model.

    Raises:
        AIProcessingError: If Gemini AI processing fails
    """
    try:
        # Read the audio file directly instead of uploading
        with open(file, 'rb') as f:
            audio_data = f.read()

        # Create instruction text similar to pattern_to_ai
        instruction_text = """Adaptive Personalized Lighting Assistant

You are an AI that analyzes audio to determine context, emotion, and activity to make personalized lighting recommendations.
Based on the audio content, recommend appropriate lighting that enhances the detected mood, context or activity.
The AI must select either RGB color or Dynamic mode—never both.

Output Schema must be valid JSON with the following structure:
{
  "context": "Brief description of the context detected in audio",
  "emotion": {
    "main": "Primary emotion detected",
    "subcategories": ["emotion1", "emotion2", "emotion3"]
  },
  "lightSetting": {
    "power": true,
    "color": [255, 255, 255]
  },
  "recommendation": "Friendly message explaining the lighting choice based on audio"
}"""

        # Create comprehensive prompt combining instruction and audio file
        combined_prompt = f"{instruction_text}\n\nUser Request: Analyze this audio and recommend optimal lighting settings."

        # Create contents with user role including the audio file reference using inline_data
        contents = [
            {"role": "user", "parts": [
                {"text": combined_prompt},
                {
                    "inline_data": {
                        "mime_type": "audio/wav",
                        "data": base64.b64encode(audio_data).decode('utf-8')
                    }
                }
            ]}
        ]

        # Get configuration
        config = {
            'response_mime_type': 'application/json',
        }

        # Call the API with the correct format
        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=contents,
            config=config
        )

        return response
    except Exception as e:
        logger.error(f"Error in Gemini AI processing: {str(e)}")
        raise AIProcessingError(f"Gemini AI processing failed: {str(e)}")


def verify_and_parse_json(response):
    """
    Verify the JSON response to ensure it contains the required fields and valid values.

    Performs validation of the AI-generated lighting configuration to ensure it meets
    application requirements before being sent to devices.

    Args:
        response: The response object from Gemini API.

    Returns:
        dict: The parsed JSON if valid, None otherwise.
    """
    try:
        # Extract JSON from Gemini response
        json_response = json.loads(response.text)
    except Exception as e:
        logger.error(f"Not valid JSON: {str(e)}")
        return None

    # Check for required fields
    required_fields = ["context", "emotion", "lightSetting", "recommendation"]
    for field in required_fields:
        if json_response.get(field) is None:
            logger.error(f"Failed. Missing required field: {field}")
            return None

    light_setting = json_response["lightSetting"]

    # Extract lighting parameters
    color = light_setting.get("color")
    dynamic_mode = light_setting.get("dynamicMode")
    power = light_setting.get("power")

    # Validate light configuration based on power state and mode
    if color is None and dynamic_mode is None:
        if power is False:  # if power is off, no need to check color and dynamic mode
            pass
        else:
            logger.error(
                "Failed. Error in light mode: neither color nor dynamicMode specified when power is on")
            return None
    else:
        # Validate dynamic mode option if color is not specified
        if color is None:
            if dynamic_mode not in VALID_DYNAMIC_MODES:
                logger.error(f"Failed. Error in dynamic mode: {dynamic_mode}")
                return None
        # Validate RGB color format if dynamic mode is not specified
        if dynamic_mode is None:
            if not isinstance(color, list) or len(color) != 3 or not all(isinstance(code, int) and 0 <= code < 256 for code in color):
                logger.error(f"Failed. Error in color code: {color}")
                return None

    return json_response


def lambda_handler(event, context):
    """
    Main Lambda handler function that processes audio-based lighting requests.

    This function:
    1. Validates required parameters and environment variables
    2. Decodes and stores the base64 audio file
    3. Authenticates the user based on their UUID and PIN
    4. Sends the audio to Gemini AI to generate a lighting recommendation
    5. Validates the AI response to ensure it meets all requirements
    6. Passes the recommendation to another Lambda function for saving and sending to devices

    Args:
        event (dict): Lambda event payload containing:
                      - uuid: User's unique identifier
                      - pin: User's authentication PIN
                      - file: Base64-encoded audio file
        context (object): Lambda context object

    Returns:
        dict: API Gateway compatible response with:
             - statusCode: HTTP status code (200, 400, 401, 500)
             - headers: Response headers
             - body: Response body containing recommendation text and request ID or error message

    Environment Variables:
        REGION_NAME: AWS region (default: 'us-east-1')
        GOOGLE_GEMINI_API_KEY: API key for Google's Gemini AI service
    """
    # Validate required environment variables
    required_vars = ['REGION_NAME', 'GOOGLE_GEMINI_API_KEY']
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    if missing_vars:
        logger.error(
            f"Missing required environment variables: {', '.join(missing_vars)}")
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps(f"Missing required environment variables: {', '.join(missing_vars)}")
        }

    # Extract the payload from the API Gateway event - FIXED DUPLICATED CODE
    logger.info(f"Received event: {json.dumps(event)}")

    # Check if the event includes a 'body' field (API Gateway integration)
    if 'body' in event:
        try:
            # If body is a JSON string, parse it
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
            # Update event with the body content for parameter extraction
            event.update(body)
            logger.info(f"Parsed body: {json.dumps(body)}")
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse event body as JSON: {str(e)}")
            return {
                'statusCode': 400,
                'headers': CORS_HEADERS,
                'body': json.dumps("Invalid request body format")
            }

    # Handle API Gateway proxy integration where parameters might be in various places
    if 'requestContext' in event and 'pathParameters' in event and event['pathParameters']:
        # Extract parameters from the path if available
        params = event['pathParameters']
        for key in ['uuid', 'pin', 'file']:
            if key in params:
                event[key] = params[key]
                logger.info(
                    f"Found {key} in pathParameters: {params[key][:10]}...")

    # Validate required parameters
    required_params = {'uuid', 'pin', 'file'}
    if not isinstance(event, dict):
        logger.error("Event is not a dictionary")
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps("Invalid event format")
        }

    missing_params = required_params - set(event.keys())
    if missing_params:
        logger.error(
            f"Missing required parameters: {', '.join(missing_params)}")
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps(f"Missing required parameters: {', '.join(missing_params)}")
        }

    # Extract user credentials
    uuid = event['uuid']
    pin = event['pin']

    # Validate UUID and PIN
    if not uuid or not isinstance(uuid, str):
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps("Invalid UUID format")
        }

    if not pin or not isinstance(pin, str):
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps("Invalid PIN format")
        }

    # Decode base64 file content
    try:
        logger.info(
            f"Attempting to decode base64 file of length: {len(event['file'])}")
        file = base64.b64decode(event['file'])
        logger.info(f"Successfully decoded file, binary length: {len(file)}")
    except Exception as e:
        logger.error(f"Failed to decode base64 file: {str(e)}")
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps("Invalid file encoding")
        }

    # Authenticate the user
    try:
        auth_user(uuid, pin)
    except AuthenticationError as e:
        return {
            'statusCode': 401,
            'headers': CORS_HEADERS,
            'body': json.dumps(str(e))
        }

    wav_file = None
    # Store the audio file in temporary storage
    try:
        wav_file = store_wav_file(uuid, file)
    except IOError as e:
        logger.error(f"Failed to store audio file: {str(e)}")
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps(f"Failed to store audio file: {str(e)}")
        }

    # Generate AI recommendation with retry mechanism
    retry = 0
    parsed_json = None
    gemini_response = None

    # Retry up to 3 times to get a valid response
    while retry < 3 and parsed_json is None:
        try:
            gemini_response = get_genai_response(wav_file)
            parsed_json = verify_and_parse_json(gemini_response)
            if parsed_json is None:
                logger.warning(
                    f"Attempt {retry+1}/3: Invalid response from Gemini AI")
        except AIProcessingError as e:
            logger.error(f"Attempt {retry+1}/3: {str(e)}")

        retry += 1

    # Clean up temp file regardless of success or failure
    if wav_file and os.path.exists(wav_file):
        try:
            os.remove(wav_file)
        except Exception as e:
            logger.warning(f"Failed to delete temp file: {str(e)}")

    # If all retries failed, return error
    if not parsed_json:
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps("AI failed to create an appropriate response")
        }

    # Add metadata to the response
    parsed_json["request_id"] = request_id
    parsed_json["uuid"] = uuid
    parsed_json["timestamp"] = datetime.now().isoformat()

    # Invoke result-save-send Lambda to process the recommendation asynchronously
    try:
        result_lambda_name = os.environ.get(
            'RESULT_LAMBDA_NAME', 'result-save-send')
        logger.info(f"Invoking Lambda function: {result_lambda_name}")
        lambda_client.invoke(
            FunctionName=result_lambda_name,
            InvocationType='Event',  # for async invocation
            Payload=json.dumps(parsed_json)
        )
        logger.info(f"Successfully invoked {result_lambda_name} Lambda")
    except Exception as e:
        logger.error(f"Failed to invoke result Lambda: {str(e)}")
        # Continue execution to at least return recommendation to user

    # Return success response with recommendation text
    logger.info(f"Successfully processed request for UUID: {uuid}")
    return {
        'statusCode': 200,
        'headers': CORS_HEADERS,
        'body': json.dumps({
            "recommendation": parsed_json["recommendation"],
            "request_id": request_id,
            "complete_data": parsed_json  # Include full data in case Lambda invocation failed
        })
    }
