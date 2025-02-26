import json
import os
import logging
import boto3
import math
import google.generativeai as genai
from google.ai.generativelanguage_v1beta.types import content
from datetime import datetime
import base64
import asyncio
from boto3.dynamodb.conditions import Key

# Custom Auth Error
class AuthenticationError(Exception):
    """Custom exception for authentication failures"""
    pass

# Initialize the logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients outside of the handler
s3_client = boto3.client('s3')  # S3 client
google_gemini_api_key = os.environ.get('GOOGLE_GEMINI_API_KEY')
if not google_gemini_api_key:
    raise EnvironmentError(
        "GOOGLE_GEMINI_API_KEY environment variable is not set")
client = genai.Client(api_key=google_gemini_api_key)  # Gemini client
dynamodb = boto3.resource(
    'dynamodb', region_name='us-east-1')  # DynamoDB client


def authUser(uuid, pin):
    """
    Authenticate user by comparing the provided pin with the stored pin in DynamoDB.

    Args:
        uuid (str): The unique identifier for the user.
        pin (str): The pin provided by the user.

    Raises:
        AuthenticationError: If the authentication fails.

    Returns:
        bool: True if authentication is successful, False otherwise.
    """
    table = dynamodb.Table("auth_table")

    try:
        response = table.get_item(Key={'uuid': uuid})
        stored_pin = response.get("Item", {}).get("pin")

        if not stored_pin or stored_pin != pin:
            raise AuthenticationError("Invalid pin")

    except Exception as e:
        logger.error(f"Failed to authenticate user: {str(e)}")
        raise AuthenticationError("Authentication failed")


def store_wav_file(uuid, file):
    wav_file = f"/tmp/{uuid}.wav"
    with open(wav_file, "wb") as f:
        f.write(file)
    return wav_file


