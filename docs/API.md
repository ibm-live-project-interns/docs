# API Reference

Complete REST API documentation for the Sentrix API Gateway.

## Base URL

| Environment | URL | Notes |
|-------------|-----|-------|
| Docker/Prod | `http://localhost:3000/api/v1` | Via nginx proxy |
| Direct API | `http://localhost:8080/api/v1` | Direct to API Gateway |

## Authentication

JWT token in the Authorization header:
```
Authorization: Bearer <token>
```

Token expiry: 24 hours (configurable via `JWT_EXPIRY_HOURS`).

---

## Public Endpoints (No Auth)

### Login

```http
POST /api/v1/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "<any-non-empty>"
}
```

**Demo mode** (no DB): Any non-empty email/password is accepted. The role is determined by the email pattern — e.g. emails containing `admin` map to `sysadmin`. The actual demo password used by the backend is set via the `DEMO_PASSWORD` environment variable (there is no hardcoded default credential). Email pattern -> role mapping:
- `*ops*` or `*noc*` -> network-ops
- `*sre*` -> sre
- `*network*` -> network-admin
- `*senior*` or `*eng*` -> senior-eng
- `*admin*` / default -> sysadmin

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_at": "2026-02-15T10:30:00Z",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "username": "admin",
    "first_name": "Demo",
    "last_name": "Admin",
    "role": "sysadmin",
    "is_active": true,
    "email_verified": true
  },
  "permissions": ["view-alerts", "acknowledge-alerts", "create-tickets", ...]
}
```

### Register

```http
POST /api/v1/register
Content-Type: application/json

{
  "email": "john@example.com",
  "username": "johndoe",
  "password": "securepassword",
  "first_name": "John",
  "last_name": "Doe"
}
```

Default role: `network-ops`. Account requires email verification before login.

### Health Check

```http
GET /api/v1/health
```

### Google OAuth

```http
GET /api/v1/auth/google/login?redirect=/dashboard
GET /api/v1/auth/google/callback
```

Redirects to Google, then back to `/login?token=<jwt>`. Requires `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` env vars.

### Email Verification & Password Reset

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/verify-email` | Verify email with token (body: `{"token": "..."}`) |
| POST | `/api/v1/auth/forgot-password` | Request password reset (body: `{"email": "..."}`) |
| POST | `/api/v1/auth/reset-password` | Reset password (body: `{"token": "...", "new_password": "..."}`) |
| POST | `/api/v1/auth/resend-verification` | Resend verification email (body: `{"email": "..."}`) |

Verification tokens expire after 24 hours. Reset tokens expire after 1 hour.

---

## Protected Endpoints (JWT Required)

All endpoints below require `Authorization: Bearer <token>`.

---

### Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/logout` | Invalidate session |
| GET | `/api/v1/me` | Get current authenticated user + permissions |
| GET | `/api/v1/auth/me` | Alias for `/me` |

---

### Alerts

| Method | Endpoint | RBAC | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/alerts` | Any auth | List alerts (supports `from`, `to` RFC3339, `severity`, `status` params) |
| GET | `/api/v1/alerts/:id` | Any auth | Get alert by ID (includes AI analysis, device info, history) |
| GET | `/api/v1/alerts/summary` | Any auth | Dashboard summary stats |
| GET | `/api/v1/alerts/severity-distribution` | Any auth | Severity breakdown for charts |
| GET | `/api/v1/alerts/over-time` | Any auth | Time series data (`?period=24h\|7d\|30d\|90d`) |
| GET | `/api/v1/alerts/recurring` | Any auth | Most frequent alert types |
| GET | `/api/v1/alerts/distribution/time` | Any auth | Alerts by time of day |
| POST | `/api/v1/alerts/:id/acknowledge` | `acknowledge-alerts` | Acknowledge alert |
| POST | `/api/v1/alerts/:id/dismiss` | `acknowledge-alerts` | Dismiss alert |
| POST | `/api/v1/alerts/:id/resolve` | `acknowledge-alerts` | Resolve alert |
| POST | `/api/v1/alerts/:id/reanalyze` | `acknowledge-alerts` | Trigger AI re-analysis |
| POST | `/api/v1/alerts/bulk-action` | `acknowledge-alerts` | Perform bulk action on multiple alerts (acknowledge/dismiss/resolve) |
| GET | `/api/v1/alerts/:id/tickets` | Any auth | List tickets linked to this alert |
| GET | `/api/v1/alerts/:id/post-mortem` | Any auth | Get post-mortem for an alert |
| POST | `/api/v1/alerts/:id/post-mortem` | `acknowledge-alerts` | Create post-mortem for an alert |
| GET | `/api/v1/alert-history` | Any auth | Resolved alerts history log |

---

### Tickets

| Method | Endpoint | RBAC | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/tickets` | Any auth | List all tickets |
| GET | `/api/v1/tickets/stats` | Any auth | Ticket statistics (includes real avg_resolution_hours) |
| GET | `/api/v1/tickets/export` | Any auth | Export tickets as CSV |
| GET | `/api/v1/tickets/:id` | Any auth | Get ticket by ID |
| GET | `/api/v1/tickets/:id/comments` | Any auth | Get ticket comments |
| POST | `/api/v1/tickets` | `create-tickets` | Create ticket |
| PUT | `/api/v1/tickets/:id` | `create-tickets` | Update ticket |
| PATCH | `/api/v1/tickets/:id` | `create-tickets` | Update ticket (alias) |
| DELETE | `/api/v1/tickets/:id` | `create-tickets` | Delete ticket |
| POST | `/api/v1/tickets/:id/comments` | `create-tickets` | Add comment to ticket |

