from boto3.resources.factory import ServiceResource
from boto3.session import Session
import logging
import json

# Initialize just the DynamoDB resource instead of all boto3
session = Session()
dynamodb = ServiceResource('dynamodb')
table = dynamodb.Table('ConnectionIdTable')

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:
        uuid = event.get('uuid')
        if not uuid:
            raise ValueError("UUID is required")
    except Exception as e:
        return {
            'statusCode': 400,
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
                'body': json.dumps({
                    'connected': True,
                    'message': 'Arduino is connected'
                })
            }
        else:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'connected': False,
                    'message': 'Arduino is not connected'
                })
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'failed to check connection status',
                'message': str(e)
            })
        }
