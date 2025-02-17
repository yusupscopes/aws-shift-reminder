# main.tf
# S3 Bucket
resource "aws_s3_bucket" "shift_bucket" {
  bucket = "shift-schedule-reminder"
}

resource "aws_s3_bucket_notification" "s3_lambda_trigger" {
  bucket = aws_s3_bucket.shift_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_json.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# DynamoDB Table
resource "aws_dynamodb_table" "shift_schedules" {
  name           = "ShiftSchedules"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "date"

  attribute {
    name = "date"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "lambda_logs" {
  name = "lambda_logs_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# S3 Access Policy
resource "aws_iam_role_policy" "lambda_s3" {
  name = "lambda_s3_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.shift_bucket.arn,
          "${aws_s3_bucket.shift_bucket.arn}/*"
        ]
      }
    ]
  })
}

# DynamoDB Access Policy
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:BatchWriteItem"
        ]
        Resource = aws_dynamodb_table.shift_schedules.arn
      }
    ]
  })
}

# Process JSON Lambda Function
resource "aws_lambda_function" "process_json" {
  filename         = "process_json_lambda.zip"
  function_name    = "process_json_lambda"
  role            = aws_iam_role.lambda_exec.arn
  handler         = "process_json_lambda.lambda_handler"
  runtime         = "python3.13"

   # This will force an update when the zip contents change
  source_code_hash = filebase64sha256("process_json_lambda.zip")

  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_iam_role_policy.lambda_s3,
    aws_iam_role_policy.lambda_dynamodb
  ]
}

# Reminder Lambda Function
resource "aws_lambda_function" "reminder" {
  filename         = "reminder_lambda.zip"
  function_name    = "reminder_lambda"
  role            = aws_iam_role.lambda_exec.arn
  handler         = "reminder_lambda.lambda_handler"
  runtime         = "python3.13"

   # This will force an update when the zip contents change
  source_code_hash = filebase64sha256("reminder_lambda.zip")

  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_iam_role_policy.lambda_dynamodb
  ]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "process_json_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_json.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "reminder_logs" {
  name              = "/aws/lambda/${aws_lambda_function.reminder.function_name}"
  retention_in_days = 7
}

# EventBridge (CloudWatch Events) Rule
resource "aws_cloudwatch_event_rule" "reminder_schedule" {
  name                = "reminder-schedule"
  description         = "Schedule for sending shift reminders"
  schedule_expression = "cron(0 13 * * ? *)"  # 1 PM UTC every day
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "reminder_lambda_target" {
  rule      = aws_cloudwatch_event_rule.reminder_schedule.name
  target_id = "SendReminders"
  arn       = aws_lambda_function.reminder.arn
}

# Lambda Permissions
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_json.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.shift_bucket.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reminder.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reminder_schedule.arn
}

# Provider Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"  # Change this to your desired region
}