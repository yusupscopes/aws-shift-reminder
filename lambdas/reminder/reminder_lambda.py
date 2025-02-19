# reminder_lambda.py
from datetime import datetime, timedelta
import json
import boto3
import logging
import os
from zoneinfo import ZoneInfo

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
sns_client = boto3.client("sns", region_name=os.environ["AWS_REGION"])
table = dynamodb.Table(os.environ["DYNAMODB_TABLE_NAME"])

def lambda_handler(event, context):
    """Check today's and tomorrow's shifts and send a combined reminder"""
    logger.info("Checking shift schedule for today and tomorrow.")
    
    # Get dates in GMT+7
    tz = ZoneInfo("Asia/Bangkok")
    now = datetime.now(tz)
    today = now.strftime("%Y-%m-%d")
    tomorrow = (now + timedelta(days=1)).strftime("%Y-%m-%d")
    
    # Get today's shift
    today_response = table.get_item(Key={"date": today})
    today_shift = today_response.get("Item", {}).get("shift", "No shift scheduled")
    
    # Get tomorrow's shift
    tomorrow_response = table.get_item(Key={"date": tomorrow})
    tomorrow_shift = tomorrow_response.get("Item", {}).get("shift", "No shift scheduled")

    # Prepare the combined message
    message_subject = f"Shift Schedule for {today} and {tomorrow}"
    message_body = (
        f"Today's shift ({today}): {today_shift}\n"
        f"Tomorrow's shift ({tomorrow}): {tomorrow_shift}"
    )

    logger.info(f"Sending combined shift notification for {today} and {tomorrow}")

    sns_client.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Message=message_body,
        Subject=message_subject
    )
    
    return {"statusCode": 200, "body": json.dumps({"message": "Reminder sent!"})}