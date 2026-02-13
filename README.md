# IBM watsonx Alerts - NOC Dashboard

> AI-powered Network Operations Center for SNMP Traps and Syslog Analytics

A full-stack platform that ingests network events (SNMP traps, syslogs), processes them through IBM watsonx AI for intelligent analysis, and presents actionable insights through a modern React dashboard built with IBM Carbon Design System.

## Repository Structure

| Repository | Description | GitHub |
|------------|-------------|--------|
| **docs** | Documentation (you are here) | [docs](https://github.com/ibm-live-project-interns/docs) |
| **ui** | React Frontend Dashboard | [ui](https://github.com/ibm-live-project-interns/ui) |
| **ingestor** | Backend Microservices (Go) | [ingestor](https://github.com/ibm-live-project-interns/ingestor) |
| **datasource** | Data Simulation Service | [datasource](https://github.com/ibm-live-project-interns/datasource) |
| **ai-core** | AI/ML Core Components | [ai-core](https://github.com/ibm-live-project-interns/ai-core) |
| **infra** | Infrastructure & Deployment | [infra](https://github.com/ibm-live-project-interns/infra) |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW                                   │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐            │
│  │  Datasource  │───▶│  Ingestor Core  │───▶│ Event Router │            │
│  │  (Go)        │    │  :8001          │    │ :8082        │            │
│  │  SNMP/Syslog │    │  Normalize,     │    │  Route to    │            │
│  │  Simulator   │    │  Validate,      │    │  Kafka       │            │
│  └──────────────┘    │  Enrich         │    └──────┬───────┘            │
│                      └─────────────────┘           │                    │
│                                                     │                    │
│                      ┌──────────────────────────────┼────────────┐      │
│                      │                              │            │      │
│                      ▼                              ▼            ▼      │
│               ┌─────────────┐              ┌──────────────┐  ┌───────┐ │
│               │  AI Core    │              │ API Gateway  │  │ Kafka │ │
│               │  (Go)       │              │ :8080 (Gin)  │  │ :9092 │ │
│               │  Watson AI  │              │ REST API     │  │       │ │
│               └─────────────┘              └──────┬───────┘  └───────┘ │
│                                                   │                    │
│                      ┌────────────────────────────┼──────────┐        │
│                      │                            │          │        │
│                      ▼                            ▼          ▼        │
│               ┌─────────────┐          ┌─────────────┐  ┌──────────┐ │
│               │ PostgreSQL  │          │  UI (nginx)  │  │ PgAdmin  │ │
│               │ :5432       │          │  :3000       │  │ :5050    │ │
│               │ 16 tables   │          │  React 19    │  └──────────┘ │
│               └─────────────┘          │  Carbon DS   │              │
│                                        └─────────────┘              │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- **Docker** (v20.10+) & Docker Compose
- **Python 3.10+** (for infra orchestrator)
- **Node.js 20+** (for local UI development only)
- **Go 1.23+** (for backend development only)

### Option 1: Infra Orchestrator (Recommended)

The orchestrator handles everything — cloning repos, building images, starting containers, and seeding the database.

```bash
cd infra
pip install streamlit
streamlit run app.py
```

Then click **Initialize & Start** (Local mode) on the Streamlit dashboard at http://localhost:8501.

### Option 2: Manual Docker Compose

If all repos are cloned side-by-side in a parent directory:

```bash
cd infra/prod
docker compose up -d --build
# Wait for postgres to be healthy, then seed the database:
docker compose exec -T postgres psql -U admin -d noc_alerts < postgres-init/init.sql
```

### Option 3: Frontend Development Only

```bash
cd ui
npm install
npm run dev  # Starts at http://localhost:5173 (needs API at :8080)
```

---

## Access Points & Credentials

| Service | URL | Credentials |
|---------|-----|-------------|
| **React Dashboard** | http://localhost:3000 | `admin@admin.com` / `admin123` |
| **API Gateway** | http://localhost:8080/api/v1 | JWT Auth (obtain token via `/api/v1/login`) |
| **PgAdmin** | http://localhost:5050 | `admin@admin.com` / `root` |
| **Kafka UI** | http://localhost:8090 | No auth required |
| **Infra Orchestrator** | http://localhost:8501 | No auth required |

### Login API

```bash
curl -X POST http://localhost:8080/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@admin.com","password":"admin123"}'
```

Returns a JWT token to use as `Authorization: Bearer <token>` for all other API calls.

### PgAdmin Database Connection

| Field | Value |
|-------|-------|
| Host | `postgres` |
| Port | `5432` |
| Database | `noc_alerts` |
| Username | `admin` |
| Password | `secret` |

---

## User Roles (RBAC)

The platform implements role-based access control with 5 roles and 13 permissions:

| Role | Code | Description | Sidebar |
|------|------|-------------|---------|
| **NOC Operator** | `network-ops` | Primary monitoring, alert triage | Operations focused |
| **SRE** | `sre` | Reliability engineering, SLA focus | Reliability metrics |
| **Network Admin** | `network-admin` | Device management, topology | Infrastructure focused |
| **Senior Engineer** | `senior-eng` | Architecture, performance analysis | Analytics focused |
| **System Administrator** | `sysadmin` | Full admin access, user management | All sections + Admin |

Default test user: `admin@admin.com` / `admin123` (role: `sysadmin` — full access to all features)

---

## Features & Pages (16 Screens)

### Operations
| Page | Route | Description |
|------|-------|-------------|
| **Dashboard** | `/dashboard` | Role-specific dashboards, KPIs, severity donut chart, alerts-over-time, top noisy devices, AI impact metrics |
| **Priority Alerts** | `/priority-alerts` | All alerts with AI confidence scores, severity badges, device IPs, filters, Export CSV |
| **Tickets** | `/tickets` | Ticket management with Create/Edit/Delete, comments, priority filters, Export CSV |
| **On-Call Schedule** | `/on-call` | Current on-call engineers, weekly schedule with "Today" marker, overrides |
| **Service Status** | `/service-status` | Live Docker container monitoring, app health checks, log viewer modal |

### Infrastructure
| Page | Route | Description |
|------|-------|-------------|
| **Devices** | `/devices` | Device inventory with health %, status, alert counts, uptime, real metrics |
| **Network Topology** | `/topology` | Network topology visualization, location groups, connections table |

### Analytics
| Page | Route | Description |
|------|-------|-------------|
| **Trends** | `/trends` | Alert trends, MTTR, acknowledgment rate, recurring alert types, AI insights |
| **Incident History** | `/incident-history` | Resolved incidents, MTTR metrics, SLA compliance, root cause charts |
| **SLA Reports** | `/reports/sla` | SLA compliance %, MTTR, violations table, compliance trend chart |
| **Reports Hub** | `/reports` | 5 report types (alerts, tickets, SLA, incidents, device health), CSV download |

### Configuration
| Page | Route | Description |
|------|-------|-------------|
| **Alert Configuration** | `/configuration` | Threshold rules, notification channels, escalation policies, global settings |
| **Runbooks** | `/runbooks` | Knowledge base with 10 runbooks, 4 categories, full CRUD, RBAC (sysadmin/senior-eng) |

### Administration
| Page | Route | Description |
|------|-------|-------------|
| **Audit Log** | `/admin/audit-log` | Full audit log with KPIs, filters, DataTable, CSV export (sysadmin-only) |

### User
| Page | Route | Description |
|------|-------|-------------|
| **Settings** | `/settings` | Language, timezone, auto-refresh, notification preferences |
| **Profile** | `/profile` | Profile header, account details, password change |

---

## Database (PostgreSQL)

16 tables with full schema, seed data, and indexes:

| Table | Description |
|-------|-------------|
| `alerts` | Network alerts with AI analysis fields (title, summary, root cause, recommendation, confidence) |
| `devices` | Monitored network devices (name, IP, model, vendor, status, health) |
| `tickets` | Support tickets linked to alerts and devices |
| `ticket_comments` | Comments on tickets |
| `users` | User accounts with roles and authentication |
| `sessions` | Active user sessions |
| `api_keys` | API key management |
| `audit_logs` | System audit trail (JSONB details, indexed) |
| `ai_metrics` | AI performance metrics (accuracy, throughput) |
| `ai_results` | AI analysis results linked to ingestion data |
| `ingestion_data` | Raw ingested events (SNMP traps, syslogs) |
| `alert_history` | Alert state change history with resolutions |
| `threshold_rules` | Alert threshold configuration |
| `notification_channels` | Notification channel config (email, Slack, webhook) |
| `escalation_policies` | Alert escalation policy definitions |
| `maintenance_windows` | Scheduled maintenance windows |

The database is automatically seeded with demo data (10 alerts, 10 devices, 6 tickets, threshold rules, etc.) during bootstrap.

---

## API Endpoints

Base URL: `http://localhost:8080/api/v1`

All protected endpoints require JWT authentication via `Authorization: Bearer <token>` header.

### Authentication (Public)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/login` | Login with email/password, returns JWT token |
| POST | `/register` | Register new user account |
| GET | `/health` | Health check |
| GET | `/auth/google/login` | Google OAuth login redirect |
| GET | `/auth/google/callback` | Google OAuth callback |

### Auth (Protected)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/logout` | Logout (invalidate session) |
| GET | `/me` | Get current user profile |
| GET | `/auth/me` | Get current user (alias) |
| POST | `/auth/verify-email` | Verify email address |
| POST | `/auth/forgot-password` | Request password reset email |
| POST | `/auth/reset-password` | Reset password with token |
| POST | `/auth/resend-verification` | Resend verification email |

### Alerts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/alerts` | List alerts (paginated, filterable by severity/status/from/to) |
| GET | `/alerts/:id` | Get alert details |
| GET | `/alerts/summary` | Alert summary statistics and KPIs |
| GET | `/alerts/severity-distribution` | Severity breakdown for donut chart |
| GET | `/alerts/over-time` | Alerts over time for area chart |
| GET | `/alerts/recurring` | Recurring alert patterns |
| GET | `/alerts/distribution/time` | Alert distribution by time of day |
| POST | `/alerts/:id/acknowledge` | Acknowledge an alert |
| POST | `/alerts/:id/dismiss` | Dismiss an alert |
| POST | `/alerts/:id/resolve` | Resolve an alert |
| POST | `/alerts/:id/reanalyze` | Re-run AI analysis on alert |

### AI
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/ai/metrics` | AI performance metrics (accuracy, processed count) |
| GET | `/ai/insights` | AI-generated insights (anomaly, trend, correlation, prediction) |
| GET | `/ai/impact-over-time` | AI impact trend data |

### Tickets
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/tickets` | List tickets (filterable) |
| POST | `/tickets` | Create ticket |
| GET | `/tickets/:id` | Get ticket details |
| PUT | `/tickets/:id` | Update ticket |
| PATCH | `/tickets/:id` | Partial update ticket |
| DELETE | `/tickets/:id` | Delete ticket |
| GET | `/tickets/:id/comments` | Get ticket comments |
| POST | `/tickets/:id/comments` | Add comment |
| GET | `/tickets/stats` | Ticket statistics (includes real avg MTTR) |
| GET | `/tickets/export` | Export tickets as CSV |

### Devices
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/devices` | List all devices |
| GET | `/devices/:id` | Get device details |
| GET | `/devices/:id/metrics` | Device performance metrics (CPU, memory, bandwidth) |
| GET | `/devices/noisy` | Top noisy devices (most alerts) |

### Trends
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/trends/kpi` | Trends KPI data (alert count, MTTR, ack rate) |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users` | List all users (admin only) |
| GET | `/users/:id` | Get user by ID |
| PUT | `/users/:id` | Update user |
| DELETE | `/users/:id` | Soft-delete user |
| POST | `/users/:id/reset-password` | Reset user password |

### Profile
| Method | Endpoint | Description |
|--------|----------|-------------|
| PUT | `/me` | Update own profile |
| PUT | `/me/password` | Change own password |

### Settings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/settings/notifications` | Get notification preferences |
| PUT | `/settings/notifications` | Update notification preferences |

### Configuration
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/configuration/rules` | List threshold rules |
| POST | `/configuration/rules` | Create threshold rule |
| GET | `/configuration/rules/:id` | Get rule by ID |
| PUT | `/configuration/rules/:id` | Update rule |
| DELETE | `/configuration/rules/:id` | Delete rule |
| GET | `/configuration/channels` | List notification channels |
| POST | `/configuration/channels` | Create channel |
| GET | `/configuration/channels/:id` | Get channel by ID |
| PUT | `/configuration/channels/:id` | Update channel |
| DELETE | `/configuration/channels/:id` | Delete channel |
| GET | `/configuration/policies` | List escalation policies |
| POST | `/configuration/policies` | Create policy |
| GET | `/configuration/policies/:id` | Get policy by ID |
| PUT | `/configuration/policies/:id` | Update policy |
| DELETE | `/configuration/policies/:id` | Delete policy |
| GET | `/configuration/maintenance` | List maintenance windows |
| POST | `/configuration/maintenance` | Create window |
| GET | `/configuration/maintenance/:id` | Get window by ID |
| PUT | `/configuration/maintenance/:id` | Update window |
| DELETE | `/configuration/maintenance/:id` | Delete window |
| GET | `/configuration/global-settings` | Get global settings (maintenance mode, auto-resolve, AI) |
| PUT | `/configuration/global-settings` | Update global settings |

### Reports & SLA
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/reports/export` | Export report as CSV (type param: alerts, tickets, sla, incidents, devices) |
| GET | `/reports/sla` | SLA compliance overview |
| GET | `/reports/sla/violations` | SLA violations list |
| GET | `/reports/sla/trend` | SLA compliance trend |

### Audit Logs
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/audit-logs` | Audit log entries (sysadmin only, paginated, filterable) |
| GET | `/audit-logs/actions` | List of audit log action types |

### On-Call
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/on-call/current` | Current on-call engineers |
| GET | `/on-call/schedule` | Weekly on-call schedule |

### Topology
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/topology` | Network topology (nodes + edges) |

### Service Status
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/service-status` | Application health checks (7 services) |
| GET | `/services/status` | Docker container status |
| GET | `/services/:name/logs` | Container logs by service name |

### Runbooks
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/runbooks` | List runbooks (search, category filter) |
| POST | `/runbooks` | Create runbook (sysadmin/senior-eng only) |
| GET | `/runbooks/:id` | Get runbook details |
| PUT | `/runbooks/:id` | Update runbook |
| DELETE | `/runbooks/:id` | Delete runbook |

### Events (Internal)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/events` | Ingest event (used by datasource/ingestor pipeline) |

---

## Tech Stack

### Frontend (`ui/`)
- **React 19** + TypeScript
- **Vite** (build tool)
- **IBM Carbon Design System** (components + icons)
- **Carbon Charts** (data visualization)
- **SCSS** with Carbon theme tokens

### Backend (`ingestor/`)
- **Go 1.23** with Gin framework
- **GORM** (ORM for PostgreSQL)
- **JWT** authentication + Google OAuth
- **RBAC** (5 roles, 13 permissions)

### AI (`ai-core/`)
- **Go** service
- **IBM watsonx AI** (via IAM token auth)
- Alert analysis, root cause detection, recommendations

### Data Pipeline
- **Datasource**: SNMP trap & syslog simulators (Go)
- **Ingestor Core**: Normalize, validate, enrich events
- **Event Router**: Route events to Kafka topics
- **Kafka**: Message bus between pipeline and AI

### Infrastructure
- **Docker & Docker Compose** (11 containers)
- **PostgreSQL 15** (Alpine)
- **Nginx** (production UI serving + API proxy)
- **Streamlit** (infra orchestrator UI)

---

## Docker Services

| Service | Image/Build | Port | Description |
|---------|------------|------|-------------|
| `postgres` | postgres:15-alpine | 5432 | Database |
| `zookeeper` | cp-zookeeper:7.5.0 | 2181 | Kafka coordination |
| `kafka` | cp-kafka:7.5.0 | 9092 | Message bus |
| `kafka-ui` | kafka-ui:latest | 8090 | Kafka management UI |
| `pgadmin` | pgadmin4:latest | 5050 | Database management UI |
| `api-gateway` | Built from ingestor/ | 8080 | REST API (Go/Gin) |
| `event-router` | Built from ingestor/ | 8082 | Event routing |
| `ingestor-core` | Built from ingestor/ | 8001 | Event processing |
| `ai-core` | Built from ai-core/ | - | Watson AI analysis |
| `datasource` | Built from datasource/ | - | SNMP/syslog simulator (exits after generating) |
| `ui` | Built from ui/ | 3000 | React frontend (nginx) |

---

## Environment Variables

All services receive these via `.env` (auto-generated by orchestrator):

| Variable | Value | Used By |
|----------|-------|---------|
| `POSTGRES_HOST` | `postgres` | All DB consumers |
| `POSTGRES_DB` | `noc_alerts` | All DB consumers |
| `POSTGRES_USER` | `admin` | All DB consumers |
| `POSTGRES_PASSWORD` | `secret` | All DB consumers |
| `POSTGRES_PORT` | `5432` | All DB consumers |
| `KAFKA_BROKER` | `kafka:9092` | ingestor-core, event-router, ai-core, api-gateway |
| `JWT_SECRET` | `noc-platform-dev-secret-key-2026` | api-gateway |
| `CORS_ALLOWED_ORIGINS` | `localhost:3000,5173` | api-gateway |
| `WATSONX_API_KEYS` | (your key) | ai-core |
| `WATSONX_REGION` | `eu-gb` | ai-core |
| `WATSONX_PROJECT_ID` | (your project ID) | ai-core |
| `FORWARD_TO_GATEWAY` | `false` | ai-core, event-router |
| `ENV` | `dev` | All services |

---

## Documentation

- [System Architecture](./docs/ARCHITECTURE.md)
- [API Reference](./docs/API.md)
- [UI Screens & Components](./docs/UI_SCREENS.md)
- [Environment Configuration](./docs/ENVIRONMENT.md)
- [Deployment Guide](./docs/DEPLOYMENT.md)
- [Watson AI Setup](./WATSONX_SETUP_GUIDE.md)
