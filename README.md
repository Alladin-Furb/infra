# Infra

Docker Compose infrastructure for a microservices architecture with an API Gateway, JWT-based authentication, and a shared MariaDB database.

## Architecture

```
                        ┌─────────────────────────────────────────┐
                        │             backend network              │
Internet                │          (internal, no internet)         │
   │                    │                                          │
   ▼                    │   ┌──────────────┐   ┌──────────────┐   │
┌──────────┐            │   │ auth-service │   │   mariadb    │   │
│   :8080  │◄──────────►│   │    :8081     │──►│    :3306     │   │
│api-gateway│           │   └──────────────┘   └──────────────┘   │
└──────────┘            │                                          │
     │ frontend network  └─────────────────────────────────────────┘
     └──────────────────────────────────────────────────────────────
```

### Networks

| Network    | Type               | Purpose                                           |
|------------|--------------------|---------------------------------------------------|
| `frontend` | bridge             | Exposes the API Gateway to the host               |
| `backend`  | bridge (internal)  | Private network; services cannot reach the internet |

The `backend` network is declared `internal: true`, meaning containers on it have no outbound internet access. Only the API Gateway sits on both networks, acting as the sole entry point.

### Services

| Service       | Image                                    | Port  | Networks             |
|---------------|------------------------------------------|-------|----------------------|
| `mariadb`     | `mariadb:11.2`                           | 3306  | backend              |
| `auth-service`| `${DOCKERHUB_USERNAME}/auth-service`     | 8081  | backend              |
| `api-gateway` | `${DOCKERHUB_USERNAME}/api-gateway`      | 8080  | frontend + backend   |

### Request flow

```
Client → api-gateway:8080 → (route match) → auth-service:8081 → mariadb:3306
```

The API Gateway matches routes by path prefix and forwards to the corresponding service. JWT validation is performed at the gateway level before requests reach downstream services.

### Route table

| Path prefix     | Upstream service              |
|-----------------|-------------------------------|
| `/api/auth/**`  | `http://auth-service:8081`    |

---

## Getting started

### 1. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in the required values:

```env
DOCKERHUB_USERNAME=your-dockerhub-username
DB_ROOT_PASSWORD=changeme
DB_NAME=auth_db
DB_USER=app_user          # must NOT be "root"
DB_PASSWORD=changeme
JWT_SECRET=<min-32-byte base64 secret>
JWT_EXPIRATION=3600000    # milliseconds (default: 1 hour)
```

> `DB_USER` cannot be `root`. MariaDB creates the root user internally via `MYSQL_ROOT_PASSWORD`; using `root` again as `MYSQL_USER` causes a startup failure.

### 2. Start the stack

```bash
docker-compose up -d
```

### 3. Verify

```bash
# Register a user
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"testuser","email":"testuser@example.com","password":"Test@1234"}'

# Login and get a JWT token
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"testuser@example.com","password":"Test@1234"}'
```

---

## Adding a new service

Follow these steps to plug a new microservice into the infrastructure.

### Step 1 — Add the service to `docker-compose.yml`

```yaml
services:
  my-service:
    image: ${DOCKERHUB_USERNAME}/my-service:latest
    container_name: my-service
    environment:
      SOME_VAR: ${SOME_VAR}
    networks:
      - backend
    depends_on:
      mariadb:
        condition: service_healthy  # only if the service needs the database
```

Keep the service on the `backend` network only. It will not be reachable from the internet directly — all traffic must go through the API Gateway.

### Step 2 — Add a route to the API Gateway

The gateway reads its routes from `application.yml` inside the `api-gateway` image. Add a new entry under `spring.cloud.gateway.routes`:

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: my-service
          uri: http://my-service:8082
          predicates:
            - Path=/api/my-service/**
```

Choose a unique path prefix that does not conflict with existing routes. Rebuild and push the `api-gateway` image after this change.

### Step 3 — Expose environment variables (if needed)

If your service needs secrets or config values, add them to `.env.example` (with empty or safe default values) and to `.env` (with real values):

```env
# .env.example
SOME_VAR=
```

Then reference them in the service definition:

```yaml
environment:
  SOME_VAR: ${SOME_VAR}
```

### Step 4 — Database (optional)

If the new service needs its own database schema, create a dedicated database and user instead of reusing the existing ones. Add the following environment variables to MariaDB:

```yaml
mariadb:
  environment:
    MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    # existing vars ...
```

MariaDB's entrypoint only supports creating one extra database/user via `MYSQL_DATABASE` / `MYSQL_USER`. For additional schemas, use an init SQL script mounted at `/docker-entrypoint-initdb.d/`:

```yaml
mariadb:
  volumes:
    - mariadb-data:/var/lib/mysql
    - ./init:/docker-entrypoint-initdb.d   # *.sql files run on first boot
```

### Step 5 — Apply changes

```bash
docker-compose down
docker-compose up -d
```

If you only changed a single service's image:

```bash
docker-compose up -d --no-deps --pull always my-service
```

---

## Useful commands

```bash
# Start the stack
docker-compose up -d

# Stop the stack (keeps volumes)
docker-compose down

# Stop and wipe all data (volumes deleted)
docker-compose down -v

# Follow logs for a specific service
docker-compose logs -f my-service

# Restart a single service
docker-compose restart my-service

# Pull latest images and recreate a single service
docker-compose up -d --no-deps --pull always my-service
```
