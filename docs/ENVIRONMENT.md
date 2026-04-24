# Environment Configuration

Complete reference for all environment variables used in Sentrix.

## UI Environment Variables

**Location:** `ui/.env`

### API Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_API_BASE_URL` | Yes | `http://localhost:8080` | Backend API base URL |
| `VITE_API_VERSION` | No | `v1` | API version prefix |
| `VITE_API_TIMEOUT` | No | `30000` | Request timeout in ms |

### WebSocket Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_WS_ENDPOINT` | No | `ws://localhost:8080/ws` | WebSocket endpoint |
| `VITE_ENABLE_WEBSOCKET` | No | `false` | Enable real-time WebSocket |

### Feature Flags

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_USE_MOCK` | No | `true` (dev) / `false` (prod) | Use mock data |
| `VITE_ENABLE_REALTIME_UPDATES` | No | `true` | Enable polling updates |
| `VITE_ENABLE_TICKETING` | No | `true` | Enable ticket system |
| `VITE_ENABLE_RAG_INSIGHTS` | No | `true` | Enable AI insights |

### Polling Intervals

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_ALERT_POLLING_INTERVAL` | No | `30000` | Alert refresh interval (ms) |
| `VITE_DASHBOARD_REFRESH_INTERVAL` | No | `30000` | Dashboard refresh (ms) |

### UI Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_MAX_ALERTS_PER_PAGE` | No | `20` | Pagination page size |
| `VITE_MAX_RECENT_ALERTS` | No | `10` | Recent alerts limit |
| `VITE_DEFAULT_THEME` | No | `system` | Default theme (light/dark/system) |

### App Info

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_APP_NAME` | No | `Sentrix` | Application name |
| `VITE_APP_VERSION` | No | `1.0.0` | Application version |

### Example `.env` File

```bash
# API Configuration
VITE_API_BASE_URL=http://localhost:8080
VITE_API_VERSION=v1
VITE_API_TIMEOUT=30000

# WebSocket Configuration
VITE_WS_ENDPOINT=ws://localhost:8080/ws
VITE_ENABLE_WEBSOCKET=false

# Feature Flags
VITE_USE_MOCK=false
VITE_ENABLE_REALTIME_UPDATES=true
VITE_ENABLE_TICKETING=true
VITE_ENABLE_RAG_INSIGHTS=true

# Polling Intervals (ms)
VITE_ALERT_POLLING_INTERVAL=30000
VITE_DASHBOARD_REFRESH_INTERVAL=30000

# UI Settings
VITE_MAX_ALERTS_PER_PAGE=20
VITE_DEFAULT_THEME=system

# App Info
VITE_APP_NAME=Sentrix
VITE_APP_VERSION=1.0.0
```

---

## Backend Environment Variables

**Location:** `ingestor/.env`

### General

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NODE_ENV` | No | `development` | Environment mode |
| `LOG_LEVEL` | No | `info` | Logging level |

### API Gateway (Port 8080)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_GATEWAY_PORT` | No | `8080` | API Gateway port |
| `API_GATEWAY_HOST` | No | `0.0.0.0` | Bind address |
| `GIN_MODE` | No | `debug` | Gin framework mode |
| `CORS_ALLOWED_ORIGINS` | No | `localhost:5173,3000` | CORS origins (comma-separated) |

### JWT Authentication

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET` | **Yes** | - | JWT signing key (min 32 chars) |
| `JWT_EXPIRY_HOURS` | No | `24` | Token expiry in hours |
| `JWT_ISSUER` | No | `noc-dashboard` | JWT issuer claim |

### Rate Limiting

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RATE_LIMIT_ENABLED` | No | `true` | Enable rate limiting |
| `RATE_LIMIT_REQUESTS_PER_MINUTE` | No | `100` | Requests per minute |

### Ingestor Core (Port 8001)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `INGESTOR_CORE_PORT` | No | `8001` | Ingestor Core port |
| `INGESTOR_CORE_HOST` | No | `0.0.0.0` | Bind address |

### Event Router (Port 8082)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `EVENT_ROUTER_PORT` | No | `8082` | Event Router port |
| `EVENT_ROUTER_HOST` | No | `0.0.0.0` | Bind address |
| `EVENT_ROUTER_CONFIG_PATH` | No | `./config.json` | Routing config file |

