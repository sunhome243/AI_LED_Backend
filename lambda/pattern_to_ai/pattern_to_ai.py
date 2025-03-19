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


def get_past_reponse(uuid):
    """
    Retrieves past responses for a user within a 2-hour window.

    Args:
        uuid: User unique identifier

    Returns:
        List of user response items within the timeframe

    Raises:
        Exception: If the DynamoDB query fails
    """
    # Calculate time window boundaries (±1 hour from current time)
    current_time = datetime.now()
    one_hour = timedelta(hours=1)
    future_time = current_time + one_hour
    future_time = future_time.strftime("%H:%M")
    past_time = current_time - one_hour
    past_time = past_time.strftime("%H:%M")
    day = datetime.today().weekday()

    # Get the DynamoDB table reference
    table = dynamodb.Table('ResponseTable')

    # Create the composite sort key values based on your actual schema
    # Changed from DAY#TIME to TIME#DAY as per the error message
    time_day_prefix = f"TIME#DAY"
    start_key = f"{time_day_prefix}#{past_time}#{day}"
    end_key = f"{time_day_prefix}#{future_time}#{day}"

    # Format UUID with prefix to match how it's stored in the database
    uuid_key = f'uuid#{uuid}'

    try:
        # Query DynamoDB for responses within the time window using resource API
        response = table.query(
            KeyConditionExpression=Key('uuid').eq(uuid_key) &
            Key('TIME#DAY').between(start_key, end_key),
            Limit=20  # Limit to 20 most recent responses
        )

        # Return the items from the response
        return response.get('Items', [])
    except Exception as e:
        logger.error(f"Error querying DynamoDB: {str(e)}")
        raise


def get_genai_response(past_response):
    """
    Generate a response using Gemini AI based on past user responses.

    Args:
        past_response: Past user responses from DynamoDB

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

1️⃣ User Activity (activity)
	•	main: General category (e.g., "study", "reading", "movie").
	•	sub: Specific details ("math", "comic book", "horror movie").

2️⃣ Light Settings (lightSetting)
	•	Choose ONE of the following:
	•	RGB Color: [R, G, B] based on prior preferences and environmental factors.
	•	Dynamic Mode: "FADE3", "MUSIC2", etc. (Only if the activity requires it, e.g., music, party, gaming.)
	•	Brightness Scaling: Adjust brightness based on time, activity, and previous feedback.
	•	Power: true (on) or false (off).

3️⃣ Emotional Analysis (emotion)
	•	main: "Positive", "Negative", "Neutral"
	•	sub: Top 3 detected emotions.

4️⃣ Recommendation (recommendation)
	•	Explain why this lighting choice was made.
	•	Example: "Since you usually study between 12 PM - 3 PM on Mondays, bright white light is set for focus. Stay productive! ✨"

5️⃣ Context (context)
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
        if not past_response:
            user_prompt = "Generate a lighting recommendation for a new user."
        else:
            user_prompt = f"Based on these past responses: {json.dumps(past_response)}, generate a lighting recommendation."

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
            safety_settings=[
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
            ],
            response_mime_type="application/json",
            response_schema=response_schema,
            system_instruction=[
                genai.types.Part.from_text(text=instruction_text)
            ],
        )

        # Create contents with user prompt and system instruction
        contents = [
            {"role": "user", "parts": [{"text": user_prompt}]}
        ]

        # Call the API with the correct format
        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=contents,
            config=generate_content_config
        )

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

    # Authenticate the user
    try:
        auth_user(uuid, pin)
    except AuthenticationError as e:
        return {
            'statusCode': 401,
            'headers': CORS_HEADERS,
            'body': json.dumps(str(e))
        }

    # Retrieve past responses for context
    try:
        # Get the past response of the user
        past_response = get_past_reponse(uuid)
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
            gemini_response = get_genai_response(past_response)
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
    parsed_json["timestamp"] = datetime.now().isoformat()

    # Try to invoke result-save-send Lambda to process the recommendation
    # But continue even if it fails due to permissions issues
    result_lambda_name = os.environ.get(
        'RESULT_LAMBDA_NAME', 'result-save-send')
    try:
        logger.info(
            f"Attempting to invoke Lambda function: {result_lambda_name}")
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
