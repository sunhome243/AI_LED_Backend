import boto3.session
import logging
import json

# Initialize just the DynamoDB resource with minimal imports
session = boto3.session.Session()
dynamodb = session.resource('dynamodb')
table = dynamodb.Table('ConnectionIdTable')

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    # Add CORS headers to all responses
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Credentials': True
    }

    # Handle OPTIONS method for CORS preflight requests
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight successful'})
        }

    try:
        uuid = event.get('uuid')
        if not uuid:
            raise ValueError("UUID is required")
    except Exception as e:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({
                'error': 'wrong input',
                'message': str(e)
            })
        }

    try:
        # Correct way to query an item from DynamoDB
        response = table.get_item(Key={'uuid': uuid})

        # Check if the item exists and has a connectionId
        if 'Item' in response and 'connectionId' in response['Item']:
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'connected': True,
                    'message': 'Arduino is connected'
                })
            }
        else:
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'connected': False,
                    'message': 'Arduino is not connected'
                })
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'error': 'failed to check connection status',
                'message': str(e)
            })
        }
