provider "azurerm" {
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

module "storage_account" {
  source              = "Azure/storage-account/azurerm"
  resource_group_name = var.resource_group_name
  account_name        = "imagestorage${random_integer.random.result}"
  location            = var.location
  account_tier        = "Standard"
  account_replication = "LRS"
}

module "function_app" {
  source              = "Azure/function-app/azurerm"
  resource_group_name = var.resource_group_name
  app_name            = "imageprocessing${random_integer.random.result}"
  location            = var.location
  os_type             = "linux"
  runtime_stack       = "dotnet"
  version             = "~3"
  app_service_plan_id  = var.app_service_plan_id
  app_settings = {
    "AzureWebJobsStorage"   = module.storage_account.primary_connection_string
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
  }
}

module "application_insights" {
  source              = "Azure/application-insights/azurerm"
  resource_group_name = var.resource_group_name
  name                = "imageprocessing${random_integer.random.result}"
  location            = var.location
}

module "blob_trigger" {
  source                       = "Azure/blob-trigger/azurerm"
  storage_account_connection_string = module.storage_account.primary_connection_string
  function_app_name            = module.function_app.name
  name                         = "image-blob-trigger"
  container_name               = "images"
  direction                    = "in"
  path                         = "{name}"
}

resource "random_integer" "random" {
  min = 100000
  max = 999999
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function_app_code"
  output_path = "${path.module}/function_app_code.zip"
}

module "function_zip" {
  source              = "Azure/function-app-zip/azurerm"
  resource_group_name = var.resource_group_name
  function_app_name   = module.function_app.name
  content             = data.archive_file.function_zip.output_path
}

output "function_app_url" {
  value = module.function_app.default_hostname
}