def getGenaiResponse(file):
    """
    Generate a response using the Gemini AI model based on the uploaded file.

    Args:
        file (str): an audio file to be uploaded for processing.

    Returns:
        dict: The response from the Gemini AI model.
    """
    myfile = client.files.upload(file)
    file_name = myfile.name
    myfile = client.files.get(name=file_name)

    # Create the model configuration
    generation_config = {
        "temperature": 1,
        "top_p": 0.95,
        "top_k": 40,
        "max_output_tokens": 8192,
        "response_schema": content.Schema(
            type=content.Type.OBJECT,
            required=["lightSetting", "emotion", "recommendation", "context"],
            properties={
                "lightSetting": content.Schema(
                    type=content.Type.OBJECT,
                    required=["lightType", "brightness"],
                    properties={
                        "lightType": content.Schema(type=content.Type.STRING),
                        "color": content.Schema(
                            type=content.Type.ARRAY,
                            items=content.Schema(type=content.Type.INTEGER),
                        ),
                        "dynamicMode": content.Schema(type=content.Type.STRING),
                        "brightness": content.Schema(type=content.Type.INTEGER),
                        "power": content.Schema(type=content.Type.BOOLEAN),
                    },
                ),
                "emotion": content.Schema(
                    type=content.Type.OBJECT,
                    description="Emotion analysis results.",
                    required=["main", "subcategories"],
                    properties={
                        "main": content.Schema(type=content.Type.STRING),
                        "subcategories": content.Schema(
                            type=content.Type.ARRAY,
                            items=content.Schema(type=content.Type.STRING),
                        ),
                    },
                ),
                "recommendation": content.Schema(type=content.Type.STRING),
                "context": content.Schema(type=content.Type.STRING),
            },
        ),
        "response_mime_type": "application/json",
    }

    # Create the model
    model = genai.GenerativeModel(
        model_name="gemini-2.0-flash",
        generation_config=generation_config,
        system_instruction="You are an AI assistant designed to analyze audio input and recommend light settings based on the user’s emotional state, context, and current time, while utilizing light therapy principles when beneficial.\n\nInstructions:\n\t1.\tAnalyze Audio:\n\t•\tProcess the user’s audio input to detect emotional cues and context (e.g., studying, gaming, sadness, excitement).\n\t•\tConsider the time of day when determining the best lighting recommendation.\n\t2.\tChoose a Light Type (One of the following):\n\t•\tStatic RGB Mode ([R, G, B]): Use this when a steady, non-dynamic light is better for the user’s needs.\n\t•\tDynamic Mode (FLASH, STROBE, FADE, SMOOTH, JUMP3, JUMP7, FADE3, FADE7): Use this when changing colors enhances mood or energy.\n\t3.\tDetermine Light Settings (Based on Chosen Type):\n\t•\tIf Static RGB Mode is chosen → Provide an [R, G, B] value (each 0–255).\n\t•\tIf Dynamic Mode is chosen → Pick one from (FLASH, STROBE, FADE, SMOOTH, JUMP3, JUMP7, FADE3, FADE7).\n\t•\tBrightness: Always set between 0–7, depending on the context.\n\t4.\tIdentify Emotions:\n\t•\tMain category: Positive, Negative, or Neutral.\n\t•\tThree subcategories (e.g., Happiness, Excitement, Anxiety, Sadness, etc.).\n\t5.\tApply Light Therapy Principles (if beneficial):\n\t•\tMorning/Afternoon: If tired, use bright, cool tones (e.g., white, blue) to enhance alertness.\n\t•\tEvening/Night: If stressed/anxious, use warm tones (e.g., amber, soft red) to promote relaxation.\n\t•\tNegative emotions: Use light therapy-backed settings to improve mood.\n\t•\tPositive/Neutral emotions: Reinforce their current emotional state with complementary lighting.\n\t6.\tRecommendation:\n\t•\tIf negative, suggest a setting that may improve mood. Also, provide warm, encouraging words if needed.\n\t•\tIf positive/neutral, reinforce their mood with suitable lighting.\n\t•\tProvide a concise, user-friendly explanation for the choice.\n\t7.\tContext Consideration:\n\t•\tSummarize the user’s situation (e.g., “You are studying late and feeling tired.”).\n\t•\tIf the context is unclear, use a “random preset” as a fallback.\n",
    )

    response = client.models.generate_content(
        model,
        contents=[
            'follow the system instruction',
            myfile,
        ]
    )

    client.files.delete(name=myfile.name)

    return response


def verifyJson(response):
    """
    Verify the JSON response to ensure it contains the required fields and valid values.

    Args:
        response (str): The JSON response as a string.

    Returns:
        bool: True if the JSON response is valid, False otherwise.
    """
    if not isinstance(response, str):
        logger.error("Failed. Response is not a string")
        return False

    try:
        json_response = json.loads(response)
    except Exception as e:
        logger.error(f"Failed. Not a valid JSON format: {str(e)}")
        return False

    if json_response.get("context") is None:
        logger.error("Failed. No context")
        return False

    if json_response.get("emotion") is None:
        logger.error("Failed. No emotion")
        return False

    if json_response.get("lightSetting") is None:
        logger.error("Failed. No lightSetting")
        return False

    brightness = json_response["lightSetting"].get("brightness")

    if brightness is None or brightness < 0 or brightness > 7:
        logger.error("Failed. Error in brightness")
        return False

    lightType = json_response["lightSetting"].get("lightType")

    if lightType is None or lightType not in ["RGB", "Dynamic"]:
        logger.error("Failed. Error in lightType")
        return False

    color = json_response["lightSetting"].get("color")
    dynamicMode = json_response["lightSetting"].get("dynamicMode")

    if color is None and dynamicMode is None:
        logger.error("Failed. Error in light mode")
        return False
    else:
        if color is None:
            if dynamicMode not in ["FLASH", "STROBE", "FADE", "SMOOTH", "JUMP3", "JUMP7", "FADE3", "FADE7"]:
                logger.error("Failed. Error in dynamic mode")
                return False
        if dynamicMode is None:
            if not (isinstance(color, list) and all(code >= 0 and code < 256 for code in color)):
                logger.error("Failed. Error in color code")
                return False

    if json_response.get("recommendation") is None:
        logger.error("Failed. No recommendation")
        return False

    return True


