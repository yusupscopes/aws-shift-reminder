# reminder_lambda.py
from datetime import datetime, timedelta
import json
import boto3
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
sns_client = boto3.client("sns", region_name=os.environ["AWS_REGION"])
table = dynamodb.Table(os.environ["DYNAMODB_TABLE_NAME"])

def lambda_handler(event, context):
    """Check tomorrow's shift and send a reminder"""
    logger.info("Checking shift schedule for tomorrow.")
    
    tomorrow = (datetime.utcnow() + timedelta(days=1)).strftime("%Y-%m-%d")
    
    response = table.get_item(Key={"date": tomorrow})
    shift_info = response.get("Item")

    if shift_info:
        shift = shift_info["shift"]
        message_subject = f"Reminder: Your Shift for {tomorrow}"
        message_body = f"Your shift for {tomorrow} is: {shift}."

        logger.info(f"Sending reminder notification for {tomorrow}: {shift}")

        sns_client.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Message=message_body,
            Subject=message_subject
        )
    
    return {"statusCode": 200, "body": json.dumps({"message": "Reminder sent!"})}
