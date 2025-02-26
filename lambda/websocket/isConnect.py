import boto3
import logging
import json

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ConnectionIdTable')

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        uuid = body['uuid']
    except Exception as e:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'wrong input',
                'message': str(e)
            })
        }

    try:
        table.get_item(Item={'uuid': uuid})
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'failed to get in dynamodb. not connected',
                'message': str(e)
            })
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Arduino is connected'})
    }
