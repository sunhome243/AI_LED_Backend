from boto3.resources.factory import ServiceResource
import logging
import json

dynamodb = ServiceResource('dynamodb')
table = dynamodb.Table('ConnectionIdTable')

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    connection_id = event['requestContext']['connectionId']

    if not connection_id:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'wrong input',
                'message': 'connection id not found'
            })
        }

    try:
        table.delete_item(Key={'connectionId': connection_id})
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'failed to delete in dynamodb',
                'message': str(e)
            })
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'connection id deleted'})
    }
