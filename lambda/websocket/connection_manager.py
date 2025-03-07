from boto3.session import Session
import logging
import json
import os

# Initialize AWS resources with explicit region
# Default to us-east-1 if not specified
region = os.environ.get('AWS_REGION', 'us-east-1')
session = Session(region_name=region)
dynamodb = session.resource('dynamodb')
table = dynamodb.Table(os.environ.get('CONNECTION_TABLE', 'ConnectionIdTable'))

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def on_connect(event, context):
    """Handle $connect WebSocket event"""
    try:
        connection_id = event['requestContext']['connectionId']

        # Get UUID from query parameters
        uuid = event.get('queryStringParameters', {}).get('uuid')
        if not uuid:
            raise ValueError("uuid is missing")

        # Store connection mapping in DynamoDB
        table.put_item(Item={'uuid': uuid, 'connectionId': connection_id})

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'connection id saved'})
        }
    except ValueError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'wrong input',
                'message': str(e)
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'failed to save in dynamodb',
                'message': str(e)
            })
        }


def on_disconnect(event, context):
    """Handle $disconnect WebSocket event"""
    try:
        connection_id = event['requestContext']['connectionId']

        # Query to find the item with this connection_id
        response = table.scan(
            FilterExpression="connectionId = :conn_id",
            ExpressionAttributeValues={":conn_id": connection_id}
        )

        items = response.get('Items', [])
        if items:
            # Delete the item using its primary key (uuid)
            for item in items:
                table.delete_item(Key={'uuid': item['uuid']})

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'connection id deleted'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'failed to delete in dynamodb',
                'message': str(e)
            })
        }


def lambda_handler(event, context):
    """Main handler that routes to the appropriate function"""
    route_key = event['requestContext'].get('routeKey')

    if route_key == '$connect':
        return on_connect(event, context)
    elif route_key == '$disconnect':
        return on_disconnect(event, context)
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'message': f'Unsupported route: {route_key}'})
        }
