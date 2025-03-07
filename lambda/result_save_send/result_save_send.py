import json
import os
import logging
import asyncio
from datetime import datetime
from boto3.session import Session
from constants import DYNAMIC_MODES, IR_CODE_MAP, DEFAULT_IR_RESULT


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
    table = dynamodb.Table("IrCodeTable")
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


async def upload_response_s3(response, uuid, request_id):
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

    file_name = f"responses/{uuid}/{request_id}.json"

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


async def upload_response_dynamo(response, uuid, request_id):
    """
    Upload the AI response data to DynamoDB for persistent storage and future analysis.

    Args:
        response (dict): The parsed JSON response containing emotion and light settings
        uuid (str): The unique identifier of the user/device
        request_id (str): The unique identifier for this specific request

    Returns:
        None

    Raises:
        Exception: If DynamoDB operations fail
    """
    # Get current date and time information for indexing
    today = datetime.now().date()
    day_of_week = today.weekday()
    time = datetime.now().time()

    # Extract data needed for storage
    emotion_tag = response["emotion"]["main"]
    uuid_key = f'uuid#{uuid}'  # Format UUID as partition key
    # Create sort key for querying by day/time
    day_time_key = f'DAY#{day_of_week}#TIME#{time}'
    light_settings = response["lightSetting"]
    context = response["context"]

    # Store the data in DynamoDB
    dynamodb.Table('ResponseTable').put_item(
        Item={
            'uuid': {'S': uuid_key},
            'requestId': {'S': request_id},
            'DAY#TIME': {'S': day_time_key},
            'emotionTag': {'S': emotion_tag},
            'lightSetting': {'M': light_settings},
            'context': {'S': context}
        }
    )


async def get_connection_id(uuid):
    """
    Get the connection ID from the DynamoDB table.

    Args:
        uuid (str): The unique identifier for the user.

    Returns:
        str: The connection ID or None if not found.
    """
    table = dynamodb.Table("ConnectionIdTable")

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
    Main async function that orchestrates the response processing workflow.

    Performs several concurrent operations:
    1. Configures light settings based on AI response
    2. Retrieves the WebSocket connection ID for the target device
    3. Uploads the response to S3 for storage
    4. Saves the response metadata to DynamoDB

    Args:
        event (dict): Lambda event data containing UUID, request ID and AI response
        context (object): Lambda context object

    Returns:
        None: The function performs side effects but doesn't return data

    Raises:
        TimeoutError: If the operations take too long
        Exception: For other processing errors
    """
    # Extract identifiers from the event
    uuid = event.get("uuid")
    request_id = event.get("requestId")

    if not uuid or not request_id:
        logger.error("Missing required fields: uuid or requestId")
        return

    try:
        # Set timeout for all tasks to avoid Lambda timeout
        timeout = 5  # seconds

        # Create tasks for concurrent execution
        tasks = [
            asyncio.create_task(configure_light_settings(event)),
            asyncio.create_task(get_connection_id(uuid)),
        ]

        # Only upload to S3 and DynamoDB if we have a complete response
        if event:
            event_text = json.dumps(event)
            tasks.append(asyncio.create_task(
                upload_response_s3(event_text, uuid, request_id)))
            tasks.append(asyncio.create_task(
                upload_response_dynamo(event, uuid, request_id)))
        else:
            # Add dummy tasks to maintain task indices
            tasks.append(asyncio.create_task(asyncio.sleep(0)))
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

    except TimeoutError as e:
        logger.error(f"Operation timed out: {str(e)}")

    except Exception as e:
        logger.error(f"Error in processing: {str(e)}")
        # Consider adding more specific exception handling

    logger.info("Successfully sent data to Arduino and saved response")

    return None


def lambda_handler(event, context):
    """
    Lambda handler function that processes incoming events from API Gateway
    and orchestrates the response processing workflow.

    This function:
    1. Receives the AI response data
    2. Configures light settings based on the response
    3. Retrieves the connection ID for the target device
    4. Saves the response to S3 and DynamoDB
    5. Sends the configuration to the connected Arduino device

    Args:
        event (dict): The event dict from Lambda trigger containing:
                        - uuid: Unique identifier for the user/device
                        - requestId: Unique identifier for this request
                        - lightSetting: Light configuration parameters. Contains:
                            - color: RGB color values
                            - power: Power state (on/off)
                            - dynamicMode: Dynamic mode setting
                        - emotion: Map of detected emotions from the AI. Contains:
                            - main: Main emotion detected
                            - subcategories: List of subcategories
                        - recommendation: Textual explanation of the lighting choice
                        - context: Additional contextual information
        context (object): Lambda context object

    Returns:
        dict: API Gateway compatible response with statusCode and body

    Environment Variables:
        REGION_NAME: AWS region (default: 'us-east-1')
        BUCKET_NAME: S3 bucket for storing responses
        WEBSOCKET_URL: API Gateway WebSocket endpoint URL
    """
    # Create an event loop
    loop = asyncio.get_event_loop()
    return loop.run_until_complete(main(event, context))
