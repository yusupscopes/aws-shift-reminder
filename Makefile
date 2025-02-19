# Variables
PYTHON_VERSION = python3
REGION = ap-southeast-1
VENV_NAME = venv
PROCESS_JSON_DIR = lambdas/process_json
REMINDER_DIR = lambdas/reminder
TERRAFORM_STATE_BUCKET = terraform-state-bucket-shift-reminder
TERRAFORM_STATE_LOCK_TABLE = terraform-state-lock

# Colors for better visibility
YELLOW := \033[1;33m
GREEN := \033[1;32m
NC := \033[0m # No Color

.PHONY: all clean deploy package-all test init help

# Default target
all: init package-all deploy

help:
	@echo "$(YELLOW)Available commands:$(NC)"
	@echo "  make init-remote-state - Set up S3 bucket and DynamoDB table for Terraform remote state"
	@echo "  make init          - Initialize virtual environment and install dependencies"
	@echo "  make clean         - Remove all build files and virtual environments"
	@echo "  make package-all   - Package both Lambda functions with dependencies"
	@echo "  make deploy        - Deploy using Terraform"
	@echo "  make all           - Run init, package-all, and deploy"
	@echo "  make test          - Run Python tests"
	@echo "  make package-process-json - Package only the process_json Lambda"
	@echo "  make package-reminder     - Package only the reminder Lambda"
	@echo "  make format        - Format Python code using black"
	@echo "  make lint          - Run pylint on Python code"

# Initialize development environment
init-remote-state:
	@echo "$(YELLOW)Setting up remote state infrastructure...$(NC)"
	aws s3api create-bucket \
		--bucket $(TERRAFORM_STATE_BUCKET) \
		--region $(REGION) \
		--create-bucket-configuration LocationConstraint=$(REGION)
	aws s3api put-bucket-versioning \
		--bucket $(TERRAFORM_STATE_BUCKET) \
		--versioning-configuration Status=Enabled
	aws s3api put-bucket-encryption \
		--bucket $(TERRAFORM_STATE_BUCKET) \
		--server-side-encryption-configuration \
		'{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
	aws dynamodb create-table \
		--table-name $(TERRAFORM_STATE_LOCK_TABLE) \
		--attribute-definitions AttributeName=LockID,AttributeType=S \
		--key-schema AttributeName=LockID,KeyType=HASH \
		--provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
		--region $(REGION)
	@echo "$(GREEN)Remote state infrastructure setup complete!$(NC)"

init:
	@echo "$(YELLOW)Initializing development environment...$(NC)"
	@if [ ! -d "$(VENV_NAME)" ]; then \
		$(PYTHON_VERSION) -m venv $(VENV_NAME); \
	fi
	@. ./$(VENV_NAME)/bin/activate && \
		pip install --upgrade pip && \
		pip install -r $(PROCESS_JSON_DIR)/requirements.txt && \
		pip install -r $(REMINDER_DIR)/requirements.txt && \
		pip install black pylint pytest
	@echo "$(GREEN)Initialization complete!$(NC)"

# Clean build files and virtual environments
clean:
	@echo "$(YELLOW)Cleaning up...$(NC)"
	rm -rf $(VENV_NAME)
	rm -rf $(PROCESS_JSON_DIR)/package
	rm -rf $(REMINDER_DIR)/package
	rm -f process_json_lambda.zip
	rm -f reminder_lambda.zip
	rm -rf __pycache__
	rm -rf .pytest_cache
	@echo "$(GREEN)Clean up complete!$(NC)"

# Package process_json Lambda
package-process-json:
	@echo "$(YELLOW)Packaging process_json Lambda...$(NC)"
	@mkdir -p $(PROCESS_JSON_DIR)/package
	@cd $(PROCESS_JSON_DIR) && \
		pip install --target ./package -r requirements.txt && \
		cd package && \
		zip -r ../process_json_lambda.zip . && \
		cd .. && \
		zip -g process_json_lambda.zip process_json_lambda.py && \
		mv process_json_lambda.zip ../../
	@echo "$(GREEN)process_json Lambda packaged!$(NC)"

# Package reminder Lambda
package-reminder:
	@echo "$(YELLOW)Packaging reminder Lambda...$(NC)"
	@mkdir -p $(REMINDER_DIR)/package
	@cd $(REMINDER_DIR) && \
		pip install --target ./package -r requirements.txt && \
		cd package && \
		zip -r ../reminder_lambda.zip . && \
		cd .. && \
		zip -g reminder_lambda.zip reminder_lambda.py && \
		mv reminder_lambda.zip ../../
	@echo "$(GREEN)reminder Lambda packaged!$(NC)"

# Package all Lambdas
package-all: package-process-json package-reminder
	@echo "$(GREEN)All Lambdas packaged successfully!$(NC)"

# Deploy using Terraform
deploy:
	@echo "$(YELLOW)Deploying with Terraform...$(NC)"
	terraform init
	terraform plan
	terraform apply -auto-approve
	@echo "$(GREEN)Deployment complete!$(NC)"

# Run tests
test:
	@echo "$(YELLOW)Running tests...$(NC)"
	@. ./$(VENV_NAME)/bin/activate && \
		pytest tests/
	@echo "$(GREEN)Tests complete!$(NC)"

# Format code
format:
	@echo "$(YELLOW)Formatting Python code...$(NC)"
	@. ./$(VENV_NAME)/bin/activate && \
		black $(PROCESS_JSON_DIR)/*.py $(REMINDER_DIR)/*.py
	@echo "$(GREEN)Formatting complete!$(NC)"

# Lint code
lint:
	@echo "$(YELLOW)Linting Python code...$(NC)"
	@. ./$(VENV_NAME)/bin/activate && \
		pylint $(PROCESS_JSON_DIR)/*.py $(REMINDER_DIR)/*.py
	@echo "$(GREEN)Linting complete!$(NC)"

# Watch for changes and rebuild
watch:
	@echo "$(YELLOW)Watching for changes...$(NC)"
	@while true; do \
		inotifywait -e modify -r $(PROCESS_JSON_DIR) $(REMINDER_DIR); \
		make package-all; \
	done