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

variable "resource_group_name" {
  type    = string
  default = "infra-rg"
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Nome do ambiente (dev, staging, prod). Usado no nome do Container App Environment."
}


# ─── ACR ──────────────────────────────────────────────────────────────────────

variable "acr_name" {
  type        = string
  description = "Nome do Azure Container Registry (global único, só alfanumérico)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "O nome do ACR deve ter entre 5 e 50 caracteres alfanuméricos (sem hífens ou underscores)."
  }
}

# ─── Storage (persistência dos bancos MariaDB via Azure Files) ────────────────

variable "storage_account_name" {
  type        = string
  description = "Nome da Storage Account (global único, 3-24 chars, só letras minúsculas e números)."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "O nome da Storage Account deve ter entre 3 e 24 caracteres (letras minúsculas e números apenas, sem hífens)."
  }
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

# ─── register-adm-service / PostgreSQL (provider externo) ───────────────────

variable "register_adm_db_url" {
  type        = string
  sensitive   = true
  description = "JDBC URL completa do PostgreSQL externo. Ex: jdbc:postgresql://host:5432/db?user=u&password=p"
}

# ─── presenca-service / PostgreSQL (provider externo) ────────────────────────

variable "presenca_db_url" {
  type        = string
  sensitive   = true
  description = "JDBC URL completa do PostgreSQL externo. Ex: jdbc:postgresql://host:5432/db?user=u&password=p"
}

# ─── relatorio-service / MariaDB ──────────────────────────────────────────────

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

# ─── Redis (Upstash — cache externo opcional do Report) ──────────────────────

variable "upstash_redis_connection_string" {
  type        = string
  sensitive   = true
  description = "Connection string TLS do Upstash para StackExchange.Redis. Ex: endpoint:6379,password=token,ssl=true,abortConnect=false"

  validation {
    condition = (
      can(regex("^[^,]+:[0-9]+,", var.upstash_redis_connection_string)) &&
      strcontains(lower(var.upstash_redis_connection_string), "password=") &&
      strcontains(lower(var.upstash_redis_connection_string), "ssl=true") &&
      strcontains(lower(var.upstash_redis_connection_string), "abortconnect=false")
    )
    error_message = "Use o formato endpoint:porta,password=token,ssl=true,abortConnect=false."
  }
}

# ─── route-generator / PostgreSQL (provider externo) ─────────────────────────

variable "route_gen_db_url" {
  type        = string
  sensitive   = true
  description = "Connection string ADO.NET do PostgreSQL externo. Ex: Host=h;Port=5432;Database=db;Username=u;Password=p"
}

# ─── RabbitMQ (CloudAMQP — serviço externo) ───────────────────────────────────

variable "rabbitmq_url" {
  type        = string
  sensitive   = true
  description = "URL AMQPS do CloudAMQP. Ex: amqps://user:pass@host.rmq.cloudamqp.com/vhost"
}