---

### Devices

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/devices` | List all devices |
| GET | `/api/v1/devices/:id` | Get device by ID |
| GET | `/api/v1/devices/:id/metrics` | Device performance metrics (`?period=24h\|7d\|30d`) |
| GET | `/api/v1/devices/noisy` | Top devices by alert count |

---

### Device Groups

| Method | Endpoint | RBAC | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/device-groups` | Any auth | List device groups |
| GET | `/api/v1/device-groups/:id` | Any auth | Get device group by ID |
| POST | `/api/v1/device-groups` | network-admin, senior-eng, sysadmin | Create device group |
| PUT | `/api/v1/device-groups/:id` | network-admin, senior-eng, sysadmin | Update device group |
| DELETE | `/api/v1/device-groups/:id` | network-admin, senior-eng, sysadmin | Delete device group |
| POST | `/api/v1/device-groups/:id/devices` | network-admin, senior-eng, sysadmin | Add devices to group |
| DELETE | `/api/v1/device-groups/:id/devices/:deviceId` | network-admin, senior-eng, sysadmin | Remove device from group |

---

### AI & Trends

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/ai/metrics` | AI performance statistics |
| GET | `/api/v1/ai/insights` | AI-generated recommendations |
| GET | `/api/v1/ai/impact-over-time` | AI impact trend data |
| GET | `/api/v1/trends/kpi` | Trends page KPIs (peak hours, avg resolution time) |

---

### Reports

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/reports/export` | Generate report (`?format=csv\|json`) |
| GET | `/api/v1/reports/sla` | SLA compliance overview |
| GET | `/api/v1/reports/sla/violations` | SLA violations list |
| GET | `/api/v1/reports/sla/trend` | SLA trend over time |

---

### Configuration (Requires sysadmin or senior-eng role)

#### Threshold Rules

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/configuration/rules` | List all rules |
| POST | `/api/v1/configuration/rules` | Create rule |
| GET | `/api/v1/configuration/rules/:id` | Get rule by ID |
| PUT | `/api/v1/configuration/rules/:id` | Update rule |
| DELETE | `/api/v1/configuration/rules/:id` | Delete rule |

#### Notification Channels

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/configuration/channels` | List all channels |
| POST | `/api/v1/configuration/channels` | Create channel |
| GET | `/api/v1/configuration/channels/:id` | Get channel by ID |
| PUT | `/api/v1/configuration/channels/:id` | Update channel |
| DELETE | `/api/v1/configuration/channels/:id` | Delete channel |

#### Escalation Policies

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/configuration/policies` | List all policies |
| POST | `/api/v1/configuration/policies` | Create policy |
| GET | `/api/v1/configuration/policies/:id` | Get policy by ID |
| PUT | `/api/v1/configuration/policies/:id` | Update policy |
| DELETE | `/api/v1/configuration/policies/:id` | Delete policy |

#### Maintenance Windows

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/configuration/maintenance` | List all windows |
| POST | `/api/v1/configuration/maintenance` | Create window |
| GET | `/api/v1/configuration/maintenance/:id` | Get window by ID |
| PUT | `/api/v1/configuration/maintenance/:id` | Update window |
| DELETE | `/api/v1/configuration/maintenance/:id` | Delete window |

#### Global Settings

