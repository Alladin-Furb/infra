resource "azurerm_container_app" "db" {
  name                         = var.name
  container_app_environment_id = var.environment_id
  resource_group_name          = var.resource_group_name
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
    name  = "root-password"
    value = var.root_password
  }
  secret {
    name  = "db-password"
    value = var.password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "db-data"
      storage_type = "AzureFile"
      storage_name = var.env_storage_name
    }

    container {
      name   = var.name
      image  = "mariadb:11.2"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "MYSQL_ROOT_PASSWORD"
        secret_name = "root-password"
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
        name = "db-data"
        path = "/var/lib/mysql"
      }
    }
  }
}
