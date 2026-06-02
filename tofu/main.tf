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

resource "azurerm_storage_share" "presenca_db_data" {
  name               = "presenca-db-data"
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

resource "azurerm_container_app_environment_storage" "presenca_db_data" {
  name                         = "presenca-db-data"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.db_storage.name
  share_name                   = azurerm_storage_share.presenca_db_data.name
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

# ─── mariadb (auth-service) ───────────────────────────────────────────────────
# Banco interno acessível por outros apps via "mariadb:3306".

resource "azurerm_container_app" "mariadb" {
  name                         = "mariadb"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  ingress {
    external_enabled = false
    exposed_port     = 3306
    target_port      = 3306
    transport        = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "db-root-password"
    value = var.db_root_password
  }
  secret {
    name  = "db-password"
    value = var.db_password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "mariadb-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.mariadb_data.name
    }

    container {
      name   = "mariadb"
      image  = "mariadb:11.2"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "MYSQL_ROOT_PASSWORD"
        secret_name = "db-root-password"
      }
      env {
        name  = "MYSQL_DATABASE"
        value = var.db_name
      }
      env {
        name  = "MYSQL_USER"
        value = var.db_user
      }
      env {
        name        = "MYSQL_PASSWORD"
        secret_name = "db-password"
      }

      volume_mounts {
        name = "mariadb-data"
        path = "/var/lib/mysql"
      }
    }
  }
}

# ─── presenca-db (MariaDB) ────────────────────────────────────────────────────
# Acessível via "presenca-db:3306". MariaDB roda OK sobre Azure Files (SMB);
# Postgres não — por isso a presenca-service foi migrada para MariaDB.

resource "azurerm_container_app" "presenca_db" {
  name                         = "presenca-db"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  ingress {
    external_enabled = false
    exposed_port     = 3306
    target_port      = 3306
    transport        = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "presenca-db-root-password"
    value = var.presenca_db_password
  }
  secret {
    name  = "presenca-db-password"
    value = var.presenca_db_password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "presenca-db-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.presenca_db_data.name
    }

    container {
      name   = "presenca-db"
      image  = "mariadb:11.2"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "MYSQL_ROOT_PASSWORD"
        secret_name = "presenca-db-root-password"
      }
      env {
        name  = "MYSQL_DATABASE"
        value = var.presenca_db_name
      }
      env {
        name  = "MYSQL_USER"
        value = var.presenca_db_user
      }
      env {
        name        = "MYSQL_PASSWORD"
        secret_name = "presenca-db-password"
      }

      volume_mounts {
        name = "presenca-db-data"
        path = "/var/lib/mysql"
      }
    }
  }
}

# ─── relatorio-db (MariaDB) ───────────────────────────────────────────────────
# Acessível via "relatorio-db:3306". A relatorio-service (.NET) usa o conector
# MySQL da Oracle, que fala o protocolo MySQL/MariaDB.

resource "azurerm_container_app" "relatorio_db" {
  name                         = "relatorio-db"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  ingress {
    external_enabled = false
    exposed_port     = 3306
    target_port      = 3306
    transport        = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "relatorio-db-root-password"
    value = var.relatorio_db_password
  }
  secret {
    name  = "relatorio-db-password"
    value = var.relatorio_db_password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "relatorio-db-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.relatorio_db_data.name
    }

    container {
      name   = "relatorio-db"
      image  = "mariadb:11.2"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "MYSQL_ROOT_PASSWORD"
        secret_name = "relatorio-db-root-password"
      }
      env {
        name  = "MYSQL_DATABASE"
        value = var.relatorio_db_name
      }
      env {
        name  = "MYSQL_USER"
        value = var.relatorio_db_user
      }
      env {
        name        = "MYSQL_PASSWORD"
        secret_name = "relatorio-db-password"
      }

      volume_mounts {
        name = "relatorio-db-data"
        path = "/var/lib/mysql"
      }
    }
  }
}

# RabbitMQ: usa serviço externo (CloudAMQP, free tier 1M msgs/mês).
# Conexão injetada via var.rabbitmq_url nas variáveis dos serviços.

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
        value = "jdbc:mariadb://mariadb:3306/${var.db_name}"
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
        value = "jdbc:mariadb://presenca-db:3306/${var.presenca_db_name}"
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
        name  = "SPRING_RABBITMQ_ADDRESSES"
        value = var.rabbitmq_url
      }
      env {
        name  = "SPRING_RABBITMQ_SSL_ENABLED"
        value = "true"
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
        name  = "SPRING_RABBITMQ_ADDRESSES"
        value = var.rabbitmq_url
      }
      env {
        name  = "SPRING_RABBITMQ_SSL_ENABLED"
        value = "true"
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
        value = "Server=relatorio-db;Port=3306;Database=${var.relatorio_db_name};User Id=${var.relatorio_db_user};Password=${var.relatorio_db_password};SslMode=Disabled"
      }
      env {
        name  = "PresencaService__BaseUrl"
        value = "http://presenca-service"
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
