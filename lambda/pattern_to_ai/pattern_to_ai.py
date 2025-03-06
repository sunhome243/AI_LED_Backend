import json
import os
import logging
import shortuuid
from datetime import datetime, timedelta
from boto3.session import Session
from boto3.dynamodb.conditions import Key
import google.generativeai as genai
from gemini_config import get_gemini_config_surprise_me
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

request_id = shortuuid.uuid()

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
    table = dynamodb.Table("AuthTable")

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


def get_past_reponse(uuid):

    current_time = datetime.now()
    one_hour = timedelta(hours=1)
    future_time = current_time + one_hour
    future_time = future_time.strftime("%H:%M")
    past_time = current_time - one_hour
    past_time = past_time.strftime("%H:%M")
    day = datetime.today().weekday()

    response = dynamodb.query(
        TableName='ResponseTable',
        KeyConditionExpression=Key('uuid').eq(uuid) & Key(
            'DAY#TIME').between(past_time, future_time),
        ExpressionAttributeValues={
            ":uuid": {"S": uuid},
            ":day": {"S": f"DAY#{day}"},
            ":past_time": {"S": past_time},
            ":future_time": {"S": future_time}
        },
        Limit=20
    )

    return response


def get_genai_response(past_response):
    """
    Generate a response using the Gemini AI model based on the uploaded file.

    Args:
        past_response: The past response of the user.

    Returns:
        dict: The response from the Gemini AI model.

    Raises:
        AIProcessingError: If Gemini AI processing fails
    """
    try:

        generate_content_config = get_gemini_config_surprise_me()

        model = "gemini-2.0-flash"
        response = client.models.generate_content(
            model,
            contents=[
                past_response
            ],
            config=generate_content_config,
        )

        return response

    except Exception as e:
        logger.error(f"Error in Gemini AI processing: {str(e)}")
        raise AIProcessingError(f"Gemini AI processing failed: {str(e)}")


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


def lambda_handler(event, context):
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
    required_params = {'uuid', 'pin'}
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

    # Authenticate the user
    try:
        auth_user(uuid, pin)
    except AuthenticationError as e:
        return {
            'statusCode': 401,
            'body': json.dumps(str(e))
        }

    try:
        # Get the past response of the user
        past_response = get_past_reponse(uuid)
    except:
        return {
            'statusCode': 404,
            'body': json.dumps("No past response found")
        }

    # Get the response from the Gemini AI model
    retry = 0
    parsed_json = None
    gemini_response = None

    # Retry up to 3 times to get a valid response
    while retry < 3 and parsed_json is None:
        try:
            gemini_response = get_genai_response(past_response)
            parsed_json = verify_and_parse_json(gemini_response)
            if parsed_json is None:
                logger.warning(
                    f"Attempt {retry+1}/3: Invalid response from Gemini AI")
        except AIProcessingError as e:
            logger.error(f"Attempt {retry+1}/3: {str(e)}")

        retry += 1

    if not parsed_json:
        return {
            'statusCode': 400,
            'body': json.dumps("AI failed to create an appropriate response")
        }

    parsed_json["request_id"] = request_id
    parsed_json["uuid"] = uuid
    parsed_json["timestamp"] = datetime.now().isoformat()

    client.invoke(
        FunctionName='result-save-send',
        InvocationType='Event',  # for async invocation
        Payload=json.dumps(parsed_json)
    )

    # Return the recommendation to the user
    logger.info(f"Successfully processed request for UUID: {uuid}")
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': "application/json"
        },
        'body': [parsed_json["recommendation"], request_id]
    }