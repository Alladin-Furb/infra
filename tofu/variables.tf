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

# ─── Storage (persistência dos bancos via Azure Files) ────────────────────────

variable "storage_account_name" {
  type        = string
  description = "Nome da Storage Account (global único, 3-24 chars, só letras minúsculas e números)."
}

# ─── auth-service / MariaDB ───────────────────────────────────────────────────

variable "db_name" {
  type    = string
  default = "auth_db"
}

variable "db_user" {
  type    = string
  default = "app_user"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_root_password" {
  type        = string
  sensitive   = true
  description = "Senha root do MariaDB."
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jwt_expiration" {
  type    = number
  default = 3600000
}

# ─── presenca-service / PostgreSQL ────────────────────────────────────────────

variable "presenca_db_name" {
  type    = string
  default = "presenca_db"
}

variable "presenca_db_user" {
  type    = string
  default = "presenca_user"
}

variable "presenca_db_password" {
  type      = string
  sensitive = true
}

# ─── relatorio-service / PostgreSQL ───────────────────────────────────────────

variable "relatorio_db_name" {
  type    = string
  default = "transporte_escolar_relatorios"
}

variable "relatorio_db_user" {
  type    = string
  default = "relatorio_user"
}

variable "relatorio_db_password" {
  type      = string
  sensitive = true
}

# ─── RabbitMQ (CloudAMQP — serviço externo) ───────────────────────────────────

variable "rabbitmq_url" {
  type        = string
  sensitive   = true
  description = "URL AMQPS do CloudAMQP. Ex: amqps://user:pass@host.rmq.cloudamqp.com/vhost"
}
