import json
import os
import logging
import shortuuid
from datetime import datetime, timedelta
from boto3.session import Session
from boto3.dynamodb.conditions import Key
from google import genai
from google.genai import types
from get_gemini_config_surprise_me import get_gemini_config
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

# CORS headers to include in all responses
CORS_HEADERS = {
    'Content-Type': "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS, POST, GET",
    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
}

# Gemini API initialization
google_gemini_api_key = os.environ.get('GOOGLE_GEMINI_API_KEY')
if not google_gemini_api_key:
    raise EnvironmentError(
        "GOOGLE_GEMINI_API_KEY environment variable is not set")
client = genai.Client(api_key=google_gemini_api_key)


def auth_user(uuid, pin):
    """
    Authenticate user by comparing provided pin with stored pin in DynamoDB.

    Args:
        uuid: User unique identifier
        pin: User pin

    Raises:
        AuthenticationError: If authentication fails

    Returns:
        True if authentication successful
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


def get_past_reponse(uuid, timestamp=None):
    """
    Retrieves past responses for a user within a 2-hour window.

    Args:
        uuid: User unique identifier
        timestamp: Client-provided timestamp dictionary (optional)

    Returns:
        List of user response items within the timeframe

    Raises:
        Exception: If the DynamoDB query fails
    """
    # Use client-provided timestamp or fallback to server time
    current_time_str = None
    day = None

    if timestamp and isinstance(timestamp, dict) and 'time' in timestamp and 'dayOfWeek' in timestamp:
        try:
            current_time_str = timestamp['time']
            day = int(timestamp['dayOfWeek'])
            # Convert day from Sunday=0 format to Monday=0 format if needed
            # If frontend uses Sunday=0, we need to adjust for DB which uses Monday=0
            if day == 0:  # Sunday in frontend
                day = 6   # Sunday in DB (Monday=0, Sunday=6)
            else:
                day = day - 1  # Other days adjustment

            logger.info(
                f"Using client timestamp: time={current_time_str}, dayOfWeek={day}")
        except (ValueError, TypeError) as e:
            logger.warning(f"Error parsing client timestamp: {e}")
            current_time_str = None

    # Fallback to server time if client time is invalid or not provided
    if current_time_str is None or day is None:
        current_time = datetime.now()
        current_time_str = current_time.strftime("%H:%M:%S")
        day = current_time.weekday()  # 0 is Monday, 6 is Sunday
        logger.info(
            f"Using server timestamp: time={current_time_str}, day={day}")

    # Calculate time window boundaries (±1 hour from provided time)
    time_parts = current_time_str.split(":")
    hour = int(time_parts[0])

    past_hour = (hour - 1) % 24
    future_hour = (hour + 1) % 24

    past_time_str = f"{past_hour:02d}:{time_parts[1]}:{time_parts[2]}"
    future_time_str = f"{future_hour:02d}:{time_parts[1]}:{time_parts[2]}"

    # Create the sort key prefixes for the time range
    start_sort_key = f"TIME#{past_time_str}#DAY#{day}"
    end_sort_key = f"TIME#{future_time_str}#DAY#{day}"

    # Log the time window and sort keys for debugging
    logger.info(
        f"Querying for responses with sort keys between {start_sort_key} and {end_sort_key}")

    # Format UUID with prefix to match how it's stored in the database
    uuid_key = f'uuid#{uuid}'

    # Get the DynamoDB table reference
    table = dynamodb.Table('ResponseTable')

    try:
        # Query DynamoDB with the correct sort key attribute name (not 'sort_key')
        response = table.query(
            KeyConditionExpression=Key('uuid').eq(uuid_key) &
            Key('TIME#DAY').between(start_sort_key, end_sort_key),
            ScanIndexForward=False,  # Get most recent first
            Limit=20  # Limit to 20 most recent responses
        )

        items = response.get('Items', [])
        logger.info(
            f"Retrieved {len(items)} past responses for user {uuid_key}")

        return items
    except Exception as e:
        logger.error(f"Error querying DynamoDB: {str(e)}")
        raise


def get_genai_response(past_response, timestamp=None):
    """
    Generate a response using Gemini AI based on past user responses.

    Args:
        past_response: Past user responses from DynamoDB
        timestamp: Client-provided timestamp dictionary (optional)

    Returns:
        The response from Gemini AI model

    Raises:
        AIProcessingError: If AI processing fails
    """
    try:
        # Create the instruction text that would normally be in the system role
        instruction_text = """Adaptive Personalized Lighting Assistant

You are an AI that predicts and personalizes lighting based on broad time patterns, emotional state, and user context. Instead of matching exact timestamps, you analyze general trends to infer the most likely current activity. The AI must select either RGB color or Dynamic mode—never both.

