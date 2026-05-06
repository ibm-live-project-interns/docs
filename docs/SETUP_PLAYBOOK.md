# Sentrix — Environment Setup Playbook

Everything needed to run Sentrix in any environment, from a blank machine. Follow one path end to end — you do not need to read the others.

---

## Choose Your Path

| Path | Best for | Approx time |
|------|----------|-------------|
| [1. Docker — Full Stack](#1-docker-full-stack-recommended) | New machine, demos, onboarding, anything that just needs to work | ~5 min |
| [2. Local Development](#2-local-development) | Actively developing backend or frontend code | ~20 min |
| [3. Cloud — Railway + Vercel](#3-cloud-railway--vercel) | Shared or persistent hosted deployment | ~30 min |

---

## Prerequisites

| Tool | Minimum version | Install check |
|------|----------------|---------------|
| Docker + Docker Compose | Docker 24+ | `docker --version` |
| Go | 1.24+ | `go version` *(local dev + cloud only)* |
| Node.js | 18+ | `node --version` *(local dev + cloud only)* |

Docker alone is sufficient for the Docker path. Go and Node are only needed if you are running services outside of containers.

---

## 1. Docker — Full Stack (Recommended)

Runs all 11 services inside containers. Nothing to install beyond Docker.

### Step 1 — Get the code

```bash
git clone <repo-url>
cd ibm-live-project-intern
```

### Step 2 — Create the environment file

```bash
cd infra/prod
cp .env.example .env
```

Open the `.env` file you just created and set these two values — everything else has working defaults:

```bash
# Generate a secure key: openssl rand -hex 32
JWT_SECRET=paste-your-generated-secret-here

# Any password you want for the local database
POSTGRES_PASSWORD=choose-any-password
```

Leave all other values at their defaults for now. Watson AI, Google OAuth, and email are optional — the platform works without them (see [Optional Integrations](#optional-integrations)).

**Full `.env` for reference:**

```bash
# ── REQUIRED ──────────────────────────────────────────────────────────────────
JWT_SECRET=<openssl rand -hex 32>
POSTGRES_PASSWORD=<any password>

# ── DATABASE (Docker internal — do not change) ─────────────────────────────────
POSTGRES_USER=admin
POSTGRES_DB=noc_alerts
DB_HOST=postgres
DB_PORT=5432
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
DATABASE_URL=postgresql://admin:${POSTGRES_PASSWORD}@postgres:5432/noc_alerts

# ── KAFKA (Docker internal — do not change) ────────────────────────────────────
KAFKA_BROKER=kafka:9092

# ── INTERNAL SERVICE URLS (Docker internal — do not change) ───────────────────
INGESTOR_CORE_URL=http://ingestor-core:8001
EVENT_ROUTER_URL=http://event-router:8082
API_GATEWAY_URL=http://api-gateway:8080

# ── CORS + APP ─────────────────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
FRONTEND_URL=http://localhost:3000
APP_NAME=Sentrix

# ── DEMO MODE ──────────────────────────────────────────────────────────────────
# Password used when the database is unavailable (fallback demo login)
DEMO_PASSWORD=admin123

# ── RATE LIMITING ──────────────────────────────────────────────────────────────
RATE_LIMIT_RATE=500
RATE_LIMIT_BURST=50

# ── PGADMIN GUI (http://localhost:5050) ────────────────────────────────────────
PGADMIN_EMAIL=admin@sentrix.local
PGADMIN_PASSWORD=admin

# ── OPTIONAL: SMTP EMAIL ───────────────────────────────────────────────────────
# Leave blank — email features silently skip when not configured
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=
SMTP_FROM_NAME=Sentrix

# ── OPTIONAL: GOOGLE OAUTH ─────────────────────────────────────────────────────
# Leave blank — Google login button shows a message if not configured
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URL=http://localhost:8080/api/v1/auth/google/callback

# ── OPTIONAL: IBM WATSON AI ────────────────────────────────────────────────────
# Leave blank — AI analysis sections show placeholder data without Watson
WATSONX_API_KEYS=
WATSONX_REGION=eu-gb
WATSONX_PROJECT_ID=
FORWARD_TO_GATEWAY=false
```

### Step 3 — Build and start

```bash
# Still inside infra/prod/
docker compose up -d --build
```

First build: 3–5 minutes (downloads base images and compiles Go services).  
Subsequent starts: ~30 seconds.

### Step 4 — Wait for all services to be healthy

```bash
docker compose ps
```

Expected state for all 11 containers:

| Container | Expected state |
|-----------|---------------|
| postgres | Up (healthy) |
| kafka | Up (healthy) |
| zookeeper | Up (healthy) |
| api-gateway | Up |
| ingestor-core | Up |
| event-router | Up |
| ai-core | Up |
| datasource | Up |
| ui | Up |
| pgadmin | Up |
| kafka-ui | Up |

If any service shows `Restarting`, check its logs: `docker compose logs <service-name>`

### Step 5 — Verify and log in

**Health check:**
```bash
curl http://localhost:8080/api/v1/health
```
Expected: `{"status":"ok","database":"connected",...}`

**Open the UI:** http://localhost:3000

**Login credentials:**
```
Email:    admin@admin.com
Password: admin123
```

This is the only user seeded by default. It has the `sysadmin` role — full access to all 22 features. To create users with other roles, log in and go to **Administration → User Management**.

You should see alerts appearing on the dashboard within 60 seconds — the `datasource` service starts generating simulated network events immediately.

### ARM machines (Apple Silicon, Oracle Cloud, Raspberry Pi)

Confluent Kafka has no ARM images. Use the ARM override file instead:

```bash
docker compose -f docker-compose.yml -f docker-compose.arm.yml up -d --build
```

This swaps in Bitnami Kafka running in KRaft mode (no Zookeeper needed). Every other service is unchanged.

### Useful commands

```bash
# Watch live logs for all services
docker compose logs -f

# Watch a specific service
docker compose logs -f api-gateway

# Restart a single service
docker compose restart api-gateway

# Stop everything, keep database data
docker compose down

# Full reset — wipes ALL data including the database
docker compose down -v && docker compose up -d --build
```

---

## 2. Local Development

Run Go services directly on your machine with `go run`. Use Docker only for the infrastructure (PostgreSQL and Kafka). The frontend runs with Vite.

Use this path when you are actively changing backend or frontend code and need hot-reload / fast iteration.

### Step 1 — Start infrastructure

```bash
cd infra/prod
cp .env.example .env
# Fill in JWT_SECRET and POSTGRES_PASSWORD as in the Docker path above
```

Start only the infrastructure containers — not the application services:

```bash
docker compose up -d postgres kafka zookeeper
```

Wait ~15 seconds, then verify:
```bash
docker compose ps
# postgres and kafka should show "healthy"
```

**Important:** The default docker-compose only exposes Kafka internally (Docker network). For Go services running on your host machine to reach Kafka, you need to temporarily add a port mapping. Edit `infra/prod/docker-compose.yml` and add under the `kafka:` service:

```yaml
kafka:
  ports:
    - "9092:9092"
```

Then restart Kafka:
```bash
docker compose up -d kafka
```

### Step 2 — Configure backend environment

```bash
cp ingestor/.env.example ingestor/.env
```

Open `ingestor/.env` and update these values to match your local setup:

```bash
# Must match what you set in infra/prod/.env
JWT_SECRET=<same value as infra/prod/.env>
POSTGRES_PASSWORD=<same value as infra/prod/.env>

# Host machine addresses (not Docker service names)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
KAFKA_BROKERS=localhost:9092

# Service URLs for local host
API_GATEWAY_URL=http://localhost:8080
INGESTOR_CORE_URL=http://localhost:8001
EVENT_ROUTER_URL=http://localhost:8082
AI_CORE_URL=http://localhost:9000

# CORS — include Vite dev server
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:5174,http://localhost:3000
FRONTEND_URL=http://localhost:5173

# Demo password (used when DB is temporarily unreachable)
DEMO_PASSWORD=admin123
```

### Step 3 — Configure AI Core environment (optional)

The AI Core service has its own separate environment file:

```bash
cp ai-core/.env.example ai-core/.env
```

If you have Watson credentials, fill them in. If not, leave the file as-is — the service starts without them and the API returns placeholder AI data.

```bash
# ai-core/.env
WATSONX_API_KEYS=       # leave blank if no Watson account
WATSONX_REGION=eu-gb
WATSONX_PROJECT_ID=     # leave blank if no Watson account
PORT=9000
LOG_LEVEL=info
```

### Step 4 — Configure datasource environment

```bash
cp datasource/.env.example datasource/.env
```

The default content is correct for local dev:

```bash
INGESTOR_CORE_URL=http://localhost:8001
LOG_LEVEL=info
```

### Step 5 — Start backend services in order

Open a separate terminal for each service. Start them in this exact sequence:

```bash
# Terminal 1 — Ingestor Core (must start first — receives all incoming events)
cd ingestor/ingestor_core
GOWORK=off go run main.go
# Wait for: "Ingestor Core listening on :8001"
```

```bash
# Terminal 2 — Event Router
cd ingestor/event_router
GOWORK=off go run main.go
# Wait for: "Event Router listening on :8082"
```

```bash
# Terminal 3 — API Gateway (primary REST API)
cd ingestor/api_gateway
GOWORK=off go run main.go
# Wait for: "API Gateway listening on :8080"
```

```bash
# Terminal 4 — Datasource simulator (generates test alert data)
cd datasource
GOWORK=off go run main.go
```

```bash
# Terminal 5 — AI Core (optional — for Watson AI features)
cd ai-core
GOWORK=off go run main.go
```

> **Why `GOWORK=off`?**  
> The repo root has a `go.work` workspace file that links all modules. When you run `go run main.go` inside an individual service directory, Go tries to resolve dependencies through the workspace, which can cause cross-module conflicts. `GOWORK=off` makes each service use only its own `go.mod`, which is the correct behaviour for running services independently.

**Verify the API is up:**
```bash
curl http://localhost:8080/api/v1/health
# Expected: {"status":"ok","database":"connected",...}
```

### Step 6 — Start the frontend

```bash
cd ui
cp .env.example .env
```

The default `.env` already points to `http://localhost:8080`. No changes needed unless your API is on a different port.

```bash
npm install
npm run dev
```

UI available at http://localhost:5173

**Login:** `admin@admin.com` / `admin123`

### Step 7 — Build verification

Before pushing any changes, always verify both compile clean:

```bash
# Go — from repo root (tests all 6 modules)
go build ./...

# TypeScript — from ui/
cd ui && npx tsc --noEmit
```

Both must produce zero errors.

---

## 3. Cloud — Railway + Vercel

### Overview

| Service | Platform | URL pattern |
|---------|----------|-------------|
| API Gateway (`sentrix-api`) | Railway | `https://sentrix-api-production-xxxx.up.railway.app` |
| AI Core (`sentrix-ai`) | Railway | `https://sentrix-ai-production-xxxx.up.railway.app` |
| Frontend | Vercel | `https://your-app.vercel.app` |
| Database | Railway (PostgreSQL plugin) | Internal Railway URL |

### Step 1 — Set up Railway

Install the CLI and create your project:

```bash
npm install -g @railway/cli
railway login
```

In the Railway dashboard:
1. Create a new project
2. Add a **PostgreSQL** plugin — Railway provisions the DB automatically
3. Create two services: `sentrix-api` and `sentrix-ai`

### Step 2 — Deploy the API Gateway (`sentrix-api`)

Link your local repo to the `sentrix-api` service and deploy:

```bash
# From repo root
railway link         # select your project and the sentrix-api service
railway up
```

Railway uses `railway.json` at the repo root, which builds `ingestor/api_gateway` with `GOWORK=off` and starts `./server`.

**Set these environment variables in the Railway dashboard for `sentrix-api`:**

```
# ── REQUIRED ────────────────────────────────────────────────────────────────
JWT_SECRET=<openssl rand -hex 32>
GIN_MODE=release
DEMO_PASSWORD=<password for demo logins>

# ── CORS + FRONTEND ──────────────────────────────────────────────────────────
# Fill in your Vercel URL after deploying the frontend
CORS_ALLOWED_ORIGINS=https://your-app.vercel.app
FRONTEND_URL=https://your-app.vercel.app

# ── DATABASE (from Railway PostgreSQL plugin) ────────────────────────────────
POSTGRES_HOST=postgres.railway.internal
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<from Railway PostgreSQL plugin credentials>
POSTGRES_DB=railway
POSTGRES_SSLMODE=disable

# ── AI CORE ──────────────────────────────────────────────────────────────────
# Fill in after deploying sentrix-ai below
AI_CORE_URL=https://sentrix-ai-production-xxxx.up.railway.app

# ── OPTIONAL: GOOGLE OAUTH ───────────────────────────────────────────────────
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URL=https://sentrix-api-production-xxxx.up.railway.app/api/v1/auth/google/callback

# ── OPTIONAL: SMTP ───────────────────────────────────────────────────────────
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=
SMTP_FROM_NAME=Sentrix
```

After the first deploy, Railway runs the database migrations automatically via GORM auto-migrate on startup. The `admin@admin.com` / `admin123` seed user is not created automatically on Railway — create your first user manually via the API or set `DEMO_PASSWORD` and use demo login.

### Step 3 — Deploy AI Core (`sentrix-ai`)

```bash
railway link         # select sentrix-ai service this time
railway up
```

**Set these environment variables for `sentrix-ai`:**

```
WATSONX_API_KEYS=<your IBM watsonx API key>
WATSONX_REGION=eu-gb
WATSONX_PROJECT_ID=<your project ID>
WATSONX_MODEL_ID=meta-llama/llama-3-3-70b-instruct
GIN_MODE=release
FORWARD_TO_GATEWAY=false
PORT=9000
LOG_LEVEL=info
```

> **Model availability by region:**  
> `eu-gb` → `meta-llama/llama-3-3-70b-instruct`  
> `us-south` → `ibm/granite-13b-instruct-v2`  
> Check the [watsonx model catalog](https://dataplatform.cloud.ibm.com/wx/samples) for your region.

Once deployed, copy the `sentrix-ai` public URL and set `AI_CORE_URL` on `sentrix-api`.

### Step 4 — Deploy the Frontend to Vercel

```bash
cd ui

# Build locally first to catch any errors
npm run build
```

Create `ui/.env.production` with your Railway API URL. **Do not commit this file.**

```bash
VITE_API_BASE_URL=https://sentrix-api-production-xxxx.up.railway.app
VITE_API_VERSION=v1
VITE_API_TIMEOUT=30000
VITE_USE_MOCK=false
VITE_ENABLE_REALTIME_UPDATES=true
VITE_ENABLE_TICKETING=true
VITE_ENABLE_RAG_INSIGHTS=true
VITE_ENABLE_GOOGLE_AUTH=false      # set true if you configured Google OAuth
VITE_GOOGLE_CLIENT_ID=             # fill in if VITE_ENABLE_GOOGLE_AUTH=true
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

Alternatively, set these same variables directly in the Vercel dashboard under **Project Settings → Environment Variables** and trigger a deploy from there.

The `ui/vercel.json` is already committed to the repo and handles SPA routing:
```json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```
No changes needed to this file.

**After deploying Vercel**, go back to Railway and update `sentrix-api`:
- `CORS_ALLOWED_ORIGINS` → your Vercel URL
- `FRONTEND_URL` → your Vercel URL

Redeploy `sentrix-api` for the CORS change to take effect.

---

## Complete Environment Variable Reference

### `infra/prod/.env` — Docker deployment

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET` | **Yes** | — | JWT signing key. Min 32 chars. `openssl rand -hex 32` |
| `POSTGRES_PASSWORD` | **Yes** | — | PostgreSQL password |
| `POSTGRES_USER` | No | `admin` | PostgreSQL username |
| `POSTGRES_DB` | No | `noc_alerts` | Database name |
| `DEMO_PASSWORD` | No | `admin123` | Fallback password when DB is unreachable |
| `CORS_ALLOWED_ORIGINS` | No | `http://localhost:3000,http://localhost:5173` | Comma-separated allowed CORS origins |
| `FRONTEND_URL` | No | `http://localhost:3000` | Used in email links |
| `RATE_LIMIT_RATE` | No | `500` | Max requests per time window |
| `RATE_LIMIT_BURST` | No | `50` | Burst allowance |
| `PGADMIN_EMAIL` | No | — | PgAdmin login email |
| `PGADMIN_PASSWORD` | No | — | PgAdmin login password |
| `SMTP_HOST` | No | — | SMTP server (e.g. `smtp.gmail.com`) |
| `SMTP_PORT` | No | `587` | SMTP port |
| `SMTP_USERNAME` | No | — | SMTP username / Gmail address |
| `SMTP_PASSWORD` | No | — | SMTP app password (not your Gmail password) |
| `SMTP_FROM` | No | — | From address in sent emails |
| `GOOGLE_CLIENT_ID` | No | — | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | No | — | Google OAuth client secret |
| `GOOGLE_REDIRECT_URL` | No | `http://localhost:8080/api/v1/auth/google/callback` | OAuth callback URL |
| `WATSONX_API_KEYS` | No | — | IBM watsonx API key |
| `WATSONX_REGION` | No | `eu-gb` | watsonx region (`eu-gb` or `us-south`) |
| `WATSONX_PROJECT_ID` | No | — | watsonx project ID |

### `ingestor/.env` — Local development only

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET` | **Yes** | — | Must be identical across all services |
| `POSTGRES_PASSWORD` | **Yes** | — | Must match the Postgres container |
| `POSTGRES_HOST` | No | `localhost` | Use `localhost` for local dev; `postgres` inside Docker |
| `POSTGRES_PORT` | No | `5432` | Postgres port |
| `POSTGRES_USER` | No | `admin` | Postgres username |
| `POSTGRES_DB` | No | `noc_alerts` | Database name |
| `KAFKA_BROKERS` | No | `localhost:9092` | Use `localhost:9092` for local dev; `kafka:9092` inside Docker |
| `CORS_ALLOWED_ORIGINS` | No | — | Include `http://localhost:5173` for Vite dev server |
| `DEMO_PASSWORD` | No | `admin123` | Fallback login password |
| `AI_CORE_URL` | No | `http://localhost:9000` | Watson AI service URL |
| `GIN_MODE` | No | `debug` | Use `release` for production |
| `LOG_LEVEL` | No | `info` | `debug`, `info`, `warn`, `error` |

### `ai-core/.env` — Local development only

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WATSONX_API_KEYS` | No | — | IBM watsonx API key. Leave blank for placeholder data. |
| `WATSONX_REGION` | No | `eu-gb` | `eu-gb` or `us-south` |
| `WATSONX_PROJECT_ID` | No | — | watsonx project ID |
| `PORT` | No | `9000` | Port the AI Core listens on |
| `LOG_LEVEL` | No | `info` | Log verbosity |

### `ui/.env` — All environments

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_API_BASE_URL` | **Yes** | `http://localhost:8080` | Full URL to the API Gateway |
| `VITE_USE_MOCK` | No | `false` | `true` = show mock data only, no API calls |
| `VITE_ENABLE_GOOGLE_AUTH` | No | `false` | `true` = show Google login button |
| `VITE_GOOGLE_CLIENT_ID` | No | — | Required when `VITE_ENABLE_GOOGLE_AUTH=true` |
| `VITE_API_VERSION` | No | `v1` | API version prefix |
| `VITE_API_TIMEOUT` | No | `30000` | Request timeout in milliseconds |
| `VITE_ALERT_POLLING_INTERVAL` | No | `30000` | How often to refresh alerts (ms) |
| `VITE_DASHBOARD_REFRESH_INTERVAL` | No | `30000` | How often to refresh dashboard (ms) |
| `VITE_MAX_ALERTS_PER_PAGE` | No | `20` | Alerts per page |
| `VITE_DEFAULT_THEME` | No | `system` | `light`, `dark`, or `system` |
| `VITE_APP_NAME` | No | `Sentrix` | App name shown in the UI |

### `datasource/.env` — Local development only

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `INGESTOR_CORE_URL` | No | `http://localhost:8001` | Where the datasource sends simulated events |
| `LOG_LEVEL` | No | `info` | Log verbosity |

---

## Database Initialisation

The database schema and seed data are fully automated.

When the `postgres` container starts for the first time, it automatically runs `infra/prod/postgres-init/init.sql`, which:
- Creates all 19 tables (alerts, tickets, users, devices, audit_logs, etc.)
- Seeds 10 runbooks
- Creates the default admin user: `admin@admin.com` / `admin123` (role: `sysadmin`)

**This only runs once** — on the first container start against a fresh volume. If you need to re-run it (e.g. after `docker compose down -v`), just recreate the containers.

On Railway/cloud deployments, GORM auto-migration handles table creation on startup. The seed user is NOT automatically created — create your first user via the sysadmin panel or use demo login.

---

## First Login and Verification

### Default credentials

| Email | Password | Role | What you can access |
|-------|----------|------|---------------------|
| `admin@admin.com` | `admin123` | `sysadmin` | Everything — all 22 features |

This is the only user created by the database seed. To test other roles, log in as admin and create additional users via **Administration → User Management** (sidebar).

### The 5 roles

| Role | Description | Notable restrictions |
|------|-------------|---------------------|
| `sysadmin` | Full access | None |
| `network-admin` | Network device management | No audit log |
| `senior-eng` | Architecture and performance focus | No user management |
| `sre` | Reliability and SLA focus | Read-only on devices |
| `network-ops` | NOC day-to-day monitoring | No config changes, no admin |

### Verification checklist

After any setup, confirm the following:

1. **API health:**
   ```bash
   curl http://localhost:8080/api/v1/health
   # Should return: {"status":"ok","database":"connected",...}
   ```

2. **UI loads:** Open http://localhost:3000 (Docker) or http://localhost:5173 (local dev)

3. **Login works:** `admin@admin.com` / `admin123`

4. **Alerts appear:** Dashboard should show alerts within 60 seconds of the datasource starting

5. **Sidebar shows all items:** If logged in as sysadmin, you should see all groups: Operations, Infrastructure, Analytics, Configuration, Administration

If alerts don't appear after 2 minutes:
```bash
docker compose logs datasource   # should show "Sending event to ingestor-core"
docker compose logs ingestor-core # should show "Event received"
```

---

## Optional Integrations

### IBM Watson AI

Without Watson credentials, all AI analysis sections display placeholder data. Every other feature works normally.

**To enable:**
1. Create a project at [cloud.ibm.com](https://cloud.ibm.com) → watsonx → Projects
2. Go to **Manage → Access (IAM) → API keys** and create an API key
3. Copy the **Project ID** from your project's Manage tab
4. Set in your `.env`:
   ```bash
   WATSONX_API_KEYS=your-api-key
   WATSONX_REGION=eu-gb        # or us-south — must match where your project lives
   WATSONX_PROJECT_ID=your-project-id
   ```
5. Rebuild the ai-core service: `docker compose up -d --build ai-core`

### Google OAuth

Without Google credentials, the "Sign in with Google" button shows a friendly error. Email/password login is unaffected.

**To enable:**
1. Go to [console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → Credentials
2. Create an **OAuth 2.0 Client ID** (application type: Web application)
3. Add authorised redirect URIs:
   - Local: `http://localhost:8080/api/v1/auth/google/callback`
   - Production: `https://your-railway-api.up.railway.app/api/v1/auth/google/callback`
4. Set in your backend `.env`:
   ```bash
   GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your-secret
   GOOGLE_REDIRECT_URL=http://localhost:8080/api/v1/auth/google/callback
   ```
5. Set in `ui/.env`:
   ```bash
   VITE_ENABLE_GOOGLE_AUTH=true
   VITE_GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
   ```

### SMTP Email

Without SMTP credentials, email features (password reset, email verification, notifications) silently skip sending. The platform operates normally.

**To enable with Gmail:**
1. Enable 2-factor authentication on your Google account
2. Create an **App Password** at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) — select Mail
3. Copy the 16-character password (ignore spaces)
4. Set in your `.env`:
   ```bash
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USERNAME=your-gmail@gmail.com
   SMTP_PASSWORD=xxxx xxxx xxxx xxxx    # the 16-char app password
   SMTP_FROM=your-gmail@gmail.com
   SMTP_FROM_NAME=Sentrix
   ```

---

## Troubleshooting

### A container keeps restarting

```bash
docker compose logs <container-name>
```

Most common causes:
- `api-gateway` or `ingestor-core` restarting → usually a wrong `POSTGRES_PASSWORD` or JWT_SECRET mismatch. Check `infra/prod/.env`.
- `kafka` restarting → Zookeeper isn't ready yet. Wait 30 seconds and try again.

### "connection refused" on port 8080

The API Gateway waits for Postgres and Kafka to be healthy before accepting connections. This can take 30–60 seconds on first start. Check with:
```bash
docker compose ps
# Wait until postgres and kafka show "healthy"
```

### Dashboard shows no alerts after 2 minutes

The datasource service sends events to ingestor-core, which forwards to the API Gateway. Check both:
```bash
docker compose logs datasource
# Should show: "Sending event to http://ingestor-core:8001"

docker compose logs ingestor-core
# Should show: "Received event" or similar
```

If datasource crashed on startup, restart it:
```bash
docker compose restart datasource
```

### 401 Unauthorized from the API

The `JWT_SECRET` must be identical in all services that handle authentication. In the Docker setup, all services read from the same `infra/prod/.env`, so this should not happen. In local development, verify `ingestor/.env` has the same `JWT_SECRET` as `infra/prod/.env`.

### Local dev: "dial tcp 127.0.0.1:9092: connect: connection refused"

Kafka is using `expose` (Docker-internal) not `ports` (host-accessible) in the default compose file. Add the port mapping as described in [Step 1 of Local Development](#step-1--start-infrastructure):
```yaml
kafka:
  ports:
    - "9092:9092"
```
Then: `docker compose up -d kafka`

### Local dev: Go build errors about missing packages

You may be hitting the Go workspace. Run with `GOWORK=off`:
```bash
cd ingestor/api_gateway
GOWORK=off go run main.go
```

Or set it in your shell session:
```bash
export GOWORK=off
```

### TypeScript compile errors in UI

```bash
cd ui && npx tsc --noEmit
```

Fix all errors before running the dev server. Most common cause is a recently modified `.tsx` file with a type mismatch.

### Full reset (Docker)

```bash
cd infra/prod

# Wipe everything — database, Kafka state, all volumes
docker compose down -v

# Rebuild from scratch
docker compose up -d --build
```

The database will be recreated from `init.sql` and the admin user re-seeded.

---

## Service Port Reference

| Service | Port | Accessible from |
|---------|------|----------------|
| Frontend (production) | 3000 | Public |
| Frontend (Vite dev) | 5173 | Public (local dev only) |
| API Gateway | 8080 | Public |
| Ingestor Core | 8001 | Docker internal only |
| Event Router | 8082 | Docker internal only |
| AI Core | 9000 | Docker internal only |
| PostgreSQL | 5432 | Docker internal only |
| PgAdmin | 5050 | `127.0.0.1` only |
| Kafka | 9092 | Docker internal only (add `ports` for local dev) |
| Zookeeper | 2181 | Docker internal only |
| Kafka UI | 8090 | `127.0.0.1` only |

---

## Project Structure Reference

```
ibm-live-project-intern/
├── infra/prod/               ← Docker Compose lives here; run all docker commands from here
│   ├── docker-compose.yml
│   ├── docker-compose.arm.yml
│   ├── .env.example          ← Copy to .env and fill in secrets
│   └── postgres-init/
│       └── init.sql          ← Auto-runs on first Postgres start; creates tables + seeds admin user
│
├── ingestor/
│   ├── api_gateway/          ← Primary REST API (port 8080)
│   ├── event_router/         ← Routes events to Kafka (port 8082)
│   ├── ingestor_core/        ← Receives raw events (port 8001)
│   ├── shared/               ← Models, middleware, RBAC, DB repos
│   └── .env.example          ← Copy to .env for local dev
│
├── ai-core/                  ← IBM Watson AI analysis service (port 9000)
│   └── .env.example          ← Copy to .env for local dev
│
├── datasource/               ← Simulates SNMP/syslog events from network devices
│   └── .env.example
│
├── ui/                       ← React 19 + TypeScript + IBM Carbon
│   ├── .env.example          ← Copy to .env for local dev
│   ├── .env.production       ← Create this for production (do not commit)
│   └── vercel.json           ← SPA routing config for Vercel — already committed
│
├── go.work                   ← Go workspace linking all 6 modules
│                                Use GOWORK=off when running services individually
│
└── railway.json              ← Railway build/deploy config for API Gateway
```
