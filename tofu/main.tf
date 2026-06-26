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
  name                = "infra-${var.environment}-env"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# ─── Storage (Azure Files) para persistência dos bancos ───────────────────────

resource "azurerm_storage_account" "db_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "mariadb_data" {
  name               = "mariadb-data"
  storage_account_id = azurerm_storage_account.db_storage.id
  quota              = 5
}

resource "azurerm_storage_share" "relatorio_db_data" {
  name               = "relatorio-db-data"
  storage_account_id = azurerm_storage_account.db_storage.id
  quota              = 5
}

# Montagem dos shares no Container Apps Environment ─────────────────────────────

resource "azurerm_container_app_environment_storage" "mariadb_data" {
  name                         = "mariadb-data"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.db_storage.name
  share_name                   = azurerm_storage_share.mariadb_data.name
  access_key                   = azurerm_storage_account.db_storage.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "relatorio_db_data" {
  name                         = "relatorio-db-data"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.db_storage.name
  share_name                   = azurerm_storage_share.relatorio_db_data.name
  access_key                   = azurerm_storage_account.db_storage.primary_access_key
  access_mode                  = "ReadWrite"
}

# ─── Bancos de dados (módulo mariadb-app) ─────────────────────────────────────

module "mariadb" {
  source              = "./modules/mariadb-app"
  name                = "mariadb"
  environment_id      = azurerm_container_app_environment.main.id
  resource_group_name = azurerm_resource_group.main.name
  root_password       = var.db_root_password
  password            = var.db_password
  db_name             = var.db_name
  db_user             = var.db_user
  env_storage_name    = azurerm_container_app_environment_storage.mariadb_data.name
}

module "relatorio_db" {
  source              = "./modules/mariadb-app"
  name                = "relatorio-db"
  environment_id      = azurerm_container_app_environment.main.id
  resource_group_name = azurerm_resource_group.main.name
  root_password       = var.relatorio_db_password
  password            = var.relatorio_db_password
  db_name             = var.relatorio_db_name
  db_user             = var.relatorio_db_user
  env_storage_name    = azurerm_container_app_environment_storage.relatorio_db_data.name
}

# RabbitMQ: usa serviço externo (CloudAMQP, free tier 1M msgs/mês).
# Conexão injetada via var.rabbitmq_url nas variáveis dos serviços.
# Redis: usa Upstash externo por TLS. A connection string é injetada como
# variável sensível e armazenada como secret do Container App do Report.

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
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
      env {
        name  = "JWT_EXPIRATION"
        value = tostring(var.jwt_expiration)
      }
      env {
        name  = "REGISTER_ADM_SERVICE_URL"
        value = "http://register-adm-service"
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 8081
        path                    = "/actuator/health"
        initial_delay           = 30
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }
    }

    min_replicas = 1
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
        value = var.presenca_db_username
      }
      env {
        name  = "SPRING_DATASOURCE_PASSWORD"
        value = var.presenca_db_password
      }
      env {
        name  = "SPRING_DATASOURCE_MAX_POOL_SIZE"
        value = "3"
      }
      env {
        name  = "SPRING_DATASOURCE_MIN_IDLE"
        value = "1"
      }
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "prod"
      }
      env {
        name  = "SPRING_RABBITMQ_ADDRESSES"
        value = var.rabbitmq_url
      }
      env {
        name  = "SPRING_RABBITMQ_SSL_ENABLED"
        value = "true"
      }
      env {
        name  = "JAVA_TOOL_OPTIONS"
        value = "-Djava.net.preferIPv4Stack=true"
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 8082
        path                    = "/actuator/health"
        initial_delay           = 30
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }
    }

    min_replicas = 1
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
        name  = "SPRING_DATASOURCE_URL"
        value = var.register_adm_db_url
      }
      env {
        name  = "SPRING_RABBITMQ_ADDRESSES"
        value = var.rabbitmq_url
      }
      env {
        name  = "SPRING_RABBITMQ_SSL_ENABLED"
        value = "true"
      }
      env {
        name  = "JAVA_TOOL_OPTIONS"
        value = "-Djava.net.preferIPv4Stack=true"
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 8084
        path                    = "/actuator/health"
        initial_delay           = 30
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }
    }

    min_replicas = 1
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
  secret {
    name  = "report-db-connection"
    value = "Server=relatorio-db;Port=3306;Database=${var.relatorio_db_name};User=${var.relatorio_db_user};Password=${var.relatorio_db_password};SslMode=Disabled"
  }

  secret {
    name  = "rabbitmq-url"
    value = var.rabbitmq_url
  }
  
  secret {
    name  = "redis-connection"
    value = var.upstash_redis_connection_string
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
        name        = "ConnectionStrings__RelatoriosDb"
        secret_name = "report-db-connection"
      }
      env {
        name        = "ConnectionStrings__Redis"
        secret_name = "redis-connection"
      }
      env {
        name        = "RabbitMQ__Url"
        secret_name = "rabbitmq-url"
      }
      env {
        name  = "PresencaService__BaseUrl"
        value = "http://presenca-service"
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 8080
        path                    = "/health/live"
        initial_delay           = 20
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = 8080
        path                    = "/health/ready"
        initial_delay           = 20
        interval_seconds        = 30
        failure_count_threshold = 3
        success_count_threshold = 1
        timeout                 = 5
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  depends_on = [
    module.relatorio_db
  ]
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
        name  = "ROTEIRIZACAO_SERVICE_URL"
        value = "http://route-generator"
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 8080
        path                    = "/actuator/health"
        initial_delay           = 30
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }
    }

    min_replicas = 1
    max_replicas = 3
  }
}

# ─── route-generator ──────────────────────────────────────────────────────────

resource "azurerm_container_app" "route_generator" {
  name                         = "route-generator"
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
      name   = "route-generator"
      image  = "${azurerm_container_registry.main.login_server}/route-generator:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "ConnectionStrings__DefaultConnection"
        value = var.route_gen_db_url
      }

      env {
        name  = "Services__AttendanceBaseUrl"
        value = "http://presenca-service"
      }

      env {
        name  = "Services__RegisterBaseUrl"
        value = "http://register-adm-service"
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 8080
        path                    = "/health"
        initial_delay           = 20
        interval_seconds        = 30
        failure_count_threshold = 3
        timeout                 = 5
      }
    }

    min_replicas = 1
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

# ─── ACR Webhook → deploy-webhook ─────────────────────────────────────────────
# ACR Basic permite só 2 webhooks — usa um único sem scope (dispara para todos
# os repositórios). O deploy-webhook roteia pelo nome do repo no payload.

resource "azurerm_container_registry_webhook" "deploy" {
  name                = "deployall"
  resource_group_name = azurerm_resource_group.main.name
  registry_name       = azurerm_container_registry.main.name
  location            = azurerm_resource_group.main.location

  service_uri = "https://${azurerm_container_app.deploy_webhook.ingress[0].fqdn}"
  status      = "enabled"
  scope       = ""
  actions     = ["push"]
}
