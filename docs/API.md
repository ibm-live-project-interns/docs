# API Reference

Complete REST API documentation for the NOC Dashboard API Gateway.

## Base URL

The API can be accessed through different URLs depending on your setup:

### Production/Docker Deployment (Recommended)
```
http://localhost:3000/api/v1
```
Use this when accessing through the UI/nginx proxy (Docker Compose deployment). The nginx server proxies API requests from port 3000 to the backend.

### Direct API Access (Development/Testing)
```
http://localhost:8080/api/v1
```
Use this to access the API Gateway directly without the proxy. Useful for backend development or API testing tools like Postman/curl.

**Note:** When using the web UI at `http://localhost:3000`, always use the proxy URL (port 3000) for API calls.

## Authentication

The API uses JWT (JSON Web Token) authentication. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Token Expiry
- Default: 24 hours
- Configurable via `JWT_EXPIRY_HOURS` environment variable

---

## Public Endpoints

These endpoints do not require authentication.

### Login

Authenticate a user and receive a JWT token.

**Demo Mode:** The API currently accepts any non-empty username and password for demonstration purposes. In production, this should be replaced with proper authentication against a user database with hashed passwords.

**Quick Test Credentials:**
- Username: `admin` (or any non-empty string)
- Password: `admin123` (or any non-empty string)

```http
POST /api/v1/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123",
  "role": {
    "id": "admin",
    "text": "Administrator"
  }
}
```

**Available Roles:**
- `{"id": "admin", "text": "Administrator"}` - Full access
- `{"id": "operator", "text": "Operator"}` - Standard access
- `{"id": "viewer", "text": "Viewer"}` - Read-only access

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "username": "admin",
    "role": {
      "id": "admin",
      "text": "Administrator"
    }
  }
}
```

### Register

Create a new user account.

```http
POST /api/v1/register
Content-Type: application/json