async def configure_light_settings(response):
    response_json = json.loads(response)
    lightSetting = response_json["lightSetting"]
    deviceType = "light"
    if lightSetting["lightType"] == "RGB":
        color = lightSetting["color"]
        dynamicMode = lightSetting.get("dynamicMode")
        if dynamicMode is None:
            ir_code = findClosestPreset(color, deviceType)
        else:
            ir_code = getDynamicMode(dynamicMode, deviceType)
    else:
        ir_code = findClosestPreset([0, 0, 0], deviceType)

    response_json["lightSetting"]["ir_code"] = ir_code["ir_code"]
    response_json["lightSetting"]["r_up"] = ir_code["r_up"]
    response_json["lightSetting"]["r_down"] = ir_code["r_down"]
    response_json["lightSetting"]["g_up"] = ir_code["g_up"]
    response_json["lightSetting"]["g_down"] = ir_code["g_down"]
    response_json["lightSetting"]["b_up"] = ir_code["b_up"]
    response_json["lightSetting"]["b_down"] = ir_code["b_down"]

    response = json.dumps(response_json)
    return response


def findClosestPreset(target, deviceType):
    """
    Return the closest preset to the target (ir code, increment, decrement).

    Args:
        target (list): The target RGB values.
        deviceType (str): The type of device.

    Returns:
        dict: The closest preset with IR codes and adjustments.
    """
    result = {"ir_code": None, "r_up": None, "r_down": None,
              "g_up": None, "g_down": None, "b_up": None, "b_down": None}

    table = dynamodb.Table("device_table")

    response = table.query(
        KeyConditionExpression=Key('deviceType').eq(
            deviceType) & Key('id').gt(7)
    )

    items = response.get('Items', [])

    min_diff = math.inf

    for item in items:
        colorCode = item.get("rgb_code")
        r = colorCode[0]
        g = colorCode[1]
        b = colorCode[2]
        diff = abs(target[0] - r) + abs(target[1] - g) + abs(target[2] - b)
        if diff < min_diff:
            min_diff = diff
            result["ir_code"] = item.get("ir_code")
            result["r_up"] = item.get("r_up")
            result["r_down"] = item.get("r_down")
            result["g_up"] = item.get("g_up")
            result["g_down"] = item.get("g_down")
            result["b_up"] = item.get("b_up")
            result["b_down"] = item.get("b_down")
        else:
            continue

    return result


def getDynamicMode(dynamicMode, deviceType):
    """
    Get the IR code for the dynamic mode.

    Args:
        dynamicMode (str): The dynamic mode.
        deviceType (str): The type of device.

    Returns:
        str: The IR code for the dynamic mode.
    """
    dynamicModeDict = {"FLASH": 0, "STROBE": 1, "FADE": 2,
                       "SMOOTH": 3, "JUMP3": 4, "JUMP7": 5, "FADE3": 6, "FADE7": 7}

    result = {"ir_code": None, "r_up": None, "r_down": None,
              "g_up": None, "g_down": None, "b_up": None, "b_down": None}

    dynamicModeID = dynamicModeDict[dynamicMode]

    table = dynamodb.Table("dynamic_mode_table")

    try:
        response = table.get_item(
            Key={
                'deviceType': deviceType,
                'id': dynamicModeID
            }
        )
        ir_code = response.get("Item", {}).get("ir_code")
        result["ir_code"] = ir_code
    except Exception as e:
        logger.error(f"Failed to retrieve item from DynamoDB: {str(e)}")
        return None

    return result


