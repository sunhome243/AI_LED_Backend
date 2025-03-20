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
    Configure light settings based on the AI response.

    Args:
        json_response: Parsed JSON response with light settings

    Returns:
        JSON string with light configuration and IR codes
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
    elif "color" in light_setting:
        # Get RGB values from the response
        result["rgbCode"] = light_setting.get("color", [0, 0, 0])
        # Get IR codes for controlling RGB light
        ir_codes = get_ir_code(device_type)
    elif "dynamic" in light_setting:
        # Set rgbCode to default for dynamic mode
        result["rgbCode"] = [0, 0, 0]
        # Get dynamic mode from lightSetting
        dynamic_mode = light_setting.get("dynamic")
        # Log the dynamic mode being used
        logger.info(f"Using dynamic mode: {dynamic_mode}")
        # Get IR codes for dynamic mode
        ir_codes = get_dynamic_mode(dynamic_mode, device_type)
    else:
        # Default case - use standard IR codes
        result["rgbCode"] = [0, 0, 0]
        ir_codes = get_ir_code(device_type)

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
    Retrieve IR codes from DynamoDB.

    Args:
        device_type: Type of device to control
        ir_id: ID of the IR code

    Returns:
        IR code or None if not found
    """
    table = dynamodb.Table("IrCodeTable")
    try:
        # Ensure ir_id is int for DynamoDB consistency
        ir_id_int = int(ir_id)

        response = table.get_item(
            Key={
                'deviceType': device_type,
                'id': ir_id_int
            }
        )
        if 'Item' in response and 'ir_code' in response['Item']:
            return response['Item']['ir_code']
        else:
            logger.warning(
                f"IR code not found for device_type: {device_type}, ir_id: {ir_id_int}")
    except ValueError:
        logger.error(f"Invalid IR ID format: {ir_id}, expected an integer")
    except Exception as e:
        logger.error(f"Failed to retrieve item from DynamoDB: {str(e)}")
    return None


def get_ir_code(device_type):
    """
    Get IR codes for RGB control.

    Args:
        device_type: Type of device

    Returns:
        Dictionary of IR codes for RGB controls
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
    Get IR code for dynamic mode.

    Args:
        dynamic_mode: Dynamic mode name
        device_type: Type of device

    Returns:
        Dictionary with IR codes for dynamic mode
    """
    # Initialize result with default values
    result = DEFAULT_IR_RESULT.copy()

    try:
        # Check if dynamic_mode is None or empty
        if not dynamic_mode:
            logger.warning(
                f"No dynamic mode specified, using default settings")
            return result

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
    Upload JSON response to S3 bucket.

    Args:
        response: JSON response string
        uuid: User identifier
        request_id: Request identifier

    Returns:
        S3 key of uploaded file or None if failed
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
    Upload AI response to DynamoDB.

    Args:
        response: Parsed JSON with emotion and light settings
        uuid: User/device identifier
        request_id: Request identifier

    Returns:
        None
    """
    # Use client-provided timestamp if available
    day_of_week = None
    formatted_time = None

    if "timestamp" in response and isinstance(response["timestamp"], dict):
        try:
            # Parse the client timestamp in the format {time: "HH:MM:SS", dayOfWeek: "0"}
            time_str = response["timestamp"].get("time")
            day_of_week_str = response["timestamp"].get("dayOfWeek")

            if time_str and day_of_week_str is not None:
                day_of_week = int(day_of_week_str)
                formatted_time = time_str

                # Convert day from Sunday=0 format to Monday=0 format if needed for DB consistency
                if day_of_week == 0:  # Sunday in frontend
                    day_of_week = 6   # Sunday in DB (Monday=0, Sunday=6)
                else:
                    day_of_week = day_of_week - 1  # Other days adjustment

                logger.info(
                    f"Using client timestamp: time={formatted_time}, dayOfWeek={day_of_week}")
        except (ValueError, TypeError, AttributeError) as e:
            logger.warning(f"Error parsing client timestamp: {e}")
            day_of_week = None

    # Fallback to server time if client timestamp is invalid or not provided
    if day_of_week is None or formatted_time is None:
        today = datetime.now().date()
        day_of_week = today.weekday()  # 0 is Monday, 6 is Sunday
        formatted_time = datetime.now().time().strftime("%H:%M:%S")
        logger.info(
            f"Using server timestamp: time={formatted_time}, dayOfWeek={day_of_week}")

    # Extract data needed for storage
    emotion_tag = response["emotion"]["main"]
    uuid_key = f'uuid#{uuid}'  # Format UUID as partition key

    # Create sort key for querying by time/day
    day_time_key = f'TIME#{formatted_time}#DAY#{day_of_week}'
    light_settings = response["lightSetting"]
    context = response["context"]

    try:
        # Store the data in DynamoDB - fix the item format
        # When using boto3 resource interface (Table), we don't need type annotations
        dynamodb.Table('ResponseTable').put_item(
            Item={
                'uuid': uuid_key,
                'requestId': request_id,
                'TIME#DAY': day_time_key,
                'emotionTag': emotion_tag,
                'lightSetting': light_settings,
                'context': context
            }
        )
        logger.info(
            f"Successfully stored response in DynamoDB for UUID: {uuid}")
    except Exception as e:
        logger.error(f"Failed to store response in DynamoDB: {str(e)}")
        raise


