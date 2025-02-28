import json
import os
import logging
import base64
import asyncio
from datetime import datetime
from boto3.session import Session
from boto3.dynamodb.conditions import Key
import google.generativeai as genai
from gemini_config import get_gemini_config
from constants import DYNAMIC_MODES, VALID_DYNAMIC_MODES, IR_CODE_MAP, DEFAULT_IR_RESULT


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
s3_client = boto_session.client('s3')
dynamodb = boto_session.resource('dynamodb')

# Gemini API initialization
google_gemini_api_key = os.environ.get('GOOGLE_GEMINI_API_KEY')
if not google_gemini_api_key:
    raise EnvironmentError(
        "GOOGLE_GEMINI_API_KEY environment variable is not set")
client = genai.Client(api_key=google_gemini_api_key)


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
    table = dynamodb.Table("auth_table")

    try:
        response = table.get_item(Key={'uuid': uuid})
        stored_pin = response.get("Item", {}).get("pin")

        if not stored_pin or stored_pin != pin:
            logger.warning(f"Invalid PIN provided for UUID: {uuid}")
            raise AuthenticationError("Invalid pin")

        return True

    except Exception as e:
        logger.error(f"Failed to authenticate user: {str(e)}")
        raise AuthenticationError("Authentication failed")


def store_wav_file(uuid, file):
    """
    Store a binary audio file to a temporary location.

    Args:
        uuid (str): The unique identifier for the user.
        file (bytes): The binary audio data to store.

    Returns:
        str: The path to the stored temporary wav file.

    Raises:
        IOError: If file writing fails
    """
    wav_file = f"/tmp/{uuid}.wav"
    try:
        with open(wav_file, "wb") as f:
            f.write(file)
        return wav_file
    except Exception as e:
        logger.error(f"Failed to write audio file: {str(e)}")
        raise IOError(f"Failed to write audio file: {str(e)}")


def get_genai_response(file):
    """
    Generate a response using the Gemini AI model based on the uploaded file.

    Args:
        file (str): an audio file to be uploaded for processing.

    Returns:
        dict: The response from the Gemini AI model.

    Raises:
        AIProcessingError: If Gemini AI processing fails
    """
    uploaded_file = None
    try:
        uploaded_file = client.files.upload(file)

        generate_content_config = get_gemini_config()

        model = "gemini-2.0-flash"
        response = client.models.generate_content(
            model,
            contents=[
                'follow the system instruction',
                uploaded_file,
            ],
            config=generate_content_config,
        )

        return response
    except Exception as e:
        logger.error(f"Error in Gemini AI processing: {str(e)}")
        raise AIProcessingError(f"Gemini AI processing failed: {str(e)}")
    finally:
        # Clean up the uploaded file regardless of success or failure
        if uploaded_file:
            try:
                client.files.delete(name=uploaded_file.name)
            except Exception as e:
                logger.warning(f"Failed to delete uploaded file: {str(e)}")


