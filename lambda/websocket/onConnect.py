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
        connection_id = body['connectionId']
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
