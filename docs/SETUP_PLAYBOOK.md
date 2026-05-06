# Sentrix — Complete Setup Playbook

> **Live deployment:** Frontend → https://ui-bionics-projects.vercel.app | API → https://sentrix-api-production-1aec.up.railway.app

This is the single document to follow when setting up Sentrix from scratch. It covers every environment — local Docker, local development, and cloud. Each path is self-contained; follow one end to end.

For deeper reference on specific topics, this playbook links out to the dedicated docs rather than duplicating them:
- Architecture and data flow → [ARCHITECTURE.md](./ARCHITECTURE.md)
- All environment variables explained → [ENVIRONMENT.md](./ENVIRONMENT.md)
- Cloud deployment detail → [DEPLOYMENT.md](./DEPLOYMENT.md)
- All API endpoints → [API.md](./API.md)
- All UI screens → [UI_SCREENS.md](./UI_SCREENS.md)

---

## What You Are Setting Up

Sentrix is an AI-powered Network Operations Center platform. It is a distributed system with 11 services:

```
┌─────────────────────────────────────────────────────────────┐
│  Browser (React + IBM Carbon)    :3000 / :5173              │
└────────────────────┬────────────────────────────────────────┘
                     │ REST API calls
┌────────────────────▼────────────────────────────────────────┐
│  API Gateway (Go/Gin)            :8080  ← main backend      │
│  └─ JWT auth, RBAC, all 101 routes, GORM → PostgreSQL       │
└──────────┬────────────────────────────────┬─────────────────┘
           │                                │
┌──────────▼──────────┐        ┌────────────▼────────────────┐
│  Ingestor Core       │        │  AI Core (Watson)   :9000   │
│  :8001              │        │  Root cause analysis        │
└──────────┬──────────┘        └─────────────────────────────┘
           │ Kafka events
┌──────────▼──────────┐
│  Event Router :8082  │
│  Routes by severity  │
└──────────┬──────────┘
           │
┌──────────▼──────────┐   ┌──────────────────────────────────┐
│  Datasource          │   │  Infrastructure                  │
│  SNMP/syslog sim     │   │  PostgreSQL :5432                │
│                      │   │  Kafka :9092 + Zookeeper :2181   │
└──────────────────────┘   │  PgAdmin :5050 (GUI)            │
                            │  Kafka UI :8090 (GUI)           │
                            └──────────────────────────────────┘
```

