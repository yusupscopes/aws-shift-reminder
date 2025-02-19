# AWS Shift Reminder

An automated system for managing and sending shift schedule reminders using AWS services.

## Architecture
- S3 bucket for storing shift schedules
- Lambda functions for processing schedules and sending reminders
- DynamoDB for storing shift data
- SNS for sending notifications
- EventBridge for scheduling reminders

## Prerequisites
- AWS CLI configured
- Terraform installed
- Python 3.x
- Make

## Setup
1. Create remote state infrastructure:
```
make init-remote-state
```
2. Initialize development environment:
```
make init
```
3. Deploy the infrastructure:
```
make deploy
```

## Usage
1. Prepare shift schedule in JSON format (see `scripts/shifts.json`)
2. Upload using the test script:
```
export S3_BUCKET_NAME="your-bucket-name"
python scripts/test_upload.py
```

## Development
- `make format` - Format Python code
- `make lint` - Run linter
- `make test` - Run tests
- `make clean` - Clean build artifacts