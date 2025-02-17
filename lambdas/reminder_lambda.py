# reminder_lambda.py
from datetime import datetime, timedelta
import json
import boto3
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
ses_client = boto3.client("ses", region_name="us-east-1")  # Adjust AWS region
table = dynamodb.Table("ShiftSchedules")

SENDER_EMAIL = "your-email@example.com"
RECIPIENT_EMAIL = "recipient@example.com"

def lambda_handler(event, context):
    """Check tomorrow's shift and send a reminder"""
    logger.info("Checking shift schedule for tomorrow.")
    
    tomorrow = (datetime.utcnow() + timedelta(days=1)).strftime("%Y-%m-%d")
    
    response = table.get_item(Key={"date": tomorrow})
    shift_info = response.get("Item")

    if shift_info:
        shift = shift_info["shift"]
        email_subject = f"Reminder: Your Shift for {tomorrow}"
        email_body = f"Your shift for {tomorrow} is: {shift}."

        logger.info(f"Sending reminder email for {tomorrow}: {shift}")

        ses_client.send_email(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [RECIPIENT_EMAIL]},
            Message={
                "Subject": {"Data": email_subject},
                "Body": {"Text": {"Data": email_body}},
            },
        )
    
    return {"statusCode": 200, "body": json.dumps({"message": "Reminder sent!"})}
