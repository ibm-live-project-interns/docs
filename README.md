# IBM watsonx Alerts - NOC Dashboard

> AI-powered Network Operations Center for SNMP Traps and Syslog Analytics

A full-stack platform that ingests network events (SNMP traps, syslogs), processes them through IBM watsonx AI for intelligent analysis, and presents actionable insights through a modern React dashboard.

## Repository Structure

This project consists of multiple repositories:

| Repository | Description | GitHub |
|------------|-------------|--------|
| **docs** | Documentation (you are here) | [docs](https://github.com/ibm-live-project-interns/docs) |
| **ui** | React Frontend Dashboard | [ui](https://github.com/ibm-live-project-interns/ui) |
| **ingestor** | Backend Microservices (Go) | [ingestor](https://github.com/ibm-live-project-interns/ingestor) |
| **datasource** | Data Simulation Service | [datasource](https://github.com/ibm-live-project-interns/datasource) |
| **ai-core** | AI/ML Core Components | [ai-core](https://github.com/ibm-live-project-interns/ai-core) |
| **infra** | Infrastructure & Deployment | [infra](https://github.com/ibm-live-project-interns/infra) |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐                │
│  │  Datasource  │───▶│  Ingestor Core  │───▶│ Event Router │                │
│  │  (Go)        │    │  :8001          │    │ :8082        │                │
│  │  SNMP/Syslog │    │                 │    │              │                │
│  └──────────────┘    └─────────────────┘    └──────┬───────┘                │
│                                                     │                        │
│                      ┌──────────────────────────────┼──────────────────┐    │
│                      │                              │                  │    │
│                      ▼                              ▼                  ▼    │
│               ┌─────────────┐              ┌─────────────┐    ┌──────────┐ │
│               │ Agents API  │              │ API Gateway │    │  Kafka   │ │
│               │ :9000       │              │ :8080       │    │  :9092   │ │
│               │ (watsonx)   │              │   (Direct)  │    │          │ │
│               └─────────────┘              └──────┬──────┘    └──────────┘ │
│                                                   │                        │
│                      ┌────────────────────────────┼────────────────┐       │
│                      │                            │                │       │
│                      ▼                            ▼                ▼       │
│               ┌─────────────┐          ┌──────────────────┐  ┌───────────┐  │
│               │  PostgreSQL │          │  UI (nginx)      │  │  PgAdmin  │  │
│               │  :5432      │          │  :3000 → :8080   │  │  :5050    │  │
│               └─────────────┘          │  (proxies API)   │  └───────────┘  │
│                                        └──────────────────┘                │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

See [Original Architecture Diagrams](./docs/arch/) for detailed layer diagrams.

## Quick Start

### Prerequisites

- Docker Desktop (v20.10+)
- Node.js 18+ (for local UI development)
- Go 1.21+ (optional, for backend development)

### 1. Clone All Repositories

```bash
# Create project directory
mkdir ibm-noc-dashboard && cd ibm-noc-dashboard

# Clone all repos
git clone https://github.com/ibm-live-project-interns/docs.git
git clone https://github.com/ibm-live-project-interns/ui.git
git clone https://github.com/ibm-live-project-interns/ingestor.git
git clone https://github.com/ibm-live-project-interns/datasource.git
git clone https://github.com/ibm-live-project-interns/ai-core.git
git clone https://github.com/ibm-live-project-interns/infra.git
```

### 2. Start All Services

```bash
cd ui
docker compose up -d --build
```

### 3. Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **UI Dashboard** | http://localhost:3000 | Demo: `admin` / `admin123` (any password works) |
| **API Gateway** | http://localhost:8080/api/v1 | JWT Auth (Direct access) |
| **PgAdmin** | http://localhost:5050 | admin@admin.com / root |
| **Kafka UI** | http://localhost:8090 | - |

**Note:** When using the web UI, API calls are made to `http://localhost:3000/api/v1/...` which nginx proxies to the backend at port 8080.

### 4. Using PgAdmin (Database Management)

1. Open http://localhost:5050
2. Login with:
   - Email: `admin@admin.com`
   - Password: `root`
3. The "NOC Database" server is pre-configured. If prompted for password, enter: `secret`
4. Navigate to: Servers → NOC Database → Databases → noc_alerts → Schemas → public → Tables

**Database Tables:**
- `alerts` - Network alerts with AI analysis
- `devices` - Monitored network devices
- `ai_metrics` - AI performance metrics
- `ingestion_data` - Raw ingested events
- `ai_results` - AI processing results
- `alert_history` - Alert state changes

### 5. Development Mode (UI Only)

```bash
cd ui
npm install
npm run dev  # Starts at http://localhost:5173 with mock data
```

## Documentation

### This Repository (docs)

- [System Architecture](./docs/ARCHITECTURE.md) - Service design and data flow
- [API Reference](./docs/API.md) - Complete REST API documentation
- [UI Screens & Components](./docs/UI_SCREENS.md) - Comprehensive UI guide with code examples
- [Environment Configuration](./docs/ENVIRONMENT.md) - All environment variables
- [Deployment Guide](./docs/DEPLOYMENT.md) - Local, Docker, and production deployment

### Other Repositories

- [UI README](https://github.com/ibm-live-project-interns/ui#readme) - Frontend setup
- [Ingestor README](https://github.com/ibm-live-project-interns/ingestor#readme) - Backend services
- [Datasource README](https://github.com/ibm-live-project-interns/datasource#readme) - Data simulation
- [Infra README](https://github.com/ibm-live-project-interns/infra#readme) - Infrastructure

## Tech Stack

### Frontend (ui)
- React 19 + TypeScript
- Vite (build tool)
- IBM Carbon Design System
- Carbon Charts

### Backend (ingestor)
- Go 1.21+ (Gin framework)
- PostgreSQL 15
- Apache Kafka
- IBM watsonx AI

### Infrastructure
- Docker & Docker Compose
- Nginx (production serving)

## Environment Variables

Key variables (see [Environment Configuration](./docs/ENVIRONMENT.md) for complete reference):

```bash
# UI
VITE_USE_MOCK=false              # Use real API vs mock data
VITE_API_BASE_URL=http://localhost:8080

# Backend
JWT_SECRET=your-secret-key       # JWT signing key (min 32 chars)
WATSON_API_KEY=your-watson-key   # IBM watsonx API key
```
