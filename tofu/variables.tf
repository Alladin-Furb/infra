# ─── Azure Auth ───────────────────────────────────────────────────────────────
# Autenticação via Azure CLI (az login). Não precisa de Service Principal.

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
  type        = string
  default     = "brazilsouth"
  description = "Região Azure."
}

variable "resource_group_name" {
  type        = string
  default     = "infra-rg"
  description = "Nome do Resource Group."
}

# ─── ACR ──────────────────────────────────────────────────────────────────────

variable "acr_name" {
  type        = string
  description = "Nome do Azure Container Registry (global único, só alfanumérico)."
}

# ─── Storage Account ──────────────────────────────────────────────────────────

variable "storage_account_name" {
  type        = string
  description = "Nome da Storage Account para volumes dos bancos (global único, só letras/números, 3-24 chars)."
}

# ─── Stack — auth-service / MariaDB ──────────────────────────────────────────

variable "db_root_password" {
  type      = string
  sensitive = true
}

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

variable "jwt_secret" {
  type        = string
  sensitive   = true
  description = "Segredo JWT (mínimo 32 bytes em base64)."
}

variable "jwt_expiration" {
  type    = number
  default = 3600000
}

# ─── Stack — presenca-service / PostgreSQL ────────────────────────────────────

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

# ─── Stack — relatorio-service / PostgreSQL ───────────────────────────────────

variable "relatorio_db_name" {
  type    = string
  default = "relatorio_db"
}

variable "relatorio_db_user" {
  type    = string
  default = "relatorio_user"
}

variable "relatorio_db_password" {
  type      = string
  sensitive = true
}

# ─── Stack — RabbitMQ ─────────────────────────────────────────────────────────

variable "rabbitmq_username" {
  type    = string
  default = "rabbitmq"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}
