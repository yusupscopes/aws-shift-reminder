# terraform/main.tf
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
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_json.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.shift_bucket.arn
}

resource "aws_dynamodb_table" "shift_schedules" {
  name           = "ShiftSchedules"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "date"

  attribute {
    name = "date"
    type = "S"
  }
}

resource "aws_lambda_function" "process_json" {
  function_name    = "process_json_lambda"
  handler         = "process_json_lambda.lambda_handler"
  runtime         = "python3.13"
  role            = aws_iam_role.lambda_exec.arn
  filename        = "lambda_function.zip"
}

resource "aws_lambda_function" "reminder" {
  function_name    = "reminder_lambda"
  handler         = "reminder_lambda.lambda_handler"
  runtime         = "python3.13"
  role            = aws_iam_role.lambda_exec.arn
  filename        = "lambda_function.zip"
}

resource "aws_cloudwatch_log_group" "process_json_logs" {
  name              = "/aws/lambda/${aws_lambda_function.process_json.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "reminder_logs" {
  name              = "/aws/lambda/${aws_lambda_function.reminder.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_event_rule" "reminder_schedule" {
  name                = "reminder-schedule"
  schedule_expression = "cron(0 13 * * ? *)"  # 1 PM UTC every day
}

resource "aws_cloudwatch_event_target" "reminder_lambda_target" {
  rule      = aws_cloudwatch_event_rule.reminder_schedule.name
  arn       = aws_lambda_function.reminder.arn
}
