# System Architecture

## Overview

The NOC Dashboard is a microservices-based platform designed for real-time network event processing and AI-powered analysis. The system follows event-driven architecture principles with clear separation of concerns.

## Service Components

### 1. Datasource Service

**Purpose:** Simulates or connects to network devices sending SNMP traps, syslogs, and metadata.

**Technology:** Go

**Responsibilities:**
- Parse raw SNMP trap data
- Parse syslog messages
- Normalize event formats
- Forward to Ingestor Core

**Data Flow:**
```
Network Device → Datasource → Ingestor Core
```

### 2. Ingestor Core (Port 8001)

**Purpose:** Central ingestion point for all network events.

**Technology:** Go + Gin

**Endpoints:**
- `POST /ingest/metadata` - Receive normalized events
- `GET /health` - Health check

**Responsibilities:**
- Validate incoming payloads
- Enrich with metadata
- Forward to Event Router

### 3. Event Router (Port 8082)

**Purpose:** Routes events to appropriate downstream services based on event type.

**Technology:** Go + Gin

**Configuration:** `config.json`
```json
{
  "critical": "http://api-gateway:8080/api/v1/events",
  "warning": "http://api-gateway:8080/api/v1/events",
  "info": "http://api-gateway:8080/api/v1/events"
}
```

**Endpoints:**
- `POST /route` - Route event to destination
- `GET /health` - Health check

### 4. API Gateway (Port 8080)

**Purpose:** REST API serving the UI with authentication and authorization.

**Technology:** Go + Gin + JWT

**Key Features:**
- JWT-based authentication
- CORS configuration
- Rate limiting
- Request logging
- Security headers

**API Groups:**
- `/api/v1/auth/*` - Authentication (login, register)
- `/api/v1/alerts/*` - Alert management
- `/api/v1/tickets/*` - Ticket management
- `/api/v1/devices/*` - Device information
- `/api/v1/ai/*` - AI metrics and insights
- `/api/v1/trends/*` - Trend analysis

### 5. Agents API (Port 9000)

**Purpose:** IBM watsonx AI integration for intelligent event analysis.

**Technology:** Go + IBM watsonx SDK

**Responsibilities:**
- Process events through watsonx LLM
- Generate AI summaries
- Identify root causes
- Recommend actions
- Calculate confidence scores

### 6. UI Dashboard (Port 3000/5173)

**Purpose:** React-based dashboard for network operations.

**Technology:** React 19 + TypeScript + Carbon Design System + Nginx (production)

**Production Deployment:**
- Nginx serves the UI on port 3000
- Nginx proxies `/api/*` requests to API Gateway at port 8080
- Browser makes all requests to `http://localhost:3000/api/v1/...`
- Nginx transparently forwards to `http://noc-api-gateway:8080`

**Development Mode:**
- Vite dev server runs on port 5173
- Direct connection to API Gateway at port 8080

**Key Pages:**
- Dashboard - Overview with KPIs
- Priority Alerts - Critical alerts management
- Tickets - Issue tracking
- Trends & Insights - Historical analysis
- Alert Details - Deep dive into specific alerts

## Data Models

### Alert
```typescript
interface Alert {
  id: string;
  severity: 'critical' | 'major' | 'minor' | 'info';
  status: 'new' | 'acknowledged' | 'in-progress' | 'resolved' | 'dismissed';
  timestamp: { absolute: string; relative: string };
  device: { name: string; ip: string; icon: string; model?: string; vendor?: string };
  aiTitle: string;
  aiSummary: string;
  confidence: number;
}
```

### Ticket
```typescript
interface Ticket {
  id: string;
  ticketNumber: string;
  alertId?: string;
  title: string;
  description: string;
  priority: 'critical' | 'high' | 'medium' | 'low';
  status: 'open' | 'in-progress' | 'resolved' | 'closed';
  deviceName: string;
  assignedTo: string;
  createdAt: string;
  updatedAt: string;
}
```

## Database Schema

### PostgreSQL Tables

```sql
-- Core tables
alerts              -- Network alerts with AI analysis
alert_history       -- Historical alert data
devices             -- Network device inventory
ai_metrics          -- AI performance metrics
ingestion_data      -- Raw ingested events
ai_results          -- AI analysis results
```

## Message Queue

### Kafka Topics

- `alerts` - New alert events
- `events` - General event stream
- `ai-requests` - Requests to AI service
- `ai-responses` - AI analysis results

## Security

### Authentication Flow

```
1. User submits credentials → POST /api/v1/login
2. Server validates and returns JWT token
3. Client includes token in Authorization header
4. Server validates token on protected routes
```

### JWT Claims
```go
type JWTClaims struct {
    UserID   string
    Username string
    Role     Role
    jwt.RegisteredClaims
}
```

### Security Headers
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

## Deployment Architecture

### Docker Compose Services

```yaml
services:
  postgres      # Database
  pgadmin       # Database UI
  zookeeper     # Kafka coordination
  kafka         # Message queue
  kafka-ui      # Kafka management
  api-gateway   # REST API
  ingestor-core # Data ingestion
  event-router  # Event routing
  agents-api    # AI processing
  ui            # Frontend
```

### Network Configuration

All services communicate over the `noc-network` Docker bridge network. External access is provided through mapped ports.

## Scalability Considerations

1. **Horizontal Scaling:** API Gateway and Ingestor Core can be scaled horizontally behind a load balancer.

2. **Database:** PostgreSQL can be configured with read replicas for query scaling.

3. **Message Queue:** Kafka partitions enable parallel event processing.

4. **Caching:** Redis can be added for session management and API response caching.

## Monitoring

### Health Endpoints

Each service exposes a `/health` endpoint:
```bash
curl http://localhost:8080/api/v1/health  # API Gateway (Direct)
curl http://localhost:3000/api/v1/health  # API Gateway (via nginx proxy)
curl http://localhost:8001/health          # Ingestor Core
curl http://localhost:8082/health          # Event Router
curl http://localhost:9000/health          # Agents API
```

**Note:** Port 8080 is direct API access. Port 3000 routes through nginx proxy (used by web UI).

### Logging

All services use structured logging with the following levels:
- `DEBUG` - Detailed debugging information
- `INFO` - General operational messages
- `WARN` - Warning conditions
- `ERROR` - Error conditions
