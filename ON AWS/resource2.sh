#!/bin/bash

# set the AWS region
aws configure set region <your-region>

# create an S3 bucket for image input
aws s3api create-bucket 
    --bucket my-image-input-bucket 
    --region <your-region> 
    --create-bucket-configuration LocationConstraint=<your-region>

# create a Rekognition collection
aws rekognition create-collection --collection-id my-face-collection

# create an IAM role for the Lambda function
aws iam create-role 
--role-name my-lambda-role 
--assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# create an IAM policy for the Lambda function
cat > policy.json << EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:s3:::my-image-input-bucket/*"
        },
        {
            "Action": [
                "rekognition:DetectLabels",
                "rekognition:DetectFaces"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOL

# create the IAM policy
aws iam create-policy --policy-name my-lambda-policy --policy-document file://policy.json

# attach the IAM policy to the IAM role
aws iam attach-role-policy --role-name my-lambda-role --policy-arn <policy-arn>

# create the Lambda function
cat > lambda_function.py << EOL
import boto3

rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    print('Received event:', event)
    
    # get the S3 bucket and key from the event
    s3_bucket = event['Records'][0]['s3']['bucket']['name']
    s3_key = event['Records'][0]['s3']['object']['key']
    
    # analyze the image using Rekognition
    response = rekognition.detect_labels(
        Image={
            'S3Object': {
                'Bucket': s3_bucket,
                'Name': s3_key
            }
        }
    )
    
    # print the labels
    print('Labels:')
    for label in response['Labels']:
        print(f"{label['Name']} ({label['Confidence']:.2f}%)")

    return {
        'statusCode': 200,
        'body': 'Image processed successfully'
    }
EOL

zip lambda_function.zip lambda_function.py

aws lambda create-function --function-name my-lambda-function --runtime python3.8 --role <role-arn> --handler lambda_function.lambda_handler --zip-file fileb://lambda_function.zip


# create an S3 trigger for the Lambda function
aws lambda create-event-source-mapping --function-name my-lambda-function --batch-size 1 --event-source-arn arn:aws:s3:::my-image-input-bucket --starting-position LATEST
# create an API Gateway REST API
rest_api_id=$(aws apigateway create-rest-api --name my-rest-api --region <your-region> --query 'id' --output text)

# create a resource for the API
resource_id=$(aws apigateway create-resource --rest-api-id $rest_api_id --path-part rekognition --query 'id' --output text)

# create a POST method for the resource
aws apigateway put-method --rest-api-id $rest_api_id --resource-id $resource_id --http-method POST --authorization-type NONE --request-parameters method.request.querystring.imageId=false

# integrate the method with the Lambda function
aws apigateway put-integration --rest-api-id $rest_api_id --resource-id $resource_id --http-method POST --type AWS --integration-http-method POST --uri arn:aws:apigateway:<your-region>:lambda:path/2015-03-31/functions/arn:aws:lambda:<your-region>:<your-account-id>:function:my-lambda-function/invocations --passthrough-behavior WHEN_NO_MATCH --request-templates '{"application/json":"{\"body\": $input.json(\"$\")}"}'

# create a deployment for the API
aws apigateway create-deployment --rest-api-id $rest_api_id --stage-name prod

# get the base URL of the deployed API
base_url=$(aws apigateway get-stage --rest-api-id $rest_api_id --stage-name prod --query 'invokeUrl' --output text)
echo "API Gateway URL: $base_url/rekognition"



# clean up temporary files
rm policy.json lambda_function.py lambda_function.zip