async def uploadResponseS3(response, uuid):
    """
    Upload the JSON response to an S3 bucket.

    Args:
        response (str): The JSON response as a string.
        uuid (str): The unique identifier for the user.

    Returns:
        str: The URL of the uploaded file.
    """
    bucket_name = os.environ['BUCKET_NAME']
    current_time = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    file_name = f"responses/{uuid}/{current_time}.json"

    try:
        s3_client.put_object(
            Body=response,
            Bucket=bucket_name,
            Key=file_name
        )
    except Exception as e:
        logger.error(f"Failed to upload file to S3: {str(e)}")
        return None


async def getConnectionId(uuid):
    """
    Get the connection ID from the DynamoDB table.

    Args:
        uuid (str): The unique identifier for the user.

    Returns:
        str: The connection ID.
    """
    table = dynamodb.Table("websocket_finder")

    try:
        response = table.get_item(Key={'uuid': uuid})
    except Exception as e:
        logger.error(f"Failed to retrieve item from DynamoDB: {str(e)}")
        return None

    connection_id = response.get("Item", {}).get("connectionId")
    if not connection_id:
        logger.error("Connection ID not found for the given UUID")
        return None
    return connection_id


async def send_data_to_arduino(connection_id, response):
    apigateway_client = boto3.client(
        'apigatewaymanagementapi', endpoint_url=os.environ['WEBSOCKET_URL'])
    response = apigateway_client.post_to_connection(
        ConnectionId=connection_id,
        Data=response.encode('utf-8')
    )
    return response


async def main(event, context):

    # Extract the required parameters from the event
    try:
        uuid = event['uuid']
        pin = event['pin']
        file = base64.b64decode(event['file'])
    except KeyError as e:
        logger.error(f"Missing required parameter: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps("Missing required parameter")
        }

    # Store the audio file
    try:
        storeWavFileTask = asyncio.create_task(store_wav_file(uuid, file))
    except Exception as e:
        logger.error(f"Failed to write file: {str(e)}")

    # Authenticate the user
    try:
        authUser(uuid, pin)
    except AuthenticationError as e:
        return {
            'statusCode': 401,
            'body': json.dumps(str(e))
        }

    # Get the response from the Gemini AI model
    await storeWavFileTask
    wav_file = storeWavFileTask.result

    retry = 0
    verified = False

    # Retry up to 3 times to get a valid response
    while retry < 3 and not verified:
        response = getGenaiResponse(wav_file)
        retry += 1
        verified = verifyJson(response)

    if not verified:
        return {
            'statusCode': 400,
            'body': json.dumps("AI failed to create an appropriate response")
        }

    try:
        forArduinoTask = asyncio.create_task(
            configure_light_settings(response))
    except Exception as e:
        logger.error(f"Failed to configure light settings: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps("Failed to configure light settings")
        }

    try:
        uploadRawResponse = asyncio.create_task(
            uploadResponseS3(response, uuid))
    except Exception as e:
        logger.error(f"Failed to upload response to S3: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps("Failed to upload response to S3")
        }

    try:
        getConnectionId = asyncio.create_task(getConnectionId(uuid))
    except Exception as e:
        logger.error(f"Failed to get connection ID: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps("Failed to get connection ID")
        }

    await asyncio.gather(forArduinoTask, getConnectionId)

    # Get the results of the tasks to send data to Arduino
    response = forArduinoTask.result()
    connectionId = getConnectionId.result()

    try:
        send_data_to_arduino(connectionId, response)
    except Exception as e:
        logger.error(f"Failed to send data to Arduino: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps("Failed to send data to Arduino")
        }

    # Wait for the response to be uploaded to S3
    await uploadRawResponse

    # Return the recommendation to the user
    return {
        'statusCode': 200,
        'body': response["recommendation"]
    }


def lambda_handler(event, context):
    asyncio.run(main(event, context))