{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@example.com",
  "password": "securepassword",
  "role": {
    "id": "operator",
    "text": "Operator"
  }
}
```

**Response:**
```json
{
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Health Check

Check API Gateway health status.

```http
GET /api/v1/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-14T10:30:00Z",
  "version": "1.0.0"
}
```

---

## Internal Endpoints

These endpoints are for service-to-service communication and do not require authentication.

### Ingest Event (Internal)

Receive events from Event Router for processing and storage.

```http
POST /api/internal/events
Content-Type: application/json
```

**Request Body:**
```json
{
  "type": "SNMP_TRAP",
  "message": "Interface GigabitEthernet0/1 is down",
  "severity": "critical",
  "source_host": "Core-Router-01",
  "source_ip": "10.0.0.1",
  "event_type": "INTERFACE_DOWN",
  "category": "network"
}
```

**Response:**
```json
{
  "message": "Event received and queued for processing"
}
```

**Usage:** This endpoint is called by the Event Router service to forward events to the API Gateway without requiring JWT authentication.

---

## Protected Endpoints

All endpoints below require a valid JWT token.

---

## Alerts

### List All Alerts

```http
GET /api/v1/alerts
Authorization: Bearer <token>
```

**Response:**
```json
[
  {
    "id": "alert-001",
    "severity": "critical",
    "status": "new",
    "timestamp": {
      "absolute": "2026-01-14 10:30:00",
      "relative": "2m ago"
    },
    "device": {
      "name": "Core-SW-01",
      "ip": "192.168.1.10",
      "icon": "switch",
      "model": "Cisco Catalyst 9300",
      "vendor": "Cisco Systems"
    },
    "aiTitle": "Interface GigabitEthernet0/1 Down",
    "aiSummary": "Network interface has transitioned to down state.",
    "confidence": 94
  }
]
```

### Get Alert by ID

```http
GET /api/v1/alerts/:id
Authorization: Bearer <token>
```

**Response:**
```json
{
  "id": "alert-001",
  "severity": "critical",
  "status": "new",
  "timestamp": { "absolute": "2026-01-14 10:30:00", "relative": "2m ago" },
  "device": { "name": "Core-SW-01", "ip": "192.168.1.10", "icon": "switch" },
  "aiTitle": "Interface GigabitEthernet0/1 Down",
  "aiSummary": "Network interface has transitioned to down state.",
  "confidence": 94,
  "similarEvents": 7,
  "aiAnalysis": {
    "summary": "The network interface has transitioned to a down state...",
    "rootCauses": [
      "Physical layer failure detected",
      "Possible cable fault or SFP failure",
      "Remote device may be powered off"
    ],
    "businessImpact": "High - Loss of redundancy to distribution layer.",
    "recommendedActions": [
      "Verify physical cable connection",
      "Check remote device status",
      "Review interface error counters"
    ]
  },
  "rawData": "SNMP-v2-MIB::sysUpTime.0 = Timeticks: (123456789)...",
  "history": [
    {
      "id": "hist-001",
      "timestamp": "2024-03-13 09:13:33",
      "title": "Interface Down",
      "resolution": "Cable reseated",
      "severity": "critical"
    }
  ],
  "extendedDevice": {
    "name": "Core-SW-01",
    "ip": "192.168.1.10",
    "location": "Data Center 1, Rack A12",
    "vendor": "Cisco Systems",
    "model": "Cisco Catalyst 9300",
    "interface": "GigabitEthernet0/1",
    "interfaceAlias": "Uplink to Distribution"
  }
}
```

### Get Alerts Summary

Dashboard summary statistics.

```http
GET /api/v1/alerts/summary
Authorization: Bearer <token>
```

**Response:**
```json
{
  "activeCount": 15,
  "criticalCount": 3,
  "majorCount": 5,
  "minorCount": 4,
  "infoCount": 3
}
```

### Get Severity Distribution

Chart data for severity breakdown.

```http
GET /api/v1/alerts/severity-distribution
Authorization: Bearer <token>
```

**Response:**
```json
[
  { "group": "Critical", "value": 3 },
  { "group": "Major", "value": 5 },
  { "group": "Minor", "value": 4 },
  { "group": "Info", "value": 3 }
]
```

### Get Alerts Over Time

Time-series data for alert trends.

```http
GET /api/v1/alerts/over-time
Authorization: Bearer <token>
```

**Query Parameters:**
- `period` - Time period: `24h`, `7d`, `30d`, `90d`

**Response:**
```json
[
  { "group": "Critical", "date": "2026-01-14T00:00:00Z", "value": 5 },
  { "group": "Critical", "date": "2026-01-14T04:00:00Z", "value": 8 },
  { "group": "Major", "date": "2026-01-14T00:00:00Z", "value": 10 }
]
```

### Get Recurring Alerts

Most frequent alert types.

```http
GET /api/v1/alerts/recurring
Authorization: Bearer <token>
```

**Response:**
```json
[
  {
    "id": "rec-1",
    "name": "Interface Down",
    "count": 15,
    "severity": "critical",
    "avgResolution": "5m",
    "percentage": 25
  }
]
```

### Get Alert Distribution by Time

Alerts grouped by time of day.

```http
GET /api/v1/alerts/distribution/time
Authorization: Bearer <token>
```

**Response:**
```json
[
  { "group": "Morning", "value": 25 },
  { "group": "Afternoon", "value": 35 },
  { "group": "Evening", "value": 20 },
  { "group": "Night", "value": 10 }
]
```

### Acknowledge Alert

Mark an alert as acknowledged.

```http
POST /api/v1/alerts/:id/acknowledge
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "Alert acknowledged",
  "status": "acknowledged"
}
```

### Dismiss Alert

Dismiss an alert.

```http
POST /api/v1/alerts/:id/dismiss
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "Alert dismissed",
  "status": "dismissed"
}
```

---

## Tickets

### List All Tickets

```http
GET /api/v1/tickets
Authorization: Bearer <token>
```

**Response:**
```json
[
  {
    "id": "ticket-001",
    "ticketNumber": "TKT-20260114-001",
    "alertId": "alert-001",
    "title": "Interface Down on Core-SW-01",
    "description": "GigabitEthernet0/1 interface is down.",
    "priority": "critical",
    "status": "open",
    "deviceName": "Core-SW-01",
    "assignedTo": "Network Team",
    "createdAt": "2026-01-14 10:30:00",
    "updatedAt": "2026-01-14 10:30:00",
    "createdBy": "admin"
  }
]
```

### Get Ticket by ID

```http
GET /api/v1/tickets/:id
Authorization: Bearer <token>
```

### Create Ticket

```http
POST /api/v1/tickets
Authorization: Bearer <token>
Content-Type: application/json

{
  "alertId": "alert-001",
  "title": "Interface Down on Core-SW-01",
  "description": "Needs immediate investigation",
  "priority": "critical",
  "deviceName": "Core-SW-01",
  "assignee": "Network Team"
}
```

**Response:**
```json
{
  "id": "ticket-003",
  "ticketNumber": "TKT-20260114-003",
  "alertId": "alert-001",
  "title": "Interface Down on Core-SW-01",
  "description": "Needs immediate investigation",
  "priority": "critical",
  "status": "open",
  "deviceName": "Core-SW-01",
  "assignedTo": "Network Team",
  "createdAt": "2026-01-14 11:00:00",
  "updatedAt": "2026-01-14 11:00:00",
  "createdBy": "admin"
}
```

### Update Ticket

```http
PUT /api/v1/tickets/:id
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "in-progress",
  "assignedTo": "John Doe"
}
```

---

## Devices

### Get Noisy Devices

Devices generating the most alerts.

```http
GET /api/v1/devices/noisy
Authorization: Bearer <token>
```

**Response:**
```json
[
  {
    "device": {
      "name": "Core-SW-01",
      "ip": "192.168.1.10",
      "icon": "switch"
    },
    "model": "Cisco Catalyst 9300",
    "alertCount": 15,
    "severity": "critical"
  }
]
```

---

## AI & Trends

### Get AI Metrics

AI performance statistics.

```http
GET /api/v1/ai/metrics
Authorization: Bearer <token>
```

**Response:**
```json
[
  { "name": "Resolution Time", "value": 50, "change": "-50%", "trend": "positive" },
  { "name": "Escalations", "value": 47, "change": "-47%", "trend": "positive" },
  { "name": "Accuracy", "value": 94.8, "change": "94.8%", "trend": "positive" }
]
```

### Get AI Insights

AI-generated recommendations.

```http
GET /api/v1/ai/insights
Authorization: Bearer <token>
```

**Response:**
```json
[
  {
    "id": "ins-1",
    "type": "pattern",
    "description": "Recurring interface flapping detected on Core-SW-01.",
    "action": "Investigate Scheduled Tasks"
  },
  {
    "id": "ins-2",
    "type": "optimization",
    "description": "Firewall rules processing efficiency dropping.",
    "action": "Optimize Rule Base"
  }
]
```

### Get AI Impact Over Time

```http
GET /api/v1/ai/impact-over-time
Authorization: Bearer <token>
```

### Get Trends KPI

Key performance indicators for trends page.

```http
GET /api/v1/trends/kpi
Authorization: Bearer <token>
```

**Response:**
```json
[
  { "id": "alert-volume", "label": "Alert Volume", "value": "156", "trend": "down" },
  { "id": "mttr", "label": "MTTR", "value": "5m", "trend": "up" },
  { "id": "recurring-alerts", "label": "Recurring Alerts", "value": "15%", "trend": "stable" },
  { "id": "escalation-rate", "label": "Escalation Rate", "value": "0%", "trend": "stable", "tag": { "text": "Low", "type": "green" } }
]
```

---

## Reports

### Export Report

Generate and download a report.

```http
GET /api/v1/reports/export?format=csv
Authorization: Bearer <token>
```

**Query Parameters:**
- `format` - Export format: `csv`, `pdf`, `json`

**Response:**
```json
{
  "url": "/reports/download/csv",
  "message": "Report generated"
}
```

---

## Error Responses

### 400 Bad Request
```json
{
  "error": "Invalid request payload"
}
```

### 401 Unauthorized
```json
{
  "error": "Authorization header required"
}
```

### 404 Not Found
```json
{
  "error": "Alert not found"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error"
}
```

---

## Rate Limiting

When enabled (`RATE_LIMIT_ENABLED=true`):
- Default: 100 requests per minute per IP
- Configurable via `RATE_LIMIT_REQUESTS_PER_MINUTE`

Rate limit headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705234567
```