def verify_and_parse_json(response):
    """
    Verify the JSON response to ensure it contains the required fields and valid values.

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

    color = light_setting.get("color")
    dynamic_mode = light_setting.get("dynamicMode")
    power = light_setting.get("power")

    if color is None and dynamic_mode is None:
        if power is False:  # if power is off, no need to check color and dynamic mode
            pass
        else:
            logger.error(
                "Failed. Error in light mode: neither color nor dynamicMode specified when power is on")
            return None
    else:
        if color is None:
            if dynamic_mode not in VALID_DYNAMIC_MODES:
                logger.error(f"Failed. Error in dynamic mode: {dynamic_mode}")
                return None
        if dynamic_mode is None:
            if not isinstance(color, list) or len(color) != 3 or not all(isinstance(code, int) and 0 <= code < 256 for code in color):
                logger.error(f"Failed. Error in color code: {color}")
                return None

    return json_response


async def configure_light_settings(json_response):
    """
    Configure light settings based on the JSON response from Gemini AI.

    Args:
        json_response (dict): The parsed JSON response containing light settings.

    Returns:
        str: A JSON string containing the light configuration and IR codes.
    """
    light_setting = json_response["lightSetting"]
    device_type = "light"

    result = {}

    # Set power state from light_setting
    power = light_setting.get("power", True)

    if not power:
        # If power is off, we don't need RGB values or dynamic mode
        result["rgbCode"] = [0, 0, 0]
        ir_codes = get_ir_code(device_type)
    elif light_setting.get("lightType") == "color":
        # Get RGB values from the response
        result["rgbCode"] = light_setting.get("color", [0, 0, 0])
        # Get IR codes for controlling RGB light
        ir_codes = get_ir_code(device_type)
    else:
        # Set rgbCode to default for dynamic mode
        result["rgbCode"] = [0, 0, 0]
        # Get dynamic mode from lightSetting
        dynamic_mode = light_setting.get("dynamicMode")
        # Get IR codes for dynamic mode
        ir_codes = get_dynamic_mode(dynamic_mode, device_type)

    # Add IR codes to the result
    result["dynamicIr"] = ir_codes.get("dynamic", "")
    result["enterDiy"] = ir_codes.get("enterDiy", "")
    result["power"] = ir_codes.get("power", "")
    result["rup"] = ir_codes.get("r_up", "")
    result["rdown"] = ir_codes.get("r_down", "")
    result["gup"] = ir_codes.get("g_up", "")
    result["gdown"] = ir_codes.get("g_down", "")
    result["bup"] = ir_codes.get("b_up", "")
    result["bdown"] = ir_codes.get("b_down", "")

    # Convert the result to JSON string
    return json.dumps(result)


def get_ir_code_from_table(device_type, ir_id):
    """
    Generic function to retrieve IR codes from DynamoDB.

    Args:
        device_type (str): Type of device to control
        ir_id (int): ID of the IR code to retrieve

    Returns:
        str: The IR code or None if not found
    """
    table = dynamodb.Table("ircode-transition-table")
    try:
        response = table.get_item(
            Key={
                'deviceType': device_type,
                'id': ir_id
            }
        )
        if 'Item' in response and 'ir_code' in response['Item']:
            return response['Item']['ir_code']
    except Exception as e:
        logger.error(f"Failed to retrieve item from DynamoDB: {str(e)}")
    return None


def get_ir_code(device_type):
    """
    Get the IR codes for RGB control from DynamoDB.

    Args:
        device_type (str): The type of device.

    Returns:
        dict: Dictionary containing IR codes for RGB up/down control.
    """
    result = DEFAULT_IR_RESULT.copy()

    try:
        # Query for each item with the specified deviceType and id
        for ir_id, key in IR_CODE_MAP.items():
            result[key] = get_ir_code_from_table(device_type, ir_id)
    except Exception as e:
        logger.error(f"Failed to retrieve items from DynamoDB: {str(e)}")

    return result


def get_dynamic_mode(dynamic_mode, device_type):
    """
    Get the IR code for the dynamic mode.

    Args:
        dynamic_mode (str): The dynamic mode.
        device_type (str): The type of device.

    Returns:
        dict: Dictionary containing IR code for the dynamic mode and power.
    """
    # Initialize result with default values
    result = DEFAULT_IR_RESULT.copy()

    try:
        dynamic_mode_id = DYNAMIC_MODES.get(dynamic_mode)
        if dynamic_mode_id is None:
            logger.error(f"Unknown dynamic mode: {dynamic_mode}")
            return result

        # Get the dynamic mode IR code
        result["dynamic"] = get_ir_code_from_table(
            device_type, dynamic_mode_id)

        # Get the power IR code
        result["power"] = get_ir_code_from_table(
            device_type, 18)  # ID for power

        # Get the DIY IR code
        result["enterDiy"] = get_ir_code_from_table(
            device_type, 19)  # ID for enter DIY mode

    except Exception as e:
        logger.error(f"Failed to retrieve item from DynamoDB: {str(e)}")

    return result


async def upload_response_s3(response, uuid):
    """
    Upload the JSON response to an S3 bucket.

    Args:
        response (str): The JSON response as a string.
        uuid (str): The unique identifier for the user.

    Returns:
        str: The S3 key of the uploaded file or None if upload fails.
    """
    if not response:
        logger.warning("Empty response, skipping S3 upload")
        return None

    bucket_name = os.environ.get('BUCKET_NAME')
    if not bucket_name:
        logger.error("BUCKET_NAME environment variable not set")
        return None

    current_time = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    file_name = f"responses/{uuid}/{current_time}.json"

    try:
        s3_client.put_object(
            Body=response,
            Bucket=bucket_name,
            Key=file_name,
            ContentType='application/json'
        )
        return file_name
    except Exception as e:
        logger.error(f"Failed to upload file to S3: {str(e)}")
        return None


async def get_connection_id(uuid):
    """
    Get the connection ID from the DynamoDB table.

    Args:
        uuid (str): The unique identifier for the user.

    Returns:
        str: The connection ID or None if not found.
    """
    table = dynamodb.Table("websocket_finder")

    try:
        response = table.get_item(Key={'uuid': uuid})
        connection_id = response.get("Item", {}).get("connectionId")
        if not connection_id:
            logger.error(f"Connection ID not found for UUID: {uuid}")
            return None
        return connection_id
    except Exception as e:
        logger.error(f"Failed to retrieve item from DynamoDB: {str(e)}")
        return None


async def send_data_to_arduino(connection_id, response):
    """
    Send the response data to arduino with the connection id.

    Args:
        connection_id: connection id of the target arduino's web socket.
        response: response data to be sent to the arduino.

    Returns:
        api_response: response from the api gateway.

    Raises:
        Exception: If sending data fails
    """
    websocket_url = os.environ.get('WEBSOCKET_URL')
    if not websocket_url:
        raise ValueError("WEBSOCKET_URL environment variable not set")

    if not connection_id:
        raise ValueError("Connection ID cannot be empty")

    try:
        apigateway_client = boto_session.client(
            'apigatewaymanagementapi', endpoint_url=websocket_url)
        api_response = apigateway_client.post_to_connection(
            ConnectionId=connection_id,
            Data=response.encode('utf-8')
        )
        return api_response
    except Exception as e:
        logger.error(f"Failed to send data to Arduino: {str(e)}")
        raise


async def main(event, context):
    """
    Main handler function that processes the event and returns a response.

    Args:
        event (dict): The event dict from Lambda trigger
        context (object): Lambda context object

    Returns:
        dict: API Gateway compatible response with statusCode and body
    """
    # Validate required environment variables
    required_vars = ['BUCKET_NAME', 'WEBSOCKET_URL', 'GOOGLE_GEMINI_API_KEY']
    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    if missing_vars:
        logger.error(
            f"Missing required environment variables: {', '.join(missing_vars)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Missing required environment variables: {', '.join(missing_vars)}")
        }

    # Validate required parameters
    required_params = {'uuid', 'pin', 'file'}
    if not isinstance(event, dict):
        logger.error("Event is not a dictionary")
        return {
            'statusCode': 400,
            'body': json.dumps("Invalid event format")
        }

    missing_params = required_params - set(event.keys())
    if missing_params:
        logger.error(
            f"Missing required parameters: {', '.join(missing_params)}")
        return {
            'statusCode': 400,
            'body': json.dumps(f"Missing required parameters: {', '.join(missing_params)}")
        }

    uuid = event['uuid']
    pin = event['pin']

    # Validate UUID and PIN
    if not uuid or not isinstance(uuid, str):
        return {
            'statusCode': 400,
            'body': json.dumps("Invalid UUID format")
        }

    if not pin or not isinstance(pin, str):
        return {
            'statusCode': 400,
            'body': json.dumps("Invalid PIN format")
        }

    # Decode file
    try:
        file = base64.b64decode(event['file'])
    except Exception as e:
        logger.error(f"Failed to decode base64 file: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps("Invalid file encoding")
        }

    wav_file = None
    # Store the audio file
    try:
        wav_file = store_wav_file(uuid, file)
    except IOError as e:
        logger.error(f"Failed to store audio file: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Failed to store audio file: {str(e)}")
        }

    # Authenticate the user
    try:
        auth_user(uuid, pin)
    except AuthenticationError as e:
        return {
            'statusCode': 401,
            'body': json.dumps(str(e))
        }

    # Get the response from the Gemini AI model
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
        if retry < 3 and parsed_json is None:
            # Wait a bit before retrying
            await asyncio.sleep(0.5)

    # Clean up temp file
    if wav_file and os.path.exists(wav_file):
        try:
            os.remove(wav_file)
        except Exception as e:
            logger.warning(f"Failed to delete temp file: {str(e)}")

    if not parsed_json:
        return {
            'statusCode': 400,
            'body': json.dumps("AI failed to create an appropriate response")
        }

    try:
        # Set timeout for all tasks to avoid Lambda timeout
        timeout = 5  # seconds

        # Create tasks
        tasks = [
            asyncio.create_task(configure_light_settings(parsed_json)),
            asyncio.create_task(get_connection_id(uuid)),
        ]

        # Only upload to S3 if we have a response
        if gemini_response and hasattr(gemini_response, 'text'):
            tasks.append(asyncio.create_task(
                upload_response_s3(gemini_response.text, uuid)))
        else:
            # Add a dummy task
            tasks.append(asyncio.create_task(asyncio.sleep(0)))

        # Execute with timeout
        done, pending = await asyncio.wait(tasks, timeout=timeout, return_when=asyncio.ALL_COMPLETED)

        # Cancel any pending tasks
        for task in pending:
            task.cancel()

        # Check if all tasks completed
        if len(done) != len(tasks):
            raise TimeoutError("Some tasks didn't complete in time")

        # Get results, handling exceptions
        arduino_response = tasks[0].result()
        connection_id = tasks[1].result()

        # Validate connection_id and send data
        if connection_id:
            await send_data_to_arduino(connection_id, arduino_response)
        else:
            logger.error("No connection ID found for the device")
            return {
                'statusCode': 404,
                'body': json.dumps("Device not connected")
            }

    except TimeoutError as e:
        logger.error(f"Operation timed out: {str(e)}")
        return {
            'statusCode': 504,  # Gateway Timeout
            'body': json.dumps("Operation timed out")
        }
    except Exception as e:
        logger.error(f"Error in processing: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Processing error: {str(e)}")
        }

    # Return the recommendation to the user
    logger.info(f"Successfully processed request for UUID: {uuid}")
    return {
        'statusCode': 200,
        'body': parsed_json["recommendation"]
    }


def lambda_handler(event, context):
    """
    Lambda handler function that calls the async main function.

    Args:
        event (dict): The event dict from Lambda trigger
        context (object): Lambda context object

    Returns:
        dict: API Gateway compatible response with statusCode and body
    """
    return asyncio.run(main(event, context))
