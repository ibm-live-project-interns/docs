# System Architecture

## Overview

Sentrix is a microservices-based platform for real-time network event processing and AI-powered analysis. Event-driven architecture with clear separation of concerns.

## Service Components

### 1. Datasource Service

Simulates or connects to network devices sending SNMP traps, syslogs, and metadata.

**Tech:** Go 1.24

**Data Flow:**
```
Network Device -> Datasource -> Ingestor Core (HTTP POST /ingest/event)
```

### 2. Ingestor Core (Port 8001)

Central ingestion point for all network events.

**Tech:** Go + Gin

**Endpoints:**
- `POST /ingest/event` - Receive normalized events
- `GET /health` - Health check

### 3. Event Router (Port 8082)

Routes events by severity to downstream services.

**Tech:** Go + Gin

**Configuration** (`config.json`):
```json
{
  "critical": "http://ai-core:9000/events",
  "high": "http://ai-core:9000/events",
  "medium": "http://api-gateway:8080/api/internal/events",
  "low": "http://api-gateway:8080/api/internal/events",
  "info": "http://api-gateway:8080/api/internal/events"
}
```

Critical/high events go to AI Core for Watson analysis. Medium/low/info go directly to the API Gateway.

### 4. API Gateway (Port 8080)

Primary backend service with 101 registered routes, JWT authentication, RBAC, and PostgreSQL persistence.

**Tech:** Go 1.24 + Gin 1.11 + GORM 1.31 + golang-jwt 5.2

**API Groups:**
- `/api/v1/auth/*` - Authentication (login, register, logout, Google OAuth)
- `/api/v1/alerts/*` - Alert management (CRUD, summary, severity distribution, time series, acknowledge, dismiss, resolve)
- `/api/v1/tickets/*` - Ticket management (CRUD, comments, stats, delete)
- `/api/v1/devices/*` - Device inventory and metrics
- `/api/v1/ai/*` - AI metrics, insights, impact
- `/api/v1/trends/*` - Trend analysis and KPIs
- `/api/v1/dashboard/*` - Dashboard summary, metrics, charts
- `/api/v1/reports/*` - Report generation, SLA reports, violations
- `/api/v1/configuration/*` - Threshold rules, channels, policies, maintenance, global settings
- `/api/v1/runbooks/*` - Knowledge base CRUD (sysadmin/senior-eng)
- `/api/v1/device-groups/*` - Device group management
- `/api/v1/users/*` - User admin (sysadmin)
- `/api/v1/me/*` - Self-service profile
- `/api/v1/audit-logs` - Audit trail (sysadmin)
- `/api/v1/on-call/*` - On-call schedule
- `/api/v1/topology` - Network topology
- `/api/v1/service-status/*` - Service health, Docker containers
- `/api/v1/settings/*` - User settings
- `/api/internal/events` - Service-to-service event ingestion

**Handler files:** 18 files in `api_gateway/handlers/`

### 5. AI Core / Agents API (Port 9000)

IBM watsonx AI integration for intelligent event analysis.

**Tech:** Go + IBM watsonx SDK

**Responsibilities:**
- Process events through watsonx LLM
- Generate AI summaries and root cause analysis
- Recommend actions
- Calculate confidence scores

### 6. UI Dashboard (Port 3000/5173)

**Tech:** React 19 + TypeScript 5.9 + Vite 7.2 + IBM Carbon Design System 1.97

**Production:** Nginx serves UI on port 3000, proxies `/api/*` to API Gateway at 8080.
**Development:** Vite dev server on port 5173.

**Pages (33 components across 18 directories):**
- Dashboard (5 role-based views), Priority Alerts, Alert Details
- Tickets, Ticket Details, Device Explorer, Device Details, Device Groups
- Trends, Incident History, Reports Hub, SLA Reports
- On-Call Schedule, Network Topology, Service Status
- Configuration (4 tabs), Runbooks, Audit Log (sysadmin)
- Settings, Profile, Login/Register

### Shared Package (`ingestor/shared/`)

Common code shared across all backend services:

| Package | Contents |
|---------|----------|
| `models/` | 6 files: Event, Alert, User, Ticket, Configuration types, AuditLog |
| `database/` | 6 files: GORM repos for alerts, tickets, users, config, audit |
| `middleware/` | 5 files: JWT auth, security headers, logging, rate limiting, CORS |
| `rbac/` | 5 roles, 13 permissions |
| `constants/` | Severity levels, event types |
| `config/` | `GetEnv()` helper |
| `errors/` | Structured error types |
| `httpclient/` | HTTP client utilities |
| `logger/` | Structured logging |

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

### PostgreSQL (17 tables)

| Table | Purpose |
|-------|---------|
| `users` | User accounts with roles |
| `sessions` | Active JWT sessions |
| `alerts` | Network alerts with AI analysis |
| `alert_history` | Historical alert data |
| `devices` | Network device inventory |
| `tickets` | Issue tracking |
| `ticket_comments` | Ticket discussion threads |
| `threshold_rules` | Alert triggering conditions |
| `notification_channels` | Slack, Email, SMS configs |
| `escalation_policies` | Multi-step alert escalation |
| `maintenance_windows` | Scheduled suppression periods |
| `ingestion_data` | Raw ingested events |
| `ai_results` | AI analysis results |
| `ai_metrics` | AI performance metrics |
| `api_keys` | Service-to-service authentication |
| `audit_logs` | User action audit trail |
| `runbooks` | Knowledge base articles |

40 indexes across all tables. Schema in `infra/prod/postgres-init/init.sql`.

## Message Queue

### Kafka Topics

- `ingestion-events` - Main topic for normalized events flowing from ingestor to AI

## Security

### Authentication Flow

```
1. User submits credentials -> POST /api/v1/login
2. Server validates (DB or demo mode) and returns JWT token
3. Client includes token in Authorization header
4. Server validates token + checks RBAC permissions on protected routes
```

### RBAC (5 Roles, 13 Permissions)

| Role | Key Permissions |
|------|----------------|
| `network-ops` | View/acknowledge alerts, create tickets |
| `sre` | View analytics, export reports |
| `network-admin` | Manage devices and device groups |
| `senior-eng` | Full analytics, manage runbooks |
| `sysadmin` | User management, audit logs, full admin |

### Demo Mode

When the database is unavailable, the API Gateway falls back to demo mode:
- Accepts any non-empty email/password
- Generates JWT in-memory
- Email patterns map to roles (e.g., `*admin*` -> sysadmin)
- Returns demo data for all endpoints

### Security Headers
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

## Deployment Architecture

### Docker Compose Services (11)

```yaml
services:
  postgres       # Database (5432)
  pgadmin        # Database UI (5050)
  zookeeper      # Kafka coordination (2181)
  kafka          # Message queue (9092)
  kafka-ui       # Kafka management (8090)
  api-gateway    # REST API (8080)
  ingestor-core  # Data ingestion (8001)
  event-router   # Event routing (8082)
  ai-core        # AI processing (9000)
  datasource     # Event simulation
  ui             # Frontend (3000)
```

All services communicate over the `noc-network` Docker bridge network.

## Health Endpoints

```bash
curl http://localhost:8080/api/v1/health  # API Gateway
curl http://localhost:3000/api/v1/health  # API Gateway (via nginx)
curl http://localhost:8001/health          # Ingestor Core
curl http://localhost:8082/health          # Event Router
curl http://localhost:9000/health          # AI Core
```
