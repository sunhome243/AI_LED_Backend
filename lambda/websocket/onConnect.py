from boto3.session import Session
import logging
import json

# Initialize only what's needed
session = Session()
dynamodb = session.resource('dynamodb')
table = dynamodb.Table('ConnectionIdTable')

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:
        connection_id = event['requestContext']['connectionId']

        uuid = event.get('queryStringParameters', {}).get('uuid')
        if not uuid:
            raise ValueError("uuid is missing")
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'wrong input',
                'message': str(e)
            })
        }

    try:
        table.put_item(Item={'uuid': uuid, 'connectionId': connection_id})
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'failed to save in dynamodb',
                'message': str(e)
            })
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'connection id saved'})
    }
