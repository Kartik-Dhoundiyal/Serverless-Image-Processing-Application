#!/bin/bash

# Set variables
export TF_VAR_subscription_id="<your_subscription_id>"
export TF_VAR_client_id="<your_client_id>"
export TF_VAR_client_secret="<your_client_secret>"
export TF_VAR_tenant_id="<your_tenant_id>"
export TF_VAR_resource_group_name="<your_resource_group_name>"
export TF_VAR_location="<your_location>"
export TF_VAR_app_service_plan_id="<your_app_service_plan_id>"

# Initialize Terraform
terraform init

# Preview the changes
terraform plan

# Apply the changes
terraform apply

# Unset variables
unset TF_VAR_subscription_id
unset TF_VAR_client_id
unset TF_VAR_client_secret
unset TF_VAR_tenant_id
unset TF_VAR_resource_group_name
unset TF_VAR_location
unset TF_VAR_app_service_plan_id
