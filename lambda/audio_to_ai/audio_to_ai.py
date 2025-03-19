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
    Authenticate user against DynamoDB.

    Args:
        uuid: User identifier
        pin: User PIN

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


def store_wav_file(uuid, file):
    """
    Store binary audio to temporary location.

    Args:
        uuid: User identifier
        file: Binary audio data

    Returns:
        Path to stored temp file

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
    Generate response from Gemini AI based on audio.

    Args:
        file: Path to audio file

    Returns:
        Response from Gemini AI

    Raises:
        AIProcessingError: If AI processing fails
    """
    try:
        # Read the audio file directly instead of uploading
        with open(file, 'rb') as f:
            audio_data = f.read()

        # Create comprehensive prompt for user query
        combined_prompt = "User Request: Analyze this audio and recommend optimal lighting settings."

        # Create contents with user role including the audio file reference using inline_data
        contents = [
            genai.types.Content(
                role="user",
                parts=[
                    genai.types.Part.from_text(text=combined_prompt),
                    genai.types.Part.from_file(
                        data=audio_data, mime_type="audio/wav"),
                ],
            ),
        ]

        # System instruction for proper context
        system_instruction = """# Personalized Lighting Assistant

You are an AI that analyzes audio input to create personalized lighting recommendations based on emotional state, context, and time of day.

Analysis Functions
- Audio Analysis: Detect emotional tone, context, and activity from user speech patterns and environmental sounds.
- Lighting Recommendation: Create settings based on analysis, time of day, and light therapy research when beneficial.

Output Schema (ALL fields REQUIRED)

1. Keyword Object (`keyword`)
- Purpose: Used for personalization by categorizing the user's activity.
- Structure:
  - `mainKeyword`: General activity category (e.g., `\"game\"`, `\"study\"`, `\"movie\"`, `\"exercise\"`, `\"relax\"`, `\"music\"`).
  - `subKeyword`: More detailed and specific keyword related to the main activity.
    - Examples:
      - For Gaming: `{ \"mainKeyword\": \"game\", \"subKeyword\": \"overwatch\" }`
      - For Movie Watching: `{ \"mainKeyword\": \"movie\", \"subKeyword\": \"horror\" }`
      - For Studying: `{ \"mainKeyword\": \"study\", \"subKeyword\": \"math\" }`
    - If no specific `subKeyword` is detected, it should be set to `\"general\"`.

2. Light Settings (`lightSetting`)
- Choose ONLY ONE option between `Color` and `Dynamic mode`:
  - Color: RGB values as a string array (e.g., `[\"255\", \"0\", \"0\"]`).
    - Brightness Scaling (MUST BE UNDERSTOOD)
      - `[0,0,0]` = Off (Darkest setting)
      - `[255,255,255]` = Fully bright (Maximum brightness)
      - AI must adjust brightness based on the environment and user context.
        - Dark Environment (e.g., `\"dark room\"`, `\"watching a movie\"`) → Lower brightness
        - Bright Environment (e.g., `\"studying\"`, `\"working\"`) → Higher brightness
      - LED Strip Application:  
        - These RGB values are used to control LED strip lighting.
        - The AI must correctly adjust the lighting to provide an optimal experience.

  - Dynamic (ONLY if truly necessary): Select ONE pattern:
    - General Effects:
      - `AUTO`: Automatically cycles through different lighting modes and effects.
      - `SLOW`: Decreases the speed of color changes or effects.
      - `QUICK`: Increases the speed of color changes or effects.
      - `FLASH`: Activates a white light strobe mode.
      - `FADE7`: Gradual transition between 7 colors.
      - `FADE3`: Gradual transition between 3 colors.
      - `JUMP7`: Abrupt change between 7 colors.
      - `JUMP3`: Abrupt change between 3 colors.

    - Music Reactive Effects (music1-4):
      - `MUSIC1`: Gentle, slow response to music beats.
      - `MUSIC2`: Moderate response to music.
      - `MUSIC3`: Faster, more dynamic response.
      - `MUSIC4`: Most sensitive and rapid response to music beats.

    - DO NOT use dynamic mode unless it is truly necessary.
    - Only apply dynamic effects for:
      - Parties / Celebrations (e.g., `\"party\"`, `\"birthday\"`, `\"celebration\"`)
      - High-energy activities (e.g., `\"dancing\"`, `\"working out\"`, `\"rave\"`)
      - Music synchronization (explicit request or strong music-related context)

- Power: Boolean (`true`=on, `false`=off).

3. Emotional Analysis (`emotion`)
- Main: Primary category (`Positive`, `Negative`, or `Neutral`).
- Subcategories: Array of 3 specific emotions.

4. User Support Information
- Recommendation: Brief explanation of the lighting choice (1-2 sentences) with a user-friendly closing sentence. Use appropriate emoji. If light therapy knowledge was applied, mention it briefly in an accessible way.
- Context: Concise description of the detected user situation (10-20 words).

Implementation Guidelines

Brightness Adjustment (MUST BE FOLLOWED)
- `[0,0,0]` is the darkest setting (lights off).
- `[255,255,255]` is the brightest setting (fully on).
- AI must adjust brightness dynamically based on:
  - Time of Day:
    For example, 
    - Morning/Daytime → Brighter, cooler lights (e.g., `[255, 255, 200]`)
    - Evening/Nighttime → Warmer, softer lights (e.g., `[180, 100, 50]`)
  - User Activity:
    For example,
    - `\"watching a movie\"` → Dim lighting (e.g., `[50, 0, 0]` for horror, `[80, 50, 50]` for romance)
    - `\"playing a game\"` → Adapt to game theme (e.g., `\"overwatch\"` → Orange/Blue theme)
    - `\"studying\"` → Bright white light (e.g., `[255, 255, 255]`)
  - Implicit Dark Environment Prediction:
    - If no explicit mention of brightness is given, infer the likely environment:
      - Low Brightness (Dark Environment Expected):
        - `\"watching a movie\"`, `\"playing a horror game\"`, `\"relaxing\"`, `\"listening to calm music\"`, `\"meditating\"`, `\"chilling\"`, `\"sleeping\"`, `\"having a romantic dinner\"`
      - High Brightness (Bright Environment Expected):
        - `\"studying\"`, `\"exercising\"`, `\"cooking\"`, `\"working on a project\"`, `\"reading a book\"`, `\"cleaning\"`, `\"getting ready for the day\"`

Theme-Based Color Selection
- If the user's activity has a single, clear theme color → Apply them:
  - `\"Deadpool\"` →  red-ish
  - `\"Ocean\"` →  blue-ish
  - `\"Sunset\"` → warm orange -ish
- If the theme has multiple conflicting colors or is unclear → Use general analysis instead:
  - `\"Christmas\"` (Red & Green) → General analysis
  - `\"Halloween\"` (Orange, Black, Purple) → General analysis
  - `\"Festival\"` (Unclear colors) → General analysis

Fallback Protocol
- Use time-appropriate defaults when context is unclear."""

        # Get configuration
        config = genai.types.GenerateContentConfig(
            temperature=0.65,
            top_p=0.95,
            top_k=40,
            max_output_tokens=8192,
            safety_settings=[
                genai.types.SafetySetting(
                    category="HARM_CATEGORY_HARASSMENT",
                    threshold="BLOCK_NONE",  # Block none
                ),
                genai.types.SafetySetting(
                    category="HARM_CATEGORY_HATE_SPEECH",
                    threshold="BLOCK_NONE",  # Block none
                ),
                genai.types.SafetySetting(
                    category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    threshold="BLOCK_NONE",  # Block none
                ),
                genai.types.SafetySetting(
                    category="HARM_CATEGORY_DANGEROUS_CONTENT",
                    threshold="BLOCK_NONE",  # Block none
                ),
                genai.types.SafetySetting(
                    category="HARM_CATEGORY_CIVIC_INTEGRITY",
                    threshold="BLOCK_NONE",  # Block none
                ),
            ],
            response_mime_type="application/json",
            response_schema=genai.types.Schema(
                type=genai.types.Type.OBJECT,
                required=["lightSetting", "emotion",
                          "recommendation", "context"],
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
                                enum=["AUTO", "SLOW", "QUICK", "FLASH", "FADE7", "FADE3",
                                      "JUMP7", "JUMP3", "MUSIC1", "MUSIC2", "MUSIC3", "MUSIC4"],
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
                                    enum=["Happy", "Excited", "Thankful", "Proud", "Relaxed", "Satisfied", "Peaceful", "Relieved", "Surprised (Good)", "Energetic", "Motivated", "Loved", "Hopeful", "Disappointed", "Sad", "Lonely", "Regretful", "Frustrated",
                                          "Annoyed", "Angry", "Hurt", "Anxious", "Scared", "Worried", "Doubtful", "Helpless", "Disgusted", "Uncomfortable", "Shocked (Bad)", "Conflicted", "Indifferent", "Practical", "Logical", "Clear-headed", "Balanced", "Neutral"],
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
            ),
            system_instruction=[
                genai.types.Part.from_text(text=system_instruction)
            ],
        )

        # Call the Gemini API with the correct format
        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=contents,
            generation_config=config,
        )

        return response
    except Exception as e:
        logger.error(f"Error in Gemini AI processing: {str(e)}")
        raise AIProcessingError(f"Gemini AI processing failed: {str(e)}")


