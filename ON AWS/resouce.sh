#!/bin/bash

# Set AWS CLI configuration variables
export AWS_ACCESS_KEY_ID=<your-access-key-id>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
export AWS_DEFAULT_REGION=<your-region>

# Create S3 buckets
aws s3api create-bucket 
--bucket my-image-input-bucket

aws s3api create-bucket 
--bucket my-image-output-bucket

# Create IAM Role for Lambda function
aws iam create-role --role-name my-lambda-role --assume-role-policy-document file://lambda-trust-policy.json
aws iam attach-role-policy --role-name my-lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam attach-role-policy --role-name my-lambda-role --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name my-lambda-role --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# Create Lambda function
zip -r my-lambda-function.zip my-lambda-function.py
aws lambda create-function --function-name my-lambda-function --runtime python3.8 --role arn:aws:iam::123456789012:role/my-lambda-role --handler my-lambda-function.lambda_handler --zip-file fileb://my-lambda-function.zip
aws lambda create-event-source-mapping --event-source-arn arn:aws:s3:::my-image-input-bucket --function-name my-lambda-function --batch-size 1

# Create API Gateway
aws apigateway create-rest-api --name my-image-processing-api
aws apigateway get-resources --rest-api-id <rest-api-id> --region <region> | jq '.items[] | select(.path == "/").id' | xargs -I {} aws apigateway create-resource --rest-api-id <rest-api-id> --parent-id {} --path-part image
aws apigateway put-method --rest-api-id <rest-api-id> --resource-id <resource-id> --http-method POST --authorization-type "NONE"
aws apigateway put-integration --rest-api-id <rest-api-id> --resource-id <resource-id> --http-method POST --type AWS --integration-http-method POST --uri arn:aws:apigateway:<region>:lambda:path/2015-03-31/functions/arn:aws:lambda:<region>:<account-id>:function:my-lambda-function/invocations --passthrough-behavior WHEN_NO_MATCH --credentials arn:aws:iam::123456789012:role/my-lambda-role
aws apigateway put-method-response --rest-api-id <rest-api-id> --resource-id <resource-id> --http-method POST --status-code 200 --response-models "{}"
aws apigateway put-integration-response --rest-api-id <rest-api-id> --resource-id <resource-id> --http-method POST --status-code 200 --response-templates "{\"application/json\": \"\"}"
aws apigateway create-deployment --rest-api-id <rest-api-id> --stage-name prod

# Clean up
rm my-lambda-function.zip

