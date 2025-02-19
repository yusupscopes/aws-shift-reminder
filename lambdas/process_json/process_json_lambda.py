# process_json_lambda.py
import json
import boto3
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE_NAME"])
s3_client = boto3.client("s3")

def lambda_handler(event, context):
    """Triggered when a JSON file is uploaded to S3"""
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        record = event["Records"][0]
        bucket_name = record["s3"]["bucket"]["name"]
        object_key = record["s3"]["object"]["key"]

        logger.info(f"Processing file: {object_key} from bucket: {bucket_name}")

        # Download JSON file from S3
        local_path = f"/tmp/{object_key}"
        s3_client.download_file(bucket_name, object_key, local_path)

        # Read JSON data
        with open(local_path, "r") as file:
            raw_data = file.read()  # Read the raw data
            logger.info(f"Raw JSON data: {raw_data}")  # Log the raw data
            data = json.loads(raw_data)  # Use json.loads to parse the raw data

        # Store shifts in DynamoDB
        with table.batch_writer() as batch:
            for shift in data["shifts"]:
                batch.put_item(Item={"date": shift["date"], "shift": shift["shift"]})

        logger.info("Shifts stored successfully in DynamoDB.")
        
        return {"statusCode": 200, "body": json.dumps({"message": "Shifts stored successfully!"})}

    except Exception as e:
        logger.error(f"Error processing file: {str(e)}", exc_info=True)
        return {"statusCode": 500, "body": json.dumps({"message": "Error processing file!"})}