For full architecture detail see → [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## Choose Your Path

| Path | When to use | Time |
|------|-------------|------|
| [1. Docker — Full Stack](#1-docker-full-stack-recommended) | New machine, demos, onboarding, just needs to work | ~5 min |
| [2. Local Development](#2-local-development) | Actively writing backend or frontend code | ~20 min |
| [3. Cloud — Railway + Vercel](#3-cloud-railway--vercel) | Shared / persistent hosted deployment | ~30 min |

---

## Prerequisites

Install these before starting. Check each with the command shown.

| Tool | Min version | Check | Install |
|------|------------|-------|---------|
| Docker Desktop | 24+ | `docker --version` | [docker.com/get-started](https://www.docker.com/get-started) |
| Docker Compose | v2 (bundled) | `docker compose version` | Included with Docker Desktop |
| Git | any | `git --version` | [git-scm.com](https://git-scm.com) |
| Go | 1.24+ | `go version` | [go.dev/dl](https://go.dev/dl) *(local dev only)* |
| Node.js | 18+ | `node --version` | [nodejs.org](https://nodejs.org) *(local dev + cloud only)* |

**Docker alone** is enough for Path 1. Go and Node are only needed if you run services outside containers.

---

## 1. Docker — Full Stack (Recommended)

All 11 services run as containers. Zero manual dependency setup beyond Docker.

### Step 1 — Clone the repo

```bash
git clone https://github.com/bionicop/sentrix.git
cd sentrix

# The project uses Git submodules — initialise them all
git submodule update --init --recursive
```

> **Why submodules?** Each service (ui, ingestor, infra, ai-core, etc.) is its own Git repository. The root repo links them together via submodules. `--recursive` pulls all nested submodule content.

### Step 2 — Create the environment file

```bash
cd infra/prod
cp .env.example .env
```

Open `infra/prod/.env` in any text editor. You must fill in two values — everything else already has working defaults for a local Docker setup:

```bash
# Generate a cryptographically random secret (32+ chars required)
# Run this in your terminal and paste the output:
#   openssl rand -hex 32
JWT_SECRET=PASTE_GENERATED_SECRET_HERE

# Any password — this becomes the local PostgreSQL database password
POSTGRES_PASSWORD=choose_any_password_here
```

**What each section in the .env does:**

| Section | What it controls | Change it? |
|---------|-----------------|-----------|
| `JWT_SECRET` / `POSTGRES_PASSWORD` | Authentication + database access | **Yes — required** |
| `POSTGRES_*` / `DB_*` / `DATABASE_URL` | PostgreSQL connection | No — Docker hostnames are correct |
| `KAFKA_BROKER` | Kafka connection | No — Docker hostname |
| `INGESTOR_CORE_URL` / `EVENT_ROUTER_URL` / `API_GATEWAY_URL` | Internal service URLs | No — Docker network |
| `CORS_ALLOWED_ORIGINS` / `FRONTEND_URL` | What origins the API accepts | Only if using a custom domain |
| `DEMO_PASSWORD` | Password for demo/fallback login | Optional — defaults to `admin123` |
| `PGADMIN_*` | PgAdmin GUI credentials | Optional |
| `SMTP_*` | Email sending | Optional — leave blank to skip |
| `GOOGLE_CLIENT_*` | Google OAuth | Optional — leave blank to disable |
| `WATSONX_*` | IBM Watson AI | Optional — leave blank for placeholder AI data |

> For the full explanation of every variable see → [ENVIRONMENT.md](./ENVIRONMENT.md)

### Step 3 — Build and start all services

```bash
# Still inside infra/prod/
docker compose up -d --build
```

What happens during the build:
- Docker pulls base images (postgres, kafka, node, golang)
- Go services are compiled inside their build containers
- React UI is built and served via a Node server
- First build: **3–5 minutes** depending on internet speed
- Subsequent starts: **~30 seconds** (images are cached)

Watch it start up:
```bash
docker compose logs -f
# Press Ctrl+C to stop watching logs (services keep running)
```

### Step 4 — Verify all services are healthy

```bash
docker compose ps
```

Wait until all containers reach a stable state:

| Container | Expected status | What it does |
|-----------|----------------|--------------|
| `postgres` | `Up (healthy)` | Main database |
| `zookeeper` | `Up (healthy)` | Kafka coordination |
| `kafka` | `Up (healthy)` | Event message queue |
| `api-gateway` | `Up` | Primary REST API (port 8080) |
| `ingestor-core` | `Up` | Receives SNMP/syslog events (port 8001) |
| `event-router` | `Up` | Routes events to Kafka (port 8082) |
| `ai-core` | `Up` | Watson AI analysis (port 9000) |
| `datasource` | `Up` | Simulates network device events |
| `ui` | `Up` | React frontend (port 3000) |
| `pgadmin` | `Up` | Database GUI (port 5050) |
| `kafka-ui` | `Up` | Kafka management GUI (port 8090) |

If any service shows `Restarting`:
```bash
docker compose logs <service-name>
# e.g.: docker compose logs api-gateway
```
See [Troubleshooting](#troubleshooting) for common fixes.

### Step 5 — Verify the API is responding

```bash
curl http://localhost:8080/api/v1/health
```

Expected response:
```json
{"status":"ok","database":"connected","version":"1.0.0"}
```

If you get `connection refused`, wait 15 seconds — the API gateway waits for Postgres and Kafka to become healthy before accepting connections.

### Step 6 — Open the UI and log in

Open **http://localhost:3000** in your browser.

**Default login:**
```
Email:    admin@admin.com
Password: admin123
```

This is the only account created by the database seed script. It has the `sysadmin` role — full access to every feature including user management and the audit log.

**Within 60 seconds** of startup, alerts will start appearing on the dashboard. The `datasource` container generates simulated SNMP traps and syslog messages continuously, flowing through the full data pipeline into PostgreSQL.

To create accounts with other roles: log in as admin → sidebar → **Administration → User Management → Create User**.

The 5 available roles:

| Role identifier | What they see |
|----------------|---------------|
| `sysadmin` | Everything — all 22 features, user management, audit log |
| `network-admin` | Devices, device groups, topology, alert config |
| `senior-eng` | Architecture view, trends, performance analytics |
| `sre` | SLA, incidents, service status, reliability focus |
| `network-ops` | Alerts, tickets, dashboard — day-to-day NOC operations |

### Step 7 — Access the admin GUI tools (optional)

**PgAdmin** (database browser): http://localhost:5050
- Login with `PGADMIN_EMAIL` and `PGADMIN_PASSWORD` from your `.env` (defaults: `admin@sentrix.local` / `admin`)
- To connect to the database: right-click Servers → Register → Server
  - Host: `postgres` (Docker network name)
  - Port: `5432`
  - Database: `noc_alerts`
  - Username: value of `POSTGRES_USER` (default: `admin`)
  - Password: value of `POSTGRES_PASSWORD`

**Kafka UI** (message queue browser): http://localhost:8090
- No login required
- Shows live event flow through the `alerts` and `events` topics

### ARM machines (Apple Silicon, Oracle Cloud, Raspberry Pi)

Confluent Kafka has no ARM64 images. Use the ARM override file:

```bash
docker compose -f docker-compose.yml -f docker-compose.arm.yml up -d --build
```

This replaces Confluent Kafka + Zookeeper with Bitnami Kafka running in KRaft mode (no Zookeeper needed). Every other service is identical.

### Day-to-day Docker commands

```bash
# Start everything (after initial build)
docker compose up -d

# Stop everything, keep data volumes
docker compose down

# Follow live logs for all services
docker compose logs -f

# Follow logs for one service
docker compose logs -f api-gateway

# Restart a single service (e.g. after code change)
docker compose restart api-gateway

# Rebuild a single service
docker compose build api-gateway && docker compose up -d api-gateway

# Full reset — DELETES ALL DATA (alerts, tickets, users, etc.)
docker compose down -v && docker compose up -d --build
```

---

## 2. Local Development

Run Go services directly on your machine with hot-reload. Use Docker only for infrastructure (PostgreSQL + Kafka). The React frontend runs with Vite's dev server.

**Use this when:** you are actively changing Go handler code or React components and need fast iteration without rebuilding containers.

### Step 1 — Start infrastructure containers only

```bash
cd infra/prod
cp .env.example .env
# Fill in JWT_SECRET and POSTGRES_PASSWORD as above
```

Start only the database and message queue — not the application services:

```bash
docker compose up -d postgres kafka zookeeper
```

Wait ~15 seconds:
```bash
docker compose ps
# postgres and kafka must show "healthy" before proceeding
```

**Expose Kafka to your host machine:**

The default docker-compose uses `expose:` (Docker-internal only) for Kafka. Go services running on your machine can't reach it. Fix this by adding a port mapping to `infra/prod/docker-compose.yml`:

```yaml
kafka:
  ports:
    - "9092:9092"   # Add this line
  expose:
    - "9092"        # Keep the existing line
```

Apply the change:
```bash
docker compose up -d kafka
```

### Step 2 — Configure backend environment

```bash
# From repo root
cp ingestor/.env.example ingestor/.env
```

Edit `ingestor/.env`. The critical differences from Docker setup — your services are running on `localhost`, not Docker hostnames:

```bash
# ── MUST MATCH infra/prod/.env ────────────────────────────────────────────────
JWT_SECRET=<same value as infra/prod/.env>
POSTGRES_PASSWORD=<same value as infra/prod/.env>

# ── HOST MACHINE ADDRESSES (not Docker service names) ─────────────────────────
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_DB=noc_alerts
POSTGRES_SSL_MODE=disable

KAFKA_BROKERS=localhost:9092

# ── LOCAL SERVICE URLS ────────────────────────────────────────────────────────
API_GATEWAY_URL=http://localhost:8080
INGESTOR_CORE_URL=http://localhost:8001
EVENT_ROUTER_URL=http://localhost:8082
AI_CORE_URL=http://localhost:9000

# ── CORS: include Vite dev server ─────────────────────────────────────────────
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:5174,http://localhost:3000
FRONTEND_URL=http://localhost:5173

# ── OTHER ─────────────────────────────────────────────────────────────────────
GIN_MODE=debug
DEMO_PASSWORD=admin123
LOG_LEVEL=info
```

> For the complete list of every available variable see → [ENVIRONMENT.md](./ENVIRONMENT.md)

### Step 3 — Configure AI Core (optional)

The AI Core service uses its own separate environment file:

```bash
cp ai-core/.env.example ai-core/.env
```

If you have Watson credentials, add them. If not, leave blank — the service starts fine and returns placeholder AI analysis data.

```bash
# ai-core/.env
WATSONX_API_KEYS=         # leave blank for placeholder mode
WATSONX_REGION=eu-gb      # eu-gb or us-south
WATSONX_PROJECT_ID=       # leave blank for placeholder mode
PORT=9000
LOG_LEVEL=info
```

How to get Watson credentials → see [Optional Integrations — IBM Watson AI](#ibm-watson-ai)

### Step 4 — Configure Datasource (optional)

```bash
cp datasource/.env.example datasource/.env
```

Default values are correct for local dev — no edits needed:

```bash
INGESTOR_CORE_URL=http://localhost:8001
LOG_LEVEL=info
```

### Step 5 — Understand the Go workspace

The repo root has a `go.work` file linking 6 Go modules:

```
go.work
├── ai-core/
├── datasource/
├── ingestor/api_gateway/
├── ingestor/event_router/
├── ingestor/ingestor_core/
└── ingestor/shared/
```

When running a service individually with `go run main.go`, Go tries to resolve all dependencies through the workspace, which causes cross-module conflicts. **Always prefix with `GOWORK=off`** when running individual services:

```bash
GOWORK=off go run main.go
```

Or set it for your whole shell session:
```bash
export GOWORK=off
```

### Step 6 — Start backend services

Open **one terminal per service**. Start them in this exact order — each service depends on the one before it being ready.

**Terminal 1 — Ingestor Core**
```bash
cd ingestor/ingestor_core
GOWORK=off go run main.go
```
Wait for: `Ingestor Core listening on :8001`

What it does: receives raw SNMP traps and syslog messages from the datasource. All event ingestion flows through here first.

**Terminal 2 — Event Router**
```bash
cd ingestor/event_router
GOWORK=off go run main.go
```
Wait for: `Event Router listening on :8082`

What it does: reads events from Ingestor Core, classifies them by severity, routes them to appropriate Kafka topics.

**Terminal 3 — API Gateway**
```bash
cd ingestor/api_gateway
GOWORK=off go run main.go
```
Wait for: `API Gateway listening on :8080`

What it does: the main backend. Handles all 101 REST API routes, JWT authentication, RBAC, GORM queries to PostgreSQL. The UI talks only to this service. See → [API.md](./API.md)

**Terminal 4 — Datasource** *(optional but recommended — generates test data)*
```bash
cd datasource
GOWORK=off go run main.go
```

What it does: simulates a network with 124 devices sending SNMP traps and syslog messages. Without it the dashboard is empty.

**Terminal 5 — AI Core** *(optional — for Watson AI features)*
```bash
cd ai-core
GOWORK=off go run main.go
```

What it does: receives alert data, calls IBM Watson AI API, returns root cause analysis and recommendations. Without Watson credentials it returns structured placeholder data.

**Verify the API is up:**
```bash
curl http://localhost:8080/api/v1/health
# Expected: {"status":"ok","database":"connected",...}
```

### Step 7 — Start the frontend

```bash
cd ui
cp .env.example .env
```

The default `.env` already has `VITE_API_BASE_URL=http://localhost:8080`. No edits needed for local dev.

```bash
npm install    # first time only
npm run dev
```

UI available at **http://localhost:5173**

Login: `admin@admin.com` / `admin123`

### Step 8 — Build verification

Before committing any changes, verify both the Go and TypeScript builds are clean:

```bash
# Go — from repo root, tests all 6 modules at once
go build ./...

# TypeScript — from ui/
cd ui && npx tsc --noEmit
```

Both must complete with **zero errors**. If either fails, fix before pushing — CI will catch it anyway.

---

## 3. Cloud — Railway + Vercel

### Current live deployment

| Service | Platform | URL |
|---------|----------|-----|
| Frontend | Vercel | https://ui-bionics-projects.vercel.app |
| API Gateway | Railway | https://sentrix-api-production-1aec.up.railway.app |
| AI Core | Railway | https://ai-core-production-9cdb.up.railway.app |
| Database | Railway (PostgreSQL plugin) | Internal — `postgres.railway.internal` |

For a fresh deployment to a new environment, follow the steps below. For the existing deployment, use the Railway and Vercel dashboards.

> For full cloud deployment detail and Railway CLI usage see → [DEPLOYMENT.md](./DEPLOYMENT.md)

### Step 1 — Install tooling and authenticate

```bash
# Railway CLI
npm install -g @railway/cli
railway login

# Vercel CLI
npm install -g vercel
vercel login
```

### Step 2 — Create Railway project

In the [Railway dashboard](https://railway.app/dashboard):
1. **New Project**
2. Add a **PostgreSQL** plugin — credentials are auto-provisioned
3. Create two services: `sentrix-api` and `sentrix-ai`

### Step 3 — Deploy API Gateway

```bash
# From repo root
railway link    # select your project → sentrix-api service
railway up
```

Railway uses `railway.json` at the root — it builds `ingestor/api_gateway` with `GOWORK=off` and starts `./server`.

**Required environment variables** — set these in the Railway dashboard for `sentrix-api`:

```
# ── REQUIRED ──────────────────────────────────────────────────────────────────
JWT_SECRET=<openssl rand -hex 32>
GIN_MODE=release
DEMO_PASSWORD=admin123

# ── DATABASE (from Railway PostgreSQL plugin — copy from plugin's Variables tab)
POSTGRES_HOST=postgres.railway.internal
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<from Railway plugin>
POSTGRES_DB=railway
POSTGRES_SSLMODE=disable

# ── CORS + FRONTEND (fill in your Vercel URL after Step 5)
CORS_ALLOWED_ORIGINS=https://your-app.vercel.app
FRONTEND_URL=https://your-app.vercel.app

# ── AI CORE (fill in after Step 4)
AI_CORE_URL=https://your-ai-core.up.railway.app

# ── OPTIONAL: GOOGLE OAUTH
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URL=https://your-api.up.railway.app/api/v1/auth/google/callback

# ── OPTIONAL: SMTP EMAIL
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=
SMTP_FROM_NAME=Sentrix
```

> On first deploy, GORM auto-migration creates all database tables. The `admin@admin.com` seed user is **not** created on Railway — use `DEMO_PASSWORD` to log in, then create users via the admin panel.

### Step 4 — Deploy AI Core

```bash
railway link    # select sentrix-ai service
railway up
```

**Environment variables for `sentrix-ai`:**

```
WATSONX_API_KEYS=<your IBM watsonx API key>
WATSONX_REGION=eu-gb
WATSONX_PROJECT_ID=<your project ID>
WATSONX_MODEL_ID=meta-llama/llama-3-3-70b-instruct
GIN_MODE=release
FORWARD_TO_GATEWAY=false
PORT=9000
```

> **Watson model IDs by region:**
> - `eu-gb` → `meta-llama/llama-3-3-70b-instruct`
> - `us-south` → `ibm/granite-13b-instruct-v2`
>
> See the [watsonx model catalog](https://dataplatform.cloud.ibm.com/wx/samples) for your region.

Once deployed, copy the public URL and set it as `AI_CORE_URL` on `sentrix-api`.

### Step 5 — Deploy Frontend to Vercel

```bash
cd ui
npm run build    # verify it builds locally first
```

Create `ui/.env.production` (do not commit this file — it's in `.gitignore`):

```bash
VITE_API_BASE_URL=https://sentrix-api-production-1aec.up.railway.app
VITE_API_VERSION=v1
VITE_API_TIMEOUT=30000
VITE_USE_MOCK=false
VITE_ENABLE_REALTIME_UPDATES=true
VITE_ENABLE_TICKETING=true
VITE_ENABLE_RAG_INSIGHTS=true
VITE_ENABLE_GOOGLE_AUTH=false     # true if Google OAuth is configured
VITE_GOOGLE_CLIENT_ID=            # fill in if VITE_ENABLE_GOOGLE_AUTH=true
VITE_ALERT_POLLING_INTERVAL=30000
VITE_DASHBOARD_REFRESH_INTERVAL=30000
VITE_MAX_ALERTS_PER_PAGE=20
VITE_DEFAULT_THEME=system
VITE_APP_NAME=Sentrix
VITE_APP_VERSION=1.0.0
```

Deploy:
```bash
vercel --prod
```

The `ui/vercel.json` is already committed — it handles SPA routing so refreshing a page doesn't 404:
```json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```

### Step 6 — Update CORS after Vercel deploy

Once Vercel gives you your domain, go back to the Railway dashboard for `sentrix-api` and update:
- `CORS_ALLOWED_ORIGINS` → your Vercel domain
- `FRONTEND_URL` → your Vercel domain

Railway redeploys automatically after variable changes.

---

## Database Initialisation

**Docker path:** When the `postgres` container starts against a fresh volume, it automatically runs `infra/prod/postgres-init/init.sql`. This script:
- Creates all 19 tables (alerts, tickets, users, devices, audit_logs, runbooks, etc.)
- Seeds 10 runbook templates
- Creates the default admin account: `admin@admin.com` / `admin123` (role: `sysadmin`)

This runs **once** on first start. If you wipe volumes with `docker compose down -v`, it runs again on the next start.

**Railway/cloud path:** GORM auto-migration creates tables on startup. No seed data — create your first user through the API or use demo login.

---

## First Login and Verification Checklist

Run through this after any setup to confirm everything is wired correctly.

**1. API health check**
```bash
# Docker / local dev
curl http://localhost:8080/api/v1/health

# Cloud
curl https://sentrix-api-production-1aec.up.railway.app/api/v1/health
```
Expected: `{"status":"ok","database":"connected",...}`

**2. UI loads without error**
- Docker: http://localhost:3000
- Local dev: http://localhost:5173
- Cloud: https://ui-bionics-projects.vercel.app

**3. Login succeeds**
```
Email:    admin@admin.com
Password: admin123
```

**4. Dashboard shows data**
- Alerts should appear within 60 seconds (Docker — datasource is running)
- If empty after 2 minutes: `docker compose logs datasource`

**5. Sidebar navigation is complete**
As `sysadmin` you should see all 5 navigation groups:
- Operations (Dashboard, Alerts, Tickets, On-Call, Service Status)
- Infrastructure (Devices, Network Topology, Device Groups)
- Analytics (Trends, Incident History, SLA Reports, Reports Hub)
- Configuration (Alert Configuration, Runbooks)
- Administration (Audit Log) — *sysadmin only*

**6. API data is real**
Navigate to **Trends** — the peak hour chart and average resolution time should show actual computed values, not static placeholders.

---

## Optional Integrations

### IBM Watson AI

Without credentials, AI analysis sections show structured placeholder data — the platform works fully, just without live AI inference.

**Setup steps:**
1. Create a project at [cloud.ibm.com](https://cloud.ibm.com) → watsonx → Projects
2. From the project: **Manage → Access (IAM) → API keys** → create an API key
3. Copy the **Project ID** from the project's Manage tab
4. Add to your `.env`:
   ```bash
   WATSONX_API_KEYS=your-api-key-here
   WATSONX_REGION=eu-gb          # must match where your project is hosted
   WATSONX_PROJECT_ID=your-project-id
   ```
5. Rebuild `ai-core`:
   ```bash
   # Docker:
   docker compose up -d --build ai-core

   # Local dev: restart Terminal 5 (ai-core)
   ```

### Google OAuth

Without credentials, the "Sign in with Google" button shows a friendly message. Email/password login works normally.

**Setup steps:**
1. Go to [console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → Credentials
2. Click **Create Credentials → OAuth 2.0 Client ID**
3. Application type: **Web application**
4. Add authorised redirect URIs:
   - Local: `http://localhost:8080/api/v1/auth/google/callback`
   - Production: `https://sentrix-api-production-1aec.up.railway.app/api/v1/auth/google/callback`
5. Copy the Client ID and Client Secret
6. Add to your backend `.env`:
   ```bash
   GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your-secret
   GOOGLE_REDIRECT_URL=http://localhost:8080/api/v1/auth/google/callback
   ```
7. Add to `ui/.env`:
   ```bash
   VITE_ENABLE_GOOGLE_AUTH=true
   VITE_GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
   ```

### SMTP Email

Without SMTP, email features (password reset, verification emails, alert notifications) silently skip. No errors, just no emails.

**Setup with Gmail App Password:**
1. Enable 2-factor auth on the Gmail account
2. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) → Select Mail → Generate
3. Copy the 16-character password (spaces don't matter)
4. Add to `.env`:
   ```bash
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USERNAME=youraddress@gmail.com
   SMTP_PASSWORD=abcd efgh ijkl mnop    # the 16-char app password
   SMTP_FROM=youraddress@gmail.com
   SMTP_FROM_NAME=Sentrix
   ```

---

## Troubleshooting

### Container keeps restarting

```bash
docker compose logs <container-name>
```

| Container | Common cause | Fix |
|-----------|-------------|-----|
| `api-gateway` | Wrong `JWT_SECRET` or `POSTGRES_PASSWORD` | Check `infra/prod/.env` — must match what Postgres was initialised with |
| `ingestor-core` | Same | Same fix |
| `kafka` | Zookeeper not ready yet | Wait 30s, run `docker compose restart kafka` |
| `datasource` | Ingestor Core not yet up | Run `docker compose restart datasource` after api-gateway is healthy |
| `ui` | Build failed | Run `docker compose logs ui` and check for npm build errors |

### API gateway returns "connection refused"

The API gateway performs health checks against Postgres and Kafka before accepting connections. On first start this can take 30–60 seconds. Check:
```bash
docker compose ps
# Both postgres and kafka must show "healthy" — not just "Up"
```

### No alerts on dashboard after 2 minutes

The data flow is: datasource → ingestor-core → event-router → Kafka → api-gateway → database → UI.

Check each link:
```bash
docker compose logs datasource     # Should show: "Sending event to ingestor-core"
docker compose logs ingestor-core  # Should show: events being received
docker compose logs event-router   # Should show: routing events to Kafka
docker compose logs api-gateway    # Should show: no errors
```

If datasource is the issue: `docker compose restart datasource`

### 401 Unauthorized

`JWT_SECRET` must be the same value in every service. In Docker all services share `infra/prod/.env`, so this shouldn't happen. In local dev, check that `ingestor/.env` has the same `JWT_SECRET` as `infra/prod/.env`.

### Local dev: Kafka connection refused

```
dial tcp 127.0.0.1:9092: connect: connection refused
```

Kafka only exposes port 9092 inside the Docker network by default. Add to `infra/prod/docker-compose.yml` under the `kafka:` service:
```yaml
ports:
  - "9092:9092"
```
Then: `docker compose up -d kafka`

### Local dev: Go module errors / missing packages

The `go.work` workspace file at root causes conflicts when running individual services. Always use:
```bash
GOWORK=off go run main.go
```
Or export once: `export GOWORK=off`

### TypeScript errors

```bash
cd ui && npx tsc --noEmit
```

Fix all errors before running the dev server. The most common cause is a recently modified `.tsx` file with a type mismatch on a Carbon component prop.

### Full reset

```bash
cd infra/prod

# Wipe all volumes — this deletes ALL data (alerts, tickets, users, audit logs)
docker compose down -v

# Rebuild everything from scratch
docker compose up -d --build
```

The database recreates all tables and re-seeds `admin@admin.com` from `init.sql`.

---

## Service Port Reference

| Service | Port | Reachable from |
|---------|------|----------------|
| Frontend (Docker) | 3000 | Public |
| Frontend (Vite dev) | 5173 | Public |
| API Gateway | 8080 | Public |
| Ingestor Core | 8001 | Docker internal only |
| Event Router | 8082 | Docker internal only |
| AI Core | 9000 | Docker internal only |
| PostgreSQL | 5432 | Docker internal only |
| PgAdmin | 5050 | `127.0.0.1` only |
| Kafka | 9092 | Docker internal / `localhost` if port-mapped |
| Zookeeper | 2181 | Docker internal only |
| Kafka UI | 8090 | `127.0.0.1` only |

---

## Project Structure Reference

```
sentrix/
├── infra/                        ← Infrastructure and deployment
│   └── prod/
│       ├── docker-compose.yml    ← Run all Docker commands from here
│       ├── docker-compose.arm.yml← ARM override (Apple Silicon, Oracle Cloud)
│       ├── .env.example          ← Template — copy to .env and fill in secrets
│       └── postgres-init/
│           └── init.sql          ← Auto-runs on first Postgres start
│                                    Creates all tables + seeds admin@admin.com
│
├── ingestor/                     ← All Go backend services
│   ├── api_gateway/              ← Primary REST API (port 8080) — 18 handlers, 101 routes
│   ├── event_router/             ← Event routing to Kafka (port 8082)
│   ├── ingestor_core/            ← Raw event ingestion (port 8001)
│   ├── shared/                   ← Shared models, RBAC, middleware, DB repos
│   ├── agents_api/               ← Watson AI bridge
│   └── .env.example              ← Copy to .env for local dev
│
├── ai-core/                      ← IBM Watson AI analysis service (port 9000)
│   └── .env.example
│
├── datasource/                   ← Network device simulator (SNMP + syslog)
│   └── .env.example
│
├── ui/                           ← React 19 + TypeScript + IBM Carbon frontend
│   ├── src/
│   │   ├── pages/                ← 33 page components (22 main features)
│   │   ├── components/           ← Shared UI components
│   │   ├── features/             ← Feature modules (auth, alerts, tickets...)
│   │   └── shared/               ← API client, services, constants, types
│   ├── .env.example              ← Copy to .env for local dev
│   ├── .env.production           ← Create for production (gitignored)
│   └── vercel.json               ← SPA routing — already committed
│
├── docs/                         ← All documentation
│   └── docs/
│       ├── SETUP_PLAYBOOK.md     ← You are here
│       ├── ENVIRONMENT.md        ← Full env variable reference
│       ├── DEPLOYMENT.md         ← Detailed deployment guide
│       ├── ARCHITECTURE.md       ← System design and data flow
│       ├── API.md                ← All 101 REST endpoints
│       └── UI_SCREENS.md         ← All 33 frontend pages
│
├── go.work                       ← Go workspace (6 modules)
│                                    Use GOWORK=off when running services individually
├── railway.json                  ← Railway build config for API Gateway
└── walkthrough/                  ← Remotion product demo video
    ├── VOICEOVER_SCRIPT_TTS.txt  ← TTS narration script (46 sections)
    └── AUDIO_INTEGRATION.md      ← How to wire audio into the Remotion video
```

---

## Related Documentation

| Doc | What it covers |
|-----|---------------|
| [ENVIRONMENT.md](./ENVIRONMENT.md) | Every environment variable for every service, with defaults and descriptions |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Railway CLI usage, Vercel config, ARM deployment, environment variable tables |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Service responsibilities, data pipeline, database tables, RBAC design |
| [API.md](./API.md) | All 101 REST endpoints with methods, paths, required roles, and descriptions |
| [UI_SCREENS.md](./UI_SCREENS.md) | All 33 frontend pages — what they show, which API endpoints they use |
