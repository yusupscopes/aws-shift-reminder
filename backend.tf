terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-shift-reminder"
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}