async def get_connection_id(uuid):
    """
    Get WebSocket connection ID from DynamoDB.

    Args:
        uuid: User identifier

    Returns:
        Connection ID or None if not found
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
    Send response data to Arduino via WebSocket.

    Args:
        connection_id: WebSocket connection ID
        response: Response data

    Returns:
        API Gateway response

    Raises:
        ValueError: If required params missing
        Exception: If sending fails
    """
    websocket_url = os.environ.get('WEBSOCKET_URL')
    if not websocket_url:
        raise ValueError("WEBSOCKET_URL environment variable not set")

    if not connection_id:
        raise ValueError("Connection ID cannot be empty")

    try:
        # Log the response being sent to Arduino
        logger.info(f"Sending response to Arduino: {response}")

        # Fix WebSocket URL format for the API Gateway client
        # Extract the domain part without the stage
        if websocket_url.startswith('wss://'):
            # Remove wss:// and any path including stage
            domain = websocket_url[6:].split('/', 1)[0]
            endpoint_url = f'https://{domain}/develop'
        elif websocket_url.startswith('https://'):
            # Remove https:// and any path including stage
            domain = websocket_url[8:].split('/', 1)[0]
            endpoint_url = f'https://{domain}/develop'
        else:
            # Just extract the domain without any path/stage
            domain = websocket_url.split('/', 1)[0]
            endpoint_url = f'https://{domain}/develop'

        logger.info(f"Using endpoint URL: {endpoint_url}")
        apigateway_client = boto_session.client(
            'apigatewaymanagementapi', endpoint_url=endpoint_url)
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
    Orchestrate response processing workflow.

    Configures light settings, retrieves connection ID,
    stores response, and sends to device.

    Args:
        event: Lambda event with UUID, request ID and AI response
        context: Lambda context

    Returns:
        None
    """
    # Extract identifiers from the event
    uuid = event.get("uuid")
    request_id = event.get("request_id") or event.get(
        "requestId")  # Check both formats

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
            try:
                upload_s3_task = asyncio.create_task(
                    upload_response_s3(event_text, uuid, request_id))
                upload_dynamo_task = asyncio.create_task(
                    upload_response_dynamo(event, uuid, request_id))
                tasks.append(upload_s3_task)
                tasks.append(upload_dynamo_task)
            except Exception as e:
                logger.error(f"Error setting up storage tasks: {str(e)}")
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
            try:
                await send_data_to_arduino(connection_id, arduino_response)
                logger.info(
                    "Successfully sent data to Arduino and saved response")
            except Exception as e:
                logger.error(f"Failed to send data to Arduino: {str(e)}")
        else:
            logger.error("No connection ID found for the device")

    except TimeoutError as e:
        logger.error(f"Operation timed out: {str(e)}")

    except Exception as e:
        logger.error(f"Error in processing: {str(e)}")
        # Consider adding more specific exception handling

    return None


def lambda_handler(event, context):
    """
    Process incoming events and orchestrate response workflow.

    Parses event, runs async workflow, and returns API response.

    Args:
        event: Lambda event with response data
        context: Lambda context

    Returns:
        API Gateway response
    """
    # Process the event if it's coming from API Gateway
    if 'body' in event:
        try:
            # If body is a JSON string, parse it
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
            # Update event with the body content
            event = body
        except json.JSONDecodeError:
            logger.error("Failed to parse event body as JSON")
            return {
                'statusCode': 400,
                'body': json.dumps("Invalid request body format")
            }

    # Create an event loop
    loop = asyncio.get_event_loop()
    result = loop.run_until_complete(main(event, context))

    # Return a formatted response for API Gateway
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': "application/json",
        },
        'body': json.dumps({
            "message": "Processing complete",
            "uuid": event.get("uuid", "unknown"),
            "request_id": event.get("request_id") or event.get("requestId", "unknown")
        })
    }