Core Functions
	•	Pattern Recognition: Retrieve and analyze past records (weekday, time range, emotion, context, RGB code, user feedback) to identify trends, not exact timestamps.
	•	Context-Aware Prediction: If multiple past activities exist within a time range, choose the most frequent or contextually relevant one, rather than the latest.
	•	Lighting Optimization: Adjust brightness and color dynamically based on historical patterns and current context.
	•	Strict Output Rule: Only one lighting mode is allowed—either RGB color or Dynamic mode, never both.

Output Schema

User Activity (activity)
	•	main: General category (e.g., "study", "reading", "movie").
	•	sub: Specific details ("math", "comic book", "horror movie").

Light Settings (lightSetting)
	•	Choose ONE of the following:
	•	RGB Color: [R, G, B] based on prior preferences and environmental factors.
	•	Dynamic Mode: "FADE3", "MUSIC2", etc. (Only if the activity requires it, e.g., music, party, gaming.)
	•	Brightness Scaling: Adjust brightness based on time, activity, and previous feedback.
	•	Power: true (on) or false (off).

Emotional Analysis (emotion)
	•	main: "Positive", "Negative", "Neutral"
	•	sub: Top 3 detected emotions.

Recommendation (recommendation)
	•	Explain why this lighting choice was made.
	•	Example: "Since you usually study between 12 PM - 3 PM on Mondays, bright white light is set for focus. Stay productive! ✨"

Context (context)
	•	Concise description (e.g., "Monday afternoon study session, feeling focused.").

Guidelines

Generalized Time Analysis
	•	Instead of exact timestamps, analyze a time block (e.g., 14:00 - 15:00).
	•	If multiple activities exist, prioritize the most frequent or logical choice.
	•	If no clear pattern emerges, default to the most contextually fitting option.

Strict Lighting Mode Selection
	•	RGB Color Mode → For studying, reading, movies, relaxing.
	•	Dynamic Mode → For music, parties, gaming (only if needed).
	•	Never use both RGB and Dynamic Mode together.

Conflict Resolution
	•	If some pattern occurs often, but some patterns are rare, choose the dominant pattern (study/reading) even if the latest entry was a horror movie.

Fallback Defaults
	•	If no strong pattern is detected, infer activity using general time-of-day behavior.

Example Correct Output (Fixing the Issue)

Past Data Analysis (14:00 - 15:00 on Mondays)
	•	Study @ 14:00 (Bright White)
	•	Reading a book @ 14:20 (Bright White)
	•	Reading a comic book @ 14:20 (Slightly Warm White)
	•	Watching a horror movie @ 14:43 (Dim Red)

Current Time: Monday, 14:30

✅ Study and reading are more frequent than horror movies.
✅ The AI selects only RGB mode (no Dynamic Mode).

