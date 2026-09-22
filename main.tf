terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    # storage account + RG injected via -backend-config in the workflow
    container_name   = "tfstate"
    key              = "app.tfstate"
    use_oidc         = true
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
  # subscription/tenant/client come from ARM_* env vars set in the workflow.
  # RP registration is the platform's job (provision.sh pre-flight); this
  # identity is RG-scoped and cannot perform subscription-level registration.
  resource_provider_registrations = "none"
}

data "azurerm_resource_group" "me" {
  name = var.resource_group_name
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "law-${var.app_name}"
  location            = data.azurerm_resource_group.me.location
  resource_group_name = data.azurerm_resource_group.me.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "cae-${var.app_name}"
  location                   = data.azurerm_resource_group.me.location
  resource_group_name        = data.azurerm_resource_group.me.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  # Azure adds this profile to every new environment. Declared here so that
  # every plan does not show a phantom "1 to change" removing it -- students
  # are told to read the plan, so it must show only their own changes.
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "app" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.me.name
  revision_mode                = "Multiple" # enables blue/green traffic splitting

  template {
    min_replicas = 0 # scale to zero: costs nothing while nobody is looking
    max_replicas = 1
    container {
      name  = "web"
      image = var.image
      # busybox httpd serving $GREETING as plaintext; the escaped \$GREETING
      # must reach the container shell literally (runtime env expands it).
      command = ["sh", "-c", "mkdir -p /www && echo \"$GREETING\" > /www/index.html && httpd -f -p 8080 -h /www"]
      cpu     = 0.25
      memory  = "0.5Gi"
      env {
        name  = "GREETING"
        value = var.greeting
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
