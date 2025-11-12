import json
import os
import uuid
import boto3
from botocore.exceptions import ClientError
import logging

# Logger Configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients outside of the handler (best practice)
try:
    sfn_client = boto3.client('stepfunctions')
    dynamodb_client = boto3.client('dynamodb')

    STEP_FUNCTION_ARN = os.environ['STEP_FUNCTION_ARN']
    DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
except KeyError as e:
    logger.error(f"Environment variable not defined: {e}")
    # This will cause the Lambda initialization to fail, which is the
    # desired outcome


def lambda_handler(event, context):
    """
    Main entry point. Routes based on the HTTP method.
    """
    logger.info(f"Event received: {json.dumps(event)}")

    http_method = event.get('httpMethod')

    try:
        if http_method == 'POST':
            return start_vpc_creation(event)
        elif http_method == 'GET':
            return get_vpc_status(event)

        return create_response(405, {"error": "Method Not Allowed"})

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return create_response(500, {"error": "Internal Server Error"})


def start_vpc_creation(event):
    """
    Handles POST /vpc requests. Validates input, saves to DynamoDB,
    and starts the Step Function.
    """
    try:
        body = json.loads(event.get('body', '{}'))
    except json.JSONDecodeError:
        return create_response(
            400, {"error": "The request body is incorrectly formatted "
                           "(invalid JSON)."}
        )

    # Input validation
    cidr = body.get('cidr')

    if not cidr:
        return create_response(400,
                               {"error": "Required field missing: 'cidr'"})

    job_id = str(uuid.uuid4())

    # Payload for Step Function
    sfn_payload = {
        'job_id': job_id,
        'cidr': cidr
    }

    try:
        # 1. Register the job in DynamoDB as PENDING
        dynamodb_client.put_item(
            TableName=DYNAMODB_TABLE,
            Item={
                'job_id': {'S': job_id},
                'status': {'S': 'PENDING'},
                'request_payload': {'S': json.dumps(body)}
            }
        )

        # 2. Start a Step Function
        sfn_client.start_execution(
            stateMachineArn=STEP_FUNCTION_ARN,
            name=job_id,
            input=json.dumps(sfn_payload)
        )

        logger.info(f"Job {job_id} iniciado com sucesso.")

        # 202 Accepted is the correct HTTP response for asynchronous operations.
        return create_response(202, {'job_id': job_id, 'status': 'PENDING'})

    except ClientError as e:
        logger.error(f"Boto3 error (start_vpc_creation): {e}")
        return create_response(500, {"error": "Error starting job"})


def get_vpc_status(event):
    """
    Handles GET /vpc/{job_id}. Query DynamoDB for job status.
    """
    job_id = event.get('pathParameters', {}).get('job_id')

    if not job_id:
        return create_response(400, {"error": "Missing job_id path parameter"})

    try:
        response = dynamodb_client.get_item(
            TableName=DYNAMODB_TABLE,
            Key={'job_id': {'S': job_id}}
        )

        if 'Item' not in response:
            logger.warn(f"Job not found: {job_id}")
            return create_response(404, {"error": "Job not found"})

        # Formats the DynamoDB response (which is complex) into a simple JSON
        item = {k: list(v.values())[0] for k, v in response['Item'].items()}

        return create_response(200, item)

    except ClientError as e:
        logger.error(f"Boto3 error (get_vpc_status): {e}")
        return create_response(500, {"error": f"Error querying the job: {e}"})


def create_response(status_code, body):
    """
    Utility function for creating API Gateway (Lambda Proxy) responses.
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body)
    }