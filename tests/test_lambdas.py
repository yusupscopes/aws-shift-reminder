import pytest
from unittest.mock import MagicMock, patch
from lambdas.reminder.reminder_lambda import lambda_handler
from lambdas.process_json.process_json_lambda import lambda_handler as process_handler

def test_reminder_lambda():
    with patch('boto3.resource') as mock_resource, \
         patch('boto3.client') as mock_client:
        # Mock DynamoDB responses
        mock_table = MagicMock()
        mock_table.get_item.side_effect = [
            {'Item': {'shift': 'Morning'}},
            {'Item': {'shift': 'Afternoon'}}
        ]
        mock_resource.return_value.Table.return_value = mock_table
        
        # Test lambda handler
        response = lambda_handler({}, {})
        assert response['statusCode'] == 200

def test_process_json_lambda():
    event = {
        'Records': [{
            's3': {
                'bucket': {'name': 'test-bucket'},
                'object': {'key': 'test.json'}
            }
        }]
    }
    
    with patch('boto3.resource') as mock_resource, \
         patch('boto3.client') as mock_client:
        response = process_handler(event, {})
        assert response['statusCode'] == 200