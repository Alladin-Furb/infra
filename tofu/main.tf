# ─── Resource Group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# ─── Container Registry ───────────────────────────────────────────────────────

resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# ─── Container Apps Environment ───────────────────────────────────────────────

resource "azurerm_container_app_environment" "main" {
  name                = "infra-env"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# ─── auth-service ─────────────────────────────────────────────────────────────

resource "azurerm_container_app" "auth_service" {
  name                         = "auth-service"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  ingress {
    external_enabled = false
    target_port      = 8081
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "auth-service"
      image  = "${azurerm_container_registry.main.login_server}/auth-service:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SPRING_DATASOURCE_URL"
        value = var.auth_db_url
      }
      env {
        name  = "SPRING_DATASOURCE_USERNAME"
        value = var.db_user
      }
      env {
        name  = "SPRING_DATASOURCE_PASSWORD"
        value = var.db_password
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
      env {
        name  = "JWT_EXPIRATION"
        value = tostring(var.jwt_expiration)
      }
    }

    min_replicas = 0
    max_replicas = 3
  }
}

# ─── presenca-service ─────────────────────────────────────────────────────────

resource "azurerm_container_app" "presenca_service" {
  name                         = "presenca-service"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  ingress {
    external_enabled = false
    target_port      = 8082
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "presenca-service"
      image  = "${azurerm_container_registry.main.login_server}/presenca-service:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SPRING_DATASOURCE_URL"
        value = var.presenca_db_url
      }
      env {
        name  = "SPRING_DATASOURCE_USERNAME"
        value = var.presenca_db_user
      }
      env {
        name  = "SPRING_DATASOURCE_PASSWORD"
        value = var.presenca_db_password
      }
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "prod"
      }
      env {
        name  = "RABBITMQ_HOST"
        value = var.rabbitmq_host
      }
      env {
        name  = "RABBITMQ_PORT"
        value = tostring(var.rabbitmq_port)
      }
      env {
        name  = "RABBITMQ_USERNAME"
        value = var.rabbitmq_username
      }
      env {
        name  = "RABBITMQ_PASSWORD"
        value = var.rabbitmq_password
      }
    }

    min_replicas = 0
    max_replicas = 3
  }
}

# ─── register-adm-service ─────────────────────────────────────────────────────

resource "azurerm_container_app" "register_adm_service" {
  name                         = "register-adm-service"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  ingress {
    external_enabled = false
    target_port      = 8084
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "register-adm-service"
      image  = "${azurerm_container_registry.main.login_server}/register-adm-service:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "RABBITMQ_HOST"
        value = var.rabbitmq_host
      }
      env {
        name  = "RABBITMQ_PORT"
        value = tostring(var.rabbitmq_port)
      }
      env {
        name  = "RABBITMQ_USERNAME"
        value = var.rabbitmq_username
      }
      env {
        name  = "RABBITMQ_PASSWORD"
        value = var.rabbitmq_password
      }
    }

    min_replicas = 0
    max_replicas = 3
  }
}

# ─── relatorio-service ────────────────────────────────────────────────────────

resource "azurerm_container_app" "relatorio_service" {
  name                         = "relatorio-service"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "relatorio-service"
      image  = "${azurerm_container_registry.main.login_server}/relatorio-service:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ConnectionStrings__RelatoriosDb"
        value = var.relatorio_db_url
      }
      env {
        name  = "PresencaService__BaseUrl"
        value = "http://presenca-service"
      }
      env {
        name  = "RabbitMQ__Host"
        value = var.rabbitmq_host
      }
      env {
        name  = "RabbitMQ__Port"
        value = tostring(var.rabbitmq_port)
      }
      env {
        name  = "RabbitMQ__Username"
        value = var.rabbitmq_username
      }
      env {
        name  = "RabbitMQ__Password"
        value = var.rabbitmq_password
      }
    }

    min_replicas = 0
    max_replicas = 3
  }
}

# ─── api-gateway ──────────────────────────────────────────────────────────────

resource "azurerm_container_app" "api_gateway" {
  name                         = "api-gateway"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "api-gateway"
      image  = "${azurerm_container_registry.main.login_server}/api-gateway:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AUTH_SERVICE_URL"
        value = "http://auth-service"
      }
      env {
        name  = "PRESENCA_SERVICE_URL"
        value = "http://presenca-service"
      }
      env {
        name  = "RELATORIO_SERVICE_URL"
        value = "http://relatorio-service"
      }
      env {
        name  = "REGISTER_ADM_SERVICE_URL"
        value = "http://register-adm-service"
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
    }

    min_replicas = 0
    max_replicas = 3
  }
}

# ─── deploy-webhook ───────────────────────────────────────────────────────────

resource "azurerm_container_app" "deploy_webhook" {
  name                         = "deploy-webhook"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.deploy.id]
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "deploy-webhook"
      image  = "${azurerm_container_registry.main.login_server}/deploy-webhook:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "ACR_SERVER"
        value = azurerm_container_registry.main.login_server
      }
      env {
        name  = "RESOURCE_GROUP"
        value = var.resource_group_name
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.deploy.client_id
      }
      env {
        name  = "AZURE_SUBSCRIPTION_ID"
        value = var.subscription_id
      }
    }

    min_replicas = 1
    max_replicas = 1
  }
}

# ─── Managed Identity para deploy-webhook ─────────────────────────────────────

resource "azurerm_user_assigned_identity" "deploy" {
  name                = "deploy-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "deploy_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}