### Agents API (Port 9000)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AGENTS_API_PORT` | No | `9000` | Agents API port |
| `AGENTS_API_HOST` | No | `0.0.0.0` | Bind address |

### IBM watsonx Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WATSON_API_KEY` | No* | - | watsonx API key |
| `WATSON_PROJECT_ID` | No* | - | watsonx project ID |
| `WATSON_URL` | No | `https://us-south.ml.cloud.ibm.com` | watsonx endpoint |

*Required for AI features

### Service Discovery

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_GATEWAY_URL` | No | `http://localhost:8080` | API Gateway URL |
| `INGESTOR_CORE_URL` | No | `http://localhost:8001` | Ingestor Core URL |
| `EVENT_ROUTER_URL` | No | `http://localhost:8082` | Event Router URL |
| `AGENTS_API_URL` | No | `http://localhost:9000` | Agents API URL |

### Database (PostgreSQL)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_HOST` | No | `localhost` | Database host |
| `POSTGRES_PORT` | No | `5432` | Database port |
| `POSTGRES_USER` | No | `admin` | Database user |
| `POSTGRES_PASSWORD` | **Yes** | - | Database password |
| `POSTGRES_DB` | No | `noc_alerts` | Database name |
| `POSTGRES_SSL_MODE` | No | `disable` | SSL mode |

### Connection Pool

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_MAX_OPEN_CONNS` | No | `25` | Max open connections |
| `DB_MAX_IDLE_CONNS` | No | `5` | Max idle connections |
| `DB_CONN_MAX_LIFETIME_MINUTES` | No | `5` | Connection lifetime |

### Kafka

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `KAFKA_BROKERS` | No | `localhost:9092` | Kafka brokers |
| `KAFKA_TOPIC_ALERTS` | No | `alerts` | Alerts topic |
| `KAFKA_TOPIC_EVENTS` | No | `events` | Events topic |
| `KAFKA_CONSUMER_GROUP` | No | `noc-ingestor` | Consumer group |

### Monitoring

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `METRICS_ENABLED` | No | `true` | Enable metrics |
| `METRICS_PORT` | No | `9090` | Metrics port |
| `TRACING_ENABLED` | No | `false` | Enable tracing |
| `TRACING_ENDPOINT` | No | - | Jaeger endpoint |

### Security

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `INTERNAL_API_KEY` | No | - | Service-to-service key |
| `TLS_ENABLED` | No | `false` | Enable TLS |
| `TLS_CERT_PATH` | No | - | TLS certificate path |
| `TLS_KEY_PATH` | No | - | TLS key path |

### Example `.env` File

```bash
# General
NODE_ENV=development
LOG_LEVEL=info

# API Gateway
API_GATEWAY_PORT=8080
GIN_MODE=debug
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000

# JWT
JWT_SECRET=your-secure-secret-key-minimum-32-characters
JWT_EXPIRY_HOURS=24

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=100

# Ingestor Core
INGESTOR_CORE_PORT=8001
EVENT_ROUTER_URL=http://localhost:8082

# Event Router
EVENT_ROUTER_PORT=8082

# Agents API
AGENTS_API_PORT=9000
WATSON_API_KEY=your-watson-api-key
WATSON_PROJECT_ID=your-watson-project-id

# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=secret
POSTGRES_DB=noc_alerts

# Kafka
KAFKA_BROKERS=localhost:9092
```

---

## Docker Environment Variables

When running with Docker Compose, environment variables are set in `docker-compose.yml`:

```yaml
services:
  api-gateway:
    environment:
      API_GATEWAY_PORT: "8080"
      GIN_MODE: release
      JWT_SECRET: "${JWT_SECRET:-default-secret}"
      POSTGRES_HOST: postgres
      KAFKA_BROKERS: kafka:29092
```

### Using `.env` with Docker Compose

Create a `.env` file in the same directory as `docker-compose.yml`:

```bash
JWT_SECRET=my-production-secret
WATSON_API_KEY=my-watson-key
```

Docker Compose automatically loads this file.

---
