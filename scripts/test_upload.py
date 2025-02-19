import boto3
import os
from pathlib import Path

# Get configuration from environment variables
BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
AWS_REGION = os.environ.get('AWS_REGION', 'ap-southeast-1')

def upload_shifts():
    if not BUCKET_NAME:
        raise ValueError("S3_BUCKET_NAME environment variable is not set")

    # Initialize S3 client
    s3_client = boto3.client('s3', region_name=AWS_REGION)
    
    # Get the path to shifts.json
    current_dir = Path(__file__).parent
    shifts_file = current_dir / 'shifts.json'
    
    # Upload the file
    try:
        s3_client.upload_file(
            str(shifts_file),
            BUCKET_NAME,
            'shifts.json'
        )
        print(f"Successfully uploaded shifts.json to {BUCKET_NAME}")
    except Exception as e:
        print(f"Error uploading file: {str(e)}")

if __name__ == "__main__":
    upload_shifts()


