# ─── Azure Auth ───────────────────────────────────────────────────────────────

variable "subscription_id" {
  type        = string
  description = "Subscriptions → ID da linha."
}

variable "tenant_id" {
  type        = string
  description = "Microsoft Entra ID → Properties → Tenant ID."
}

# ─── Infraestrutura ───────────────────────────────────────────────────────────

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "resource_group_name" {
  type    = string
  default = "infra-rg"
}

# ─── ACR ──────────────────────────────────────────────────────────────────────

variable "acr_name" {
  type        = string
  description = "Nome do Azure Container Registry (global único, só alfanumérico)."
}

# ─── auth-service ─────────────────────────────────────────────────────────────

variable "auth_db_url" {
  type        = string
  description = "JDBC URL do banco da auth-service. Ex: jdbc:mariadb://host:3306/auth_db"
}

variable "db_user" {
  type    = string
  default = "app_user"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jwt_expiration" {
  type    = number
  default = 3600000
}

# ─── presenca-service ─────────────────────────────────────────────────────────

variable "presenca_db_url" {
  type        = string
  description = "JDBC URL do banco da presenca-service. Ex: jdbc:postgresql://host:5432/presenca_db?sslmode=disable"
}

variable "presenca_db_user" {
  type    = string
  default = "presenca_user"
}

variable "presenca_db_password" {
  type      = string
  sensitive = true
}

# ─── relatorio-service ────────────────────────────────────────────────────────

variable "relatorio_db_url" {
  type        = string
  description = "Connection string do banco da relatorio-service. Ex: Host=host;Port=5432;Database=relatorio_db;Username=relatorio_user;Password=...;SSL Mode=Disable"
}

# ─── RabbitMQ ─────────────────────────────────────────────────────────────────

variable "rabbitmq_host" {
  type        = string
  description = "Hostname do RabbitMQ externo."
}

variable "rabbitmq_port" {
  type    = number
  default = 5672
}

variable "rabbitmq_username" {
  type    = string
  default = "rabbitmq"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}
