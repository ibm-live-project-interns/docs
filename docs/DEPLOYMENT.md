# Deployment Guide

Complete guide for deploying Sentrix in various environments.

## Table of Contents

- [Local Development](#local-development)
- [Docker Deployment](#docker-deployment)
- [Environment Configuration](#environment-configuration)
- [Troubleshooting](#troubleshooting)

---

## Local Development

### Prerequisites

- Node.js 18+ (for UI)
- Go 1.24+ (for backend services)
- Docker (for databases and message queue)

### Quick Start - Local Development

**Step 1: Start Required Infrastructure (Database & Kafka)**

```bash
cd ui
docker compose up -d postgres kafka zookeeper
```

Wait for services to be healthy (~10 seconds).

**Step 2: Start Backend Services (In Order)**

Open separate terminals for each service and start in this order:

```bash
# 1. Ingestor Core (Port 8001) - Must start FIRST to receive data
cd ingestor/ingestor_core
go run main.go

# 2. Event Router (Port 8082) - Routes events from Ingestor Core
cd ingestor/event_router
go run main.go

# 3. API Gateway (Port 8080) - Receives routed events and serves UI
cd ingestor/api_gateway
go run main.go

# 4. Datasource (Optional) - Simulates network devices sending events
cd datasource
go run main.go

# 5. Agents API (Port 9000) - Optional, for AI processing
cd ingestor/agents_api
go run main.go
```

**Note:** Datasource will automatically start sending simulated SNMP traps and syslog messages to Ingestor Core once started.

**Step 3: Start UI**

```bash
# UI Dev Server (Port 5173)
cd ui
npm install

# With real API (uses backend services)
VITE_USE_MOCK=false npm run dev

# OR with mock data (no backend needed)
npm run dev
```

**Step 4: Access the Application**

- UI: http://localhost:5173
- API: http://localhost:8080/api/v1/health
- Ingestor Core: http://localhost:8001/health
- Event Router: http://localhost:8082/health
- Login: Use any username/password (demo mode)

**Data Flow Verification:**
1. Datasource sends events → Ingestor Core logs will show incoming events
2. Ingestor Core forwards → Event Router logs will show routing
3. Event Router routes → API Gateway logs will show event storage
4. UI fetches from API Gateway → Dashboard displays alerts

### UI Development

```bash
# Navigate to UI directory
cd ui

# Install dependencies
npm install

# Start development server (uses mock data by default)
npm run dev

# To use real API instead of mock data
VITE_USE_MOCK=false npm run dev
```

The UI will be available at `http://localhost:5173`

### Backend Development

**Service Startup Order:**
Start services in this order to follow the data flow:

```bash
# 1. Ingestor Core (Port 8001) - Central ingestion point
cd ingestor/ingestor_core
go run main.go

# 2. Event Router (Port 8082) - Routes events by severity
cd ingestor/event_router
go run main.go

# 3. API Gateway (Port 8080) - REST API for UI
cd ingestor/api_gateway
go run main.go

# 4. Datasource (Optional) - Simulates network devices
cd datasource
go run main.go

# 5. Agents API (Optional, Port 9000) - AI processing
cd ingestor/agents_api
go run main.go
```

**Environment Files:**
- Create `ingestor/.env` for all ingestor services (API Gateway, Ingestor Core, Event Router, Agents API)
- Create `datasource/.env` for datasource service
- See [Environment Configuration](#environment-configuration) section below

**Datasource Service:**
The datasource service simulates network devices:
- Sends SNMP traps to Ingestor Core
- Sends syslog messages to Ingestor Core
- Sends device metadata
- Uses HTTP client with retry logic
- Validates events using shared Event model

**Required for Full Testing:**
To see data flowing through the system, you need at minimum:
1. Infrastructure (PostgreSQL, Kafka)
2. Ingestor Core (receives events)
3. API Gateway (serves UI)
4. Datasource (generates events)
5. UI (displays data)

### Database Setup (Local)

```bash
# Start PostgreSQL only
docker compose up -d postgres

# Connect to database
psql -h localhost -U admin -d noc_alerts
```

---

## Docker Deployment

### Full Stack Deployment

```bash
cd ui

# Build and start all services
docker compose up -d --build

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Stop and remove volumes (reset data)
docker compose down -v
```

### Service Ports

| Service | Port | Description |
|---------|------|-------------|
| UI (Dev) | 5173 | Vite dev server |
| UI (Prod) | 3000 | Production frontend |
| API Gateway | 8080 | REST API (serves UI) |
| Ingestor Core | 8001 | Data ingestion |
| Event Router | 8082 | Event routing |
| Agents API | 9000 | AI processing |
| Datasource | - | Sends events to Ingestor Core |
| PostgreSQL | 5432 | Database |
| PgAdmin | 5050 | Database UI |
| Kafka | 9092 | Message queue |
| Zookeeper | 2181 | Kafka coordination |
| Kafka UI | 8090 | Kafka management |

### Accessing Services

**PgAdmin:**
- URL: http://localhost:5050
- Email: admin@admin.com
- Password: root

To connect to PostgreSQL from PgAdmin:
1. Right-click "Servers" → "Register" → "Server"
2. Name: `noc-postgres`
3. Connection tab:
   - Host: `postgres` (Docker network name)
   - Port: `5432`
   - Database: `noc_alerts`
   - Username: `admin`
   - Password: `secret`

**Kafka UI:**
- URL: http://localhost:8090
- No authentication required

### Building Individual Services

```bash
# Build UI only
docker compose build ui

# Build API Gateway only
docker compose build api-gateway

# Rebuild all services
docker compose build --no-cache
```

### Scaling Services

```bash
# Scale API Gateway to 3 instances
docker compose up -d --scale api-gateway=3
```

---

## Environment Configuration

### UI Environment Variables

Create `.env` file in `ui/` directory:

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
VITE_APP_NAME=IBM watsonx Alerts
VITE_APP_VERSION=1.0.0
```

### Backend Environment Variables

Create `.env` file in `ingestor/` directory:

```bash
# General
NODE_ENV=production
LOG_LEVEL=info

# API Gateway
API_GATEWAY_PORT=8080
GIN_MODE=release
CORS_ALLOWED_ORIGINS=https://noc.example.com
JWT_SECRET=your-secure-secret-key-minimum-32-chars
JWT_EXPIRY_HOURS=24
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=100

# Ingestor Core
INGESTOR_CORE_PORT=8001
EVENT_ROUTER_URL=http://event-router:8082

# Event Router
EVENT_ROUTER_PORT=8082

# Agents API
AGENTS_API_PORT=9000
WATSON_API_KEY=your-watson-api-key
WATSON_PROJECT_ID=your-watson-project-id
WATSON_URL=https://us-south.ml.cloud.ibm.com

# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=secure-password
POSTGRES_DB=noc_alerts
POSTGRES_SSL_MODE=require

# Kafka
KAFKA_BROKERS=kafka:29092
KAFKA_TOPIC_ALERTS=alerts
KAFKA_TOPIC_EVENTS=events
```

### Environment Variable Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET` | Yes | - | JWT signing key (min 32 chars) |
| `POSTGRES_PASSWORD` | Yes | - | Database password |
| `WATSON_API_KEY` | No | - | IBM watsonx API key |
| `GIN_MODE` | No | `debug` | Gin framework mode |
| `CORS_ALLOWED_ORIGINS` | No | `localhost` | Allowed CORS origins |

---

## Troubleshooting

### Common Issues

#### Services not starting

```bash
# Check service logs
docker compose logs api-gateway
docker compose logs postgres

# Check if ports are in use
lsof -i :8080
lsof -i :5432
```

#### Database connection issues

```bash
# Test database connection
docker compose exec postgres psql -U admin -d noc_alerts -c "SELECT 1"

# Check database logs
docker compose logs postgres
```

#### API Gateway returning 401

1. Check JWT token is valid and not expired
2. Verify `JWT_SECRET` matches between services
3. Check Authorization header format: `Bearer <token>`

#### UI not connecting to API

1. Check `VITE_API_BASE_URL` is correct
2. Verify CORS origins include UI URL
3. Check browser console for errors

#### Kafka connection issues

```bash
# Check Kafka is running
docker compose logs kafka

# Test Kafka connection
docker compose exec kafka kafka-topics --list --bootstrap-server localhost:9092
```

### Reset Everything

```bash
# Stop all services and remove volumes
docker compose down -v

# Remove all images
docker compose down --rmi all

# Rebuild from scratch
docker compose up -d --build
```

### Logs and Debugging

```bash
# Follow all logs
docker compose logs -f

# Follow specific service
docker compose logs -f api-gateway

# Get last 100 lines
docker compose logs --tail=100 api-gateway

# Export logs to file
docker compose logs > logs.txt
```

### Performance Issues (Known Issues & Fixes)
1. **Slow API responses:**
   - **Known Issue:** Database queries can become slow with large datasets
   - **Fixes Found:**
     - Enable query logging: `log_statement = 'all'` in postgresql.conf
     - Add indexes on frequently queried columns (alert_id, timestamp, severity)
     - Use connection pooling with `max_connections=100`
     - Implement query result caching for dashboard endpoints

2. **UI slow to load:**
   - **Known Issue:** Large bundle sizes and unoptimized assets cause slow initial load
   - **Fixes Found:**
     - Enable gzip in nginx.conf: `gzip on; gzip_types text/css application/javascript;`
     - Implement lazy loading for dashboard components
     - Use `npm run build -- --analyze` to identify large dependencies
     - Split vendor chunks in vite.config.js: `build.rollupOptions.output.manualChunks`
