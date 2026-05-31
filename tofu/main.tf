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

# ─── Storage para dados persistentes (Azure Files) ────────────────────────────

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "mariadb" {
  name               = "mariadb-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 10
}

resource "azurerm_storage_share" "presenca_db" {
  name               = "presenca-db-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 10
}

resource "azurerm_storage_share" "relatorio_db" {
  name               = "relatorio-db-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 10
}

resource "azurerm_storage_share" "rabbitmq" {
  name               = "rabbitmq-data"
  storage_account_id = azurerm_storage_account.main.id
  quota              = 5
}

# ─── Container Apps Environment ───────────────────────────────────────────────

resource "azurerm_container_app_environment" "main" {
  name                = "infra-env"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_container_app_environment_storage" "mariadb" {
  name                         = "mariadb-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.mariadb.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "presenca_db" {
  name                         = "presenca-db-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.presenca_db.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "relatorio_db" {
  name                         = "relatorio-db-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.relatorio_db.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "rabbitmq" {
  name                         = "rabbitmq-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.rabbitmq.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

# ─── MariaDB ──────────────────────────────────────────────────────────────────

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

  template {
    container {
      name   = "mariadb"
      image  = "mariadb:11.2"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "MYSQL_ROOT_PASSWORD"
        value = var.db_root_password
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
        name  = "MYSQL_PASSWORD"
        value = var.db_password
      }

      volume_mounts {
        name = "mariadb-data"
        path = "/var/lib/mysql"
      }
    }

    volume {
      name         = "mariadb-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.mariadb.name
    }

    min_replicas = 1
    max_replicas = 1
  }
}

# ─── RabbitMQ ─────────────────────────────────────────────────────────────────

resource "azurerm_container_app" "rabbitmq" {
  name                         = "rabbitmq"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  ingress {
    external_enabled = false
    exposed_port     = 5672
    target_port      = 5672
    transport        = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "rabbitmq"
      image  = "rabbitmq:3.13-management"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "RABBITMQ_DEFAULT_USER"
        value = var.rabbitmq_username
      }
      env {
        name  = "RABBITMQ_DEFAULT_PASS"
        value = var.rabbitmq_password
      }

      volume_mounts {
        name = "rabbitmq-data"
        path = "/var/lib/rabbitmq"
      }
    }

    volume {
      name         = "rabbitmq-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.rabbitmq.name
    }

    min_replicas = 1
    max_replicas = 1
  }
}

# ─── presenca-db ──────────────────────────────────────────────────────────────

resource "azurerm_container_app" "presenca_db" {
  name                         = "presenca-db"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  ingress {
    external_enabled = false
    exposed_port     = 5432
    target_port      = 5432
    transport        = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "presenca-db"
      image  = "postgres:17"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "POSTGRES_DB"
        value = var.presenca_db_name
      }
      env {
        name  = "POSTGRES_USER"
        value = var.presenca_db_user
      }
      env {
        name  = "POSTGRES_PASSWORD"
        value = var.presenca_db_password
      }

      volume_mounts {
        name = "presenca-db-data"
        path = "/var/lib/postgresql/data"
      }
    }

    volume {
      name         = "presenca-db-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.presenca_db.name
    }

    min_replicas = 1
    max_replicas = 1
  }
}

# ─── relatorio-db ─────────────────────────────────────────────────────────────

resource "azurerm_container_app" "relatorio_db" {
  name                         = "relatorio-db"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  ingress {
    external_enabled = false
    exposed_port     = 5432
    target_port      = 5432
    transport        = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "relatorio-db"
      image  = "postgres:17"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "POSTGRES_DB"
        value = var.relatorio_db_name
      }
      env {
        name  = "POSTGRES_USER"
        value = var.relatorio_db_user
      }
      env {
        name  = "POSTGRES_PASSWORD"
        value = var.relatorio_db_password
      }

      volume_mounts {
        name = "relatorio-db-data"
        path = "/var/lib/postgresql/data"
      }
    }

    volume {
      name         = "relatorio-db-data"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.relatorio_db.name
    }

    min_replicas = 1
    max_replicas = 1
  }
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

    min_replicas = 1
    max_replicas = 3
  }

  depends_on = [azurerm_container_app.mariadb]
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
        value = "jdbc:postgresql://presenca-db:5432/${var.presenca_db_name}?sslmode=disable"
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
        value = "rabbitmq"
      }
      env {
        name  = "RABBITMQ_PORT"
        value = "5672"
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

    min_replicas = 1
    max_replicas = 3
  }

  depends_on = [
    azurerm_container_app.presenca_db,
    azurerm_container_app.rabbitmq,
  ]
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
        value = "rabbitmq"
      }
      env {
        name  = "RABBITMQ_PORT"
        value = "5672"
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

    min_replicas = 1
    max_replicas = 3
  }

  depends_on = [azurerm_container_app.rabbitmq]
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
        value = "Host=relatorio-db;Port=5432;Database=${var.relatorio_db_name};Username=${var.relatorio_db_user};Password=${var.relatorio_db_password};SSL Mode=Disable"
      }
      env {
        name  = "PresencaService__BaseUrl"
        value = "http://presenca-service"
      }
      env {
        name  = "RabbitMQ__Host"
        value = "rabbitmq"
      }
      env {
        name  = "RabbitMQ__Port"
        value = "5672"
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

    min_replicas = 1
    max_replicas = 3
  }

  depends_on = [
    azurerm_container_app.relatorio_db,
    azurerm_container_app.rabbitmq,
    azurerm_container_app.presenca_service,
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
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  depends_on = [azurerm_container_app.auth_service]
}
