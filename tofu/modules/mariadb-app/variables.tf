variable "name" {
  type        = string
  description = "Nome do Container App (ex: mariadb, presenca-db)."
}

variable "environment_id" {
  type        = string
  description = "ID do Container App Environment."
}

variable "resource_group_name" {
  type        = string
  description = "Nome do Resource Group."
}

variable "root_password" {
  type        = string
  sensitive   = true
  description = "Senha do usuário root do MariaDB."
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Senha do usuário da aplicação."
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados a criar."
}

variable "db_user" {
  type        = string
  description = "Usuário da aplicação no banco."
}

variable "env_storage_name" {
  type        = string
  description = "Nome do recurso azurerm_container_app_environment_storage para o volume."
}