| Method | Endpoint | RBAC | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/configuration/global-settings` | Any auth | Get global settings |
| PUT | `/api/v1/configuration/global-settings` | sysadmin | Update global settings |

---

### Runbooks

| Method | Endpoint | RBAC | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/runbooks` | Any auth | List runbooks (`?search=`, `?category=`) |
| GET | `/api/v1/runbooks/suggest` | Any auth | Suggest runbooks relevant to an alert/context |
| GET | `/api/v1/runbooks/:id` | Any auth | Get runbook by ID |
| POST | `/api/v1/runbooks` | sysadmin, senior-eng | Create runbook |
| PUT | `/api/v1/runbooks/:id` | sysadmin, senior-eng | Update runbook |
| DELETE | `/api/v1/runbooks/:id` | sysadmin, senior-eng | Delete runbook |

---

### User Management (sysadmin only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/users` | List all users |
| GET | `/api/v1/users/:id` | Get user by ID |
| PUT | `/api/v1/users/:id` | Update user (role, status) |
| DELETE | `/api/v1/users/:id` | Soft-delete user |
| POST | `/api/v1/users/:id/reset-password` | Reset user password |

---

### Profile (Self-service)

| Method | Endpoint | Description |
|--------|----------|-------------|
| PUT | `/api/v1/me` | Update own profile (first_name, last_name, email) |
| PUT | `/api/v1/me/password` | Change own password |

---

### Audit Logs (sysadmin only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/audit-logs` | List audit logs (paginated, filterable by action, resource, user) |
| GET | `/api/v1/audit-logs/actions` | Get distinct action types for filter dropdown |

---

### On-Call Schedule

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/on-call/current` | Get current on-call engineer |
| GET | `/api/v1/on-call/schedule` | Get weekly schedule |
| GET | `/api/v1/on-call/schedules` | List all on-call schedules |
| POST | `/api/v1/on-call/schedules` | Create an on-call schedule |
| PUT | `/api/v1/on-call/schedules/:id` | Update an on-call schedule |
| DELETE | `/api/v1/on-call/schedules/:id` | Delete an on-call schedule |
| POST | `/api/v1/on-call/overrides` | Create a schedule override |
| DELETE | `/api/v1/on-call/overrides/:id` | Delete a schedule override |

---

### Network Topology

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/topology` | Get topology nodes and edges |

---

### Post-Mortems

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/post-mortems` | List all post-mortems |
| PUT | `/api/v1/post-mortems/:id` | Update a post-mortem |

See also the alert-scoped post-mortem endpoints under the Alerts section (`/api/v1/alerts/:id/post-mortem`).

---

### System

| Method | Endpoint | RBAC | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/system/health` | sysadmin | Detailed system health (deep checks of DB, Kafka, services) |

---

### Service Status

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/service-status` | Application-level health checks (7 services) |
| GET | `/api/v1/services/status` | Docker container status via `docker ps` |
| GET | `/api/v1/services/:name/logs` | Docker container logs (`?lines=100`, max 5000) |

---

### User Settings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/settings/notifications` | Get notification preferences |
| PUT | `/api/v1/settings/notifications` | Update notification preferences |
| GET | `/api/v1/settings/ui` | Get UI preferences (theme, density, etc.) |
| PUT | `/api/v1/settings/ui` | Update UI preferences |

---

### Event Ingestion

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/events` | Ingest event (also available internally) |

---

### Test Utilities (sysadmin only)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/test/send-all-emails` | Send all email templates to test address |
| GET | `/api/v1/test/send-all-emails` | Same (GET alias) |

---

## Error Responses

All errors return JSON with an `error` field:

| Status | Meaning | Example |
|--------|---------|---------|
| 400 | Bad request / validation error | `{"error": "Invalid email format"}` |
| 401 | Not authenticated | `{"error": "Authorization header required"}` |
| 403 | Insufficient permissions | `{"error": "Insufficient permissions"}` |
| 404 | Resource not found | `{"error": "Alert not found"}` |
| 409 | Duplicate entry | `{"error": "Email already registered"}` |
| 429 | Rate limit exceeded | `{"error": "Rate limit exceeded"}` |
| 500 | Internal server error | `{"error": "Internal server error"}` |
| 503 | Database unavailable | `{"error": "Database not available"}` |

---

## Rate Limiting

When enabled (`RATE_LIMIT_ENABLED=true`):
- Default: 100 requests per minute per IP
- Configurable via `RATE_LIMIT_REQUESTS_PER_MINUTE`

Response headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705234567
```

---

## RBAC Roles & Permissions

| Role | Key Permissions |
|------|----------------|
| `network-ops` | view-alerts, acknowledge-alerts, create-tickets |
| `sre` | view-alerts, acknowledge-alerts, create-tickets, view-analytics |
| `network-admin` | view-alerts, acknowledge-alerts, create-tickets, manage-devices |
| `senior-eng` | All except user management and audit logs |
| `sysadmin` | Full access (all permissions) |