{
  "context": "It's Monday afternoon, and you're likely studying or reading.",
  "emotion": {
    "main": "Neutral",
    "subcategories": [
      "Focused",
      "Calm",
      "Engaged"
    ]
  },
  "lightSetting": {
    "power": true,
    "color": [
      "255",
      "255",
      "250"
    ]
  },
  "recommendation": "Since you often study or read around this time on Mondays, a bright white light is set to help you focus. Keep up the good work! 📚✨"
}
}"""

        # Create a comprehensive prompt that includes both the instructions and user request
        # Use client-provided timestamp or fallback to server time
        if timestamp and isinstance(timestamp, dict) and 'time' in timestamp and 'dayOfWeek' in timestamp:
            try:
                time_str = timestamp['time']
                day_num = int(timestamp['dayOfWeek'])

                # Map day number to name
                days = ["Sunday", "Monday", "Tuesday",
                        "Wednesday", "Thursday", "Friday", "Saturday"]
                day_name = days[day_num]

                current_time_str = f"{day_name}, {time_str}"
                logger.info(
                    f"Using client timestamp in prompt: {current_time_str}")
            except (ValueError, TypeError, IndexError) as e:
                logger.warning(f"Error formatting client timestamp: {e}")
                current_time = datetime.now()
                current_time_str = current_time.strftime("%Y-%m-%d %H:%M:%S")
        else:
            current_time = datetime.now()
            current_time_str = current_time.strftime("%Y-%m-%d %H:%M:%S")
            logger.info(
                f"Using server timestamp in prompt: {current_time_str}")

        if not past_response:
            user_prompt = f"Generate a lighting recommendation for a new user. Current time: {current_time_str}"
        else:
            user_prompt = f"Based on these past responses: {json.dumps(past_response)}, generate a lighting recommendation. Current time: {current_time_str}"

        # Combine the instruction and user prompt
        combined_prompt = f"{instruction_text}\n\nUser Request: {user_prompt}"

        # Log the request being sent to the AI
        logger.info(f"Sending request to Gemini AI: {user_prompt}")

        # Create contents with just the combined text
        contents = [
            genai.types.Content(
                role="user",
                parts=[
                    genai.types.Part.from_text(text=combined_prompt),
                ],
            ),
        ]

        # Set up response schema
        response_schema = genai.types.Schema(
            type=genai.types.Type.OBJECT,
            required=["lightSetting", "emotion", "recommendation", "context"],
            properties={
                "lightSetting": genai.types.Schema(
                    type=genai.types.Type.OBJECT,
                    required=["power"],
                    properties={
                        "color": genai.types.Schema(
                            type=genai.types.Type.ARRAY,
                            items=genai.types.Schema(
                                type=genai.types.Type.STRING,
                            ),
                        ),
                        "power": genai.types.Schema(
                            type=genai.types.Type.BOOLEAN,
                        ),
                        "dynamic": genai.types.Schema(
                            type=genai.types.Type.STRING,
                            enum=VALID_DYNAMIC_MODES,
                        ),
                    },
                ),
                "emotion": genai.types.Schema(
                    type=genai.types.Type.OBJECT,
                    description="Emotion analysis result",
                    required=["main", "subcategories"],
                    properties={
                        "main": genai.types.Schema(
                            type=genai.types.Type.STRING,
                            enum=["Positive", "Negative", "Neutral"],
                        ),
                        "subcategories": genai.types.Schema(
                            type=genai.types.Type.ARRAY,
                            items=genai.types.Schema(
                                type=genai.types.Type.STRING,
                                enum=["Happy", "Excited", "Thankful", "Proud", "Relaxed",
                                      "Satisfied", "Peaceful", "Relieved", "Surprised (Good)",
                                      "Energetic", "Motivated", "Loved", "Hopeful", "Disappointed",
                                      "Sad", "Lonely", "Regretful", "Frustrated", "Annoyed",
                                      "Angry", "Hurt", "Anxious", "Scared", "Worried",
                                      "Doubtful", "Helpless", "Disgusted", "Uncomfortable",
                                      "Shocked (Bad)", "Conflicted", "Indifferent", "Practical",
                                      "Logical", "Clear-headed", "Balanced", "Neutral"],
                            ),
                        ),
                    },
                ),
                "recommendation": genai.types.Schema(
                    type=genai.types.Type.STRING,
                ),
                "context": genai.types.Schema(
                    type=genai.types.Type.STRING,
                ),
            },
        )

        # Create a configuration with all necessary parameters
        generate_content_config = genai.types.GenerateContentConfig(
            temperature=0.85,
            top_p=0.95,
            top_k=40,
            max_output_tokens=8192,
            response_mime_type="application/json",
            response_schema=response_schema,
        )

        # Add safety settings separately
        safety_settings = [
            genai.types.SafetySetting(
                category="HARM_CATEGORY_HARASSMENT",
                threshold="BLOCK_NONE",
            ),
            genai.types.SafetySetting(
                category="HARM_CATEGORY_HATE_SPEECH",
                threshold="BLOCK_NONE",
            ),
            genai.types.SafetySetting(
                category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
                threshold="BLOCK_NONE",
            ),
            genai.types.SafetySetting(
                category="HARM_CATEGORY_DANGEROUS_CONTENT",
                threshold="BLOCK_NONE",
            ),
            genai.types.SafetySetting(
                category="HARM_CATEGORY_CIVIC_INTEGRITY",
                threshold="BLOCK_NONE",
            ),
        ]

        # Call the API with the correct format based on sample code
        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=contents,
            config=generate_content_config,
        )

        # Log the Gemini AI response
        logger.info(f"Gemini AI response: {response.text}")

        return response

    except Exception as e:
        logger.error(f"Error in Gemini AI processing: {str(e)}")
        raise AIProcessingError(f"Gemini AI processing failed: {str(e)}")


def verify_and_parse_json(response):
    """
    Verify and validate JSON response from AI.

    Args:
        response: Response object from Gemini API

    Returns:
        Parsed JSON if valid, None otherwise
    """
    logger.info(f"Verifying response from Gemini AI: {response.text}")

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
    # Check both 'dynamic' and 'dynamicMode' fields
    dynamic_mode = light_setting.get("dynamic")
    power = light_setting.get("power")

    # Validate light configuration based on power state and mode
    if color is None and dynamic_mode is None:
        if power is False:  # if power is off, no need to check color and dynamic mode
            pass
        else:
            logger.error(
                "Failed. Error in light mode: neither color nor dynamic mode specified when power is on")
            return None
    else:
        # Validate dynamic mode option if color is not specified
        if color is None:
            if dynamic_mode not in VALID_DYNAMIC_MODES:
                logger.error(f"Failed. Error in dynamic mode: {dynamic_mode}")
                return None
        # Validate RGB color format if dynamic mode is not specified
        if dynamic_mode is None and color is not None:
            # Check if color is a list of strings or integers
            if not isinstance(color, list) or len(color) != 3:
                logger.error(f"Failed. Error in color code format: {color}")
                return None

            # Convert strings to integers if needed
            try:
                color_values = [int(c) if isinstance(
                    c, str) else c for c in color]
                if not all(isinstance(code, int) and 0 <= code < 256 for code in color_values):
                    logger.error(
                        f"Failed. Error in color code values: {color}")
                    return None
                # Update color with integer values
                light_setting["color"] = color_values
            except ValueError:
                logger.error(f"Failed. Error converting color values: {color}")
                return None

    # Standardize dynamic field name to 'dynamic' if it exists as 'dynamicMode'
    if light_setting.get("dynamicMode") and not light_setting.get("dynamic"):
        light_setting["dynamic"] = light_setting.pop("dynamicMode")

    return json_response


def lambda_handler(event, context):
    """
    Process "surprise me" lighting requests based on user patterns.

    Authenticates user, retrieves context, generates AI recommendation,
    and returns personalized lighting configuration.

    Args:
        event: Lambda event with user identification and request details
        context: Lambda context

    Returns:
        API Gateway response with status code, headers and body
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

    # Extract the payload from the API Gateway event
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
        except json.JSONDecodeError:
            logger.error("Failed to parse event body as JSON")
            return {
                'statusCode': 400,
                'headers': CORS_HEADERS,
                'body': json.dumps("Invalid request body format")
            }

    # Handle API Gateway proxy integration where parameters might be in various places
    if 'requestContext' in event and 'pathParameters' in event and event['pathParameters']:
        # Extract parameters from the path if available
        params = event['pathParameters']
        if 'uuid' in params and 'pin' in params:
            uuid = params['uuid']
            pin = params['pin']
            event['uuid'] = uuid
            event['pin'] = pin

    # Validate required parameters
    required_params = {'uuid', 'pin'}
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

    # Extract user credentials and timestamp
    uuid = event['uuid']
    pin = event['pin']
    timestamp = event.get('timestamp')

    # Log client timestamp if available
    if timestamp:
        logger.info(f"Client timestamp received: {timestamp}")

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

    # Authenticate the user
    try:
        auth_user(uuid, pin)
    except AuthenticationError as e:
        return {
            'statusCode': 401,
            'headers': CORS_HEADERS,
            'body': json.dumps(str(e))
        }

    # Retrieve past responses for context with client timestamp
    try:
        # Get the past response of the user with timestamp
        past_response = get_past_reponse(uuid, timestamp)
        # Continue even if past_response is an empty list
        logger.info(
            f"Found {len(past_response)} past responses for UUID: {uuid}")
    except Exception as e:
        logger.warning(f"Failed to retrieve past responses: {str(e)}")
        # Instead of returning an error, continue with an empty list
        past_response = []

    # Generate AI recommendation with retry mechanism
    retry = 0
    parsed_json = None
    gemini_response = None

    # Retry up to 3 times to get a valid response
    while retry < 3 and parsed_json is None:
        try:
            gemini_response = get_genai_response(past_response, timestamp)
            parsed_json = verify_and_parse_json(gemini_response)
            if parsed_json is None:
                logger.warning(
                    f"Attempt {retry+1}/3: Invalid response from Gemini AI")
        except AIProcessingError as e:
            logger.error(f"Attempt {retry+1}/3: {str(e)}")

        retry += 1

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

    # Use the client-provided timestamp or generate one in the required format
    if timestamp and isinstance(timestamp, dict) and 'time' in timestamp and 'dayOfWeek' in timestamp:
        parsed_json["timestamp"] = timestamp
    else:
        current_time = datetime.now()
        parsed_json["timestamp"] = {
            "time": current_time.strftime("%H:%M:%S"),
            "dayOfWeek": str(current_time.weekday())
        }

    # Try to invoke result-save-send Lambda to process the recommendation
    # But continue even if it fails due to permissions issues
    result_lambda_name = os.environ.get(
        'RESULT_LAMBDA_NAME', 'result-save-send')
    try:
        logger.info(
            f"Attempting to invoke Lambda function: {result_lambda_name}")

        # Make sure to include the timestamp in the payload
        lambda_client.invoke(
            FunctionName=result_lambda_name,
            InvocationType='Event',  # for async invocation
            Payload=json.dumps(parsed_json)
        )
        logger.info(
            f"Successfully invoked Lambda function: {result_lambda_name}")
    except Exception as e:
        # Log the error but continue processing
        logger.warning(
            f"Failed to invoke Lambda function {result_lambda_name}: {str(e)}")
        logger.warning("Continuing execution to return recommendation to user")

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