def verify_and_parse_json(response):
    """
    Validate AI-generated lighting configuration.

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

    # Extract lighting parameters - note the field name change from dynamicMode to dynamic
    color = light_setting.get("color")
    # Changed from dynamicMode to dynamic
    dynamic_mode = light_setting.get("dynamic")
    power = light_setting.get("power")

    # Validate light configuration based on power state and mode
    if color is None and dynamic_mode is None:
        if power is False:  # if power is off, no need to check color and dynamic mode
            pass
        else:
            logger.error(
                "Failed. Error in light mode: neither color nor dynamic specified when power is on")
            return None
    else:
        # Validate dynamic mode option if color is not specified
        if color is None:
            if dynamic_mode not in VALID_DYNAMIC_MODES:
                logger.error(f"Failed. Error in dynamic mode: {dynamic_mode}")
                return None
        # Validate RGB color format if dynamic mode is not specified
        if dynamic_mode is None:
            if not isinstance(color, list) or len(color) != 3:
                logger.error(f"Failed. Error in color code format: {color}")
                return None
            # Convert string values to integers if they're strings
            try:
                if all(isinstance(code, str) for code in color):
                    color_int = [int(code) for code in color]
                    if not all(0 <= code < 256 for code in color_int):
                        logger.error(
                            f"Failed. Color values out of range: {color}")
                        return None
                    # Update the color values to integers in the response
                    json_response["lightSetting"]["color"] = color_int
                elif not all(isinstance(code, int) and 0 <= code < 256 for code in color):
                    logger.error(f"Failed. Invalid color values: {color}")
                    return None
            except ValueError:
                logger.error(
                    f"Failed. Color values not convertible to integers: {color}")
                return None

    return json_response


def lambda_handler(event, context):
    """
    Process audio-based lighting requests.

    Authenticates user, processes audio, gets AI recommendation,
    and returns lighting configuration.

    Args:
        event: Lambda event with user identification and audio file
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
