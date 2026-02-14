# Exhaustive Codebase Audit — NOC Dashboard

**Date:** 2026-02-13
**Scope:** Every file in the backend (Go), frontend (React/TS), shared models, database schema
**Status:** PLAN ONLY — No code changes executed

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [CRITICAL Issues (Must Fix)](#2-critical-issues)
3. [HIGH Issues (Should Fix)](#3-high-issues)
4. [MEDIUM Issues (Recommended)](#4-medium-issues)
5. [LOW Issues (Nice to Have)](#5-low-issues)
6. [Systemic / Cross-Cutting Issues](#6-systemic-issues)
7. [Full Issue Index](#7-full-issue-index)

---

## 1. Executive Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 18 |
| HIGH     | 38 |
| MEDIUM   | 52 |
| LOW      | 60+ |
| **Total** | **168+** |

### Top 10 Most Dangerous Issues

1. **RBAC middleware defined but NEVER applied** — every authenticated user can access every endpoint
2. **Auth endpoint paths wrong** — 6 endpoints (verify-email, forgot-password, reset-password, resend-verification, Google OAuth) will 404
3. **Frontend role always defaults to `network-ops`** — backend returns flat string, frontend expects `{id: "..."}` object
4. **Frontend permissions hardcoded** — all users get same 4 permissions regardless of role
5. **`users.go` nil pointer crash** — line 343 discards error then calls method on nil
6. **Demo mode accepts ANY credentials** — when DB is down, any email/password works
7. **Ticket tags never persist** — `gorm:"-" json:"-"` on Tags field, no `tags` column in DB
8. **Device model has no GORM backing** — Device struct in handlers/common.go has no GORM tags, column `icon` vs field `Type` mismatch
9. **Alert severity/status mismatch** — Go rejects `major`/`minor`/`new`/`in-progress` that exist in DB seed data
10. **No logout server invalidation** — `authService.logout()` only clears localStorage, JWT remains valid

---

## 2. CRITICAL Issues

### C-01: RBAC Permissions Defined But Never Enforced
- **Files:** `shared/middleware/auth.go`, `shared/rbac/permissions.go`, `api_gateway/main.go`
- **Detail:** `RequirePermission()`, `RequireAnyPermission()`, `RequireRole()` middleware functions exist (middleware/auth.go:14-117) but are NEVER applied to any route in main.go. All 13 permissions and 5 role mappings are dead code. Every authenticated user can hit every endpoint.
- **Impact:** Any logged-in user (even `network-ops`) can access admin-only endpoints like user management, audit logs, configuration changes.

### C-02: Auth Endpoint Path Mismatch (6 Endpoints Will 404)
- **Files:** `ui/src/shared/config/api.config.ts:66-76`, `api_gateway/main.go:120-134`
- **Detail:** Frontend defines paths without `/auth/` prefix:
  - `VERIFY_EMAIL: '/verify-email'` → backend expects `/auth/verify-email`
  - `FORGOT_PASSWORD: '/forgot-password'` → backend expects `/auth/forgot-password`
  - `RESET_PASSWORD: '/reset-password'` → backend expects `/auth/reset-password`
  - `RESEND_VERIFICATION: '/resend-verification'` → backend expects `/auth/resend-verification`
  - `GOOGLE_LOGIN: '/google/login'` → backend expects `/auth/google/login`
  - `GOOGLE_CALLBACK: '/google/callback'` → backend expects `/auth/google/callback`
- **Impact:** Email verification, password reset, and Google OAuth are completely broken.

### C-03: Frontend Role Always Defaults to `network-ops`
- **File:** `ui/src/features/auth/services/authService.ts:123`
- **Detail:** `role: response.user?.role?.id || 'network-ops'` — backend returns role as flat string `"sysadmin"`, not object `{id: "sysadmin"}`. `?.id` on a string returns `undefined`, so every user gets `network-ops`.
- **Impact:** All frontend role-based UI hiding is broken. Sysadmins see network-ops view.

### C-04: Frontend Permissions Hardcoded for All Roles
- **File:** `ui/src/features/auth/services/authService.ts:132-133`
- **Detail:** `permissions: ['view-alerts', 'acknowledge-alerts', 'create-tickets', 'view-tickets']` — same 4 permissions for every user regardless of actual role.
- **Impact:** Frontend RBAC checks (e.g., `hasPermission('view-devices')`) fail for all roles except coincidentally matching ones.

### C-05: Nil Pointer Crash in users.go
- **File:** `handlers/users.go:343`
- **Detail:** `repo.GetByID` error is discarded with `_`, then `.ToResponse()` is called on the nil user pointer.
- **Impact:** Server panic (500) when fetching a non-existent user by ID.

### C-06: Demo Mode Accepts Any Credentials
- **File:** `handlers/auth.go:142-189`
- **Detail:** When DB is unavailable, login falls back to demo mode. It maps email patterns to roles (e.g., `admin@` → sysadmin) but accepts ANY password.
- **Impact:** In production, a temporary DB outage turns the app into an open door.

### C-07: Ticket Tags Never Persist
- **Files:** `shared/models/ticket.go:36`, `infra/prod/postgres-init/init.sql`
- **Detail:** Tags field has `gorm:"-" json:"-"` (ignored by both GORM and JSON). The `tickets` table has no `tags` column. `SetTags()` in ticket_repo.go writes to a non-existent column.
- **Impact:** Tags feature is completely non-functional. Runtime SQL errors on SetTags.

### C-08: Device Model Has No Proper GORM Backing
- **Files:** `handlers/common.go` Device struct, `init.sql` devices table
- **Detail:**
  - Device struct is a plain Go struct in handlers (not shared/models), with no GORM tags
  - SQL column `icon` maps to Go field `Type` — GORM would look for column `type` which doesn't exist
  - SQL seeds status `active` but TS type expects `online/offline/warning/critical`
  - Go JSON tags use camelCase (`alertCount`), TS expects snake_case (`recent_alerts`)
- **Impact:** Device queries via GORM are broken. Frontend receives wrong field names.

### C-09: Alert AIConfidence GORM Column Mismatch
- **File:** `shared/models/alert.go:43`
- **Detail:** `AIConfidence float64` has no `gorm:"column:ai_confidence"` tag. GORM defaults to `a_i_confidence` (snake_case of Go field). DB column is `ai_confidence`.
- **Impact:** AI confidence scores are never read from or written to the database correctly.

### C-10: Alert Severity Mismatch Across Layers
- **Files:** `shared/constants/severity.go`, `init.sql`, `shared/models/alert.go`
- **Detail:**
  - SQL CHECK allows 7 values: `critical, high, major, medium, minor, low, info`
  - Go constants allow 5 values: `critical, high, medium, low, info` (missing `major`, `minor`)
  - Seed data uses `major` (alert-002, alert-006)
  - Go `IsValidSeverity()` would reject valid DB records
- **Impact:** Alerts with `major`/`minor` severity can exist in DB but fail Go validation.

### C-11: Alert Status Mismatch Across Layers
- **Files:** `shared/constants/`, `init.sql`, `shared/models/alert.go`
- **Detail:**
  - SQL CHECK allows 6 values: `new, open, acknowledged, in-progress, resolved, dismissed`
  - Go constants allow 4 values: `open, acknowledged, resolved, dismissed` (missing `new`, `in-progress`)
  - Seed data uses `new` and `in-progress`
- **Impact:** Alerts with status `new` or `in-progress` exist in DB but aren't recognized by Go/TS.

### C-12: OAuth State Never Validated (CSRF Broken)
- **File:** `handlers/auth.go:577, 607-614`
- **Detail:** The `state` parameter is generated (line 577) but NEVER validated on callback (lines 607-614). Anyone can forge an OAuth callback.
- **Impact:** CSRF vulnerability in OAuth flow. Attacker can force-associate their Google account with a victim's session.

### C-13: `strings.Split` Panic on Single-Word Names
- **File:** `handlers/auth.go:168`
- **Detail:** `strings.Split(demoName, " ")[1]` panics with index out of range if user enters a single-word name in demo mode.
- **Impact:** Server crash on demo login with single-word display name.

### C-14: OAuth Bypasses Account Deactivation
- **File:** `handlers/auth.go:696`
- **Detail:** Google OAuth login does not check `user.IsActive` before issuing JWT.
- **Impact:** Deactivated users can still log in via Google OAuth.

### C-15: ProtectedRoute Auth Bypass via `tokenProcessed` Flag
- **File:** `ui/src/pages/auth/ProtectedRoute.tsx:75`
- **Detail:** `const isAuthenticated = authService.isAuthenticated() || tokenProcessed`. Once `tokenProcessed` is set true (after OAuth), it never resets. If token later expires or is invalidated, the route still renders protected content.
- **Impact:** Persistent client-side auth bypass after first OAuth login.

### C-16: No AuthContext — No Reactive Auth State
- **Detail:** No `AuthContext.tsx` exists. Auth is managed imperatively via `authService` singleton + localStorage. Components cannot reactively respond to auth state changes. Token expiry is never checked.
- **Impact:** Users continue seeing stale UI after token expires until a 401 forces redirect.

### C-17: OAuth Login Never Loads User Profile
- **File:** `ui/src/features/auth/services/authService.ts:267-269`
- **Detail:** `setOAuthToken` only calls `HttpService.setToken(token)`. Does not call `getCurrentUser()` or `saveUser()`. After OAuth login, `currentUser` is null.
- **Impact:** After OAuth login, username shows "User", role shows "Viewer", initials show "??".

### C-18: Internal API Key Middleware Allows All When Not Configured
- **File:** `api_gateway/main.go:309-315`
- **Detail:** When `INTERNAL_API_KEY` env var is not set, the middleware allows ALL requests through.
- **Impact:** Internal-only endpoints are publicly accessible if env var is missing.

---

## 3. HIGH Issues

### H-01: `PriorityAlertsPage` Uses Wrong Token Key
- **File:** `ui/src/pages/alerts/PriorityAlertsPage.tsx:166`
- **Detail:** `localStorage.getItem('auth_token')` — should be `'noc_token'`. CSV export will fail (401).

### H-02: `TicketsPage` Uses Wrong Token Key
- **File:** `ui/src/pages/tickets/TicketsPage.tsx:91`
- **Detail:** Same `auth_token` vs `noc_token` issue. CSV export broken.

### H-03: Logout Doesn't Invalidate Server Session
- **File:** `ui/src/features/auth/services/authService.ts:250-255`
- **Detail:** `logout()` clears localStorage but never calls `POST /logout`. JWT remains valid until natural expiry.

### H-04: No Token Refresh Mechanism
- **Detail:** No refresh token storage, no proactive expiry check, no token renewal. Users are abruptly redirected to login when token expires.

### H-05: DeviceService Silently Falls Back to Mock Data on ALL Errors
- **File:** `ui/src/features/devices/services/deviceService.ts:290-298`
- **Detail:** A 500 error, auth failure, or malformed JSON ALL silently return mock data. User sees fake devices in a monitoring tool.

### H-06: AlertService Has No Mock Fallback
- **File:** `ui/src/features/alerts/services/alertService.ts`
- **Detail:** Unlike ticketService and deviceService, alertService has no mock implementation. If API is down, every call throws.

### H-07: `alertService.transformAlert` Uses `any` for Both Param and Return
- **File:** `alertService.ts:90`
- **Detail:** `private transformAlert(backendAlert: any): any` — the core transformation is completely untyped.

### H-08: `similarEvents` Falls Back to Math.random()
- **File:** `alertService.ts:219`
- **Detail:** If backend doesn't return `similar_count`, a random number 1-15 is injected. Same alert shows different counts on each load.

### H-09: Fabricated History Entries
- **File:** `alertService.ts:220-235`
- **Detail:** If backend doesn't return `history`, two fake historical incidents are injected with fabricated dates and descriptions.

### H-10: Alert Time Filter Comparison Bug
- **File:** `alertService.ts:263`
- **Detail:** `from.getTime() !== now.getTime()` is virtually always true (millisecond difference). Unknown period strings send near-zero-width time range.

### H-11: Race Condition in `GenerateAlertID()`
- **File:** `shared/database/alert_repo.go:354-360`
- **Detail:** Count-based ID generation. Two concurrent creations → duplicate primary keys.

### H-12: Race Condition in `GenerateTicketID()`
- **File:** `shared/database/ticket_repo.go:162-169`
- **Detail:** Same count-based race condition as alerts.

### H-13: `SkipDefaultTransaction: true` With No Manual Transactions
- **File:** `shared/database/database.go:117`
- **Detail:** GORM transactions disabled globally, but no repo method uses `db.Transaction()`. Multi-step operations like `UpdateLoginAttempt` are not atomic.

### H-14: Race Condition on Account Lockout
- **File:** `handlers/auth.go:200-234`
- **Detail:** Read-then-write pattern for failed login attempts. Two concurrent failures could both read count=4, both increment, but only one triggers lock.

### H-15: JWT in URL Query Parameter
- **File:** `handlers/auth.go:725`
- **Detail:** Token passed in URL query param. Logged in server access logs, browser history, referrer headers.

### H-16: 8 Missing Alert Columns in Go Model
- **File:** `shared/models/alert.go:12-50`
- **Detail:** `device_name`, `device_ip`, `device_icon`, `device_model`, `device_vendor`, `ai_title`, `confidence`, `raw_data` exist in init.sql but not in Go model.

### H-17: `ticketService.createTicket` Sends `category` Mapped to `priority`
- **File:** `ui/src/features/tickets/services/ticketService.ts:346`
- **Detail:** `category: data.priority` — corrupts category statistics. Priority values sent as categories.

### H-18: `ticketService.createTicket` Sends Device Name as Device ID
- **File:** `ticketService.ts:348`
- **Detail:** `device_id: data.deviceName` — string name sent where numeric/string ID expected.

### H-19: `createTicket` camelCase vs snake_case for `alertId`
- **File:** `alertService.ts:499`
- **Detail:** Sends `alertId` (camelCase) but backend expects `alert_id` (snake_case).

### H-20: AppHeader Accesses Non-Existent Alert Properties
- **File:** `ui/src/components/layout/AppHeader.tsx:179-181`
- **Detail:** `alert.aiTitle`, `alert.device?.name`, `alert.timestamp?.relative` — none exist on API Alert type.

### H-21: AppHeader Search Accesses Non-Existent Properties
- **File:** `AppHeader.tsx:252-256, 278-279`
- **Detail:** `alert.aiSummary`, `ticket.ticketNumber`, `ticket.deviceName` — wrong field names.

### H-22: `setOAuthToken` Missing User Profile Load
- **File:** `authService.ts:267-269`
- **Detail:** After OAuth, no user profile is loaded. `currentUser` remains null.

### H-23: HttpService 401 Handler Doesn't Clear `noc_user`
- **File:** `ui/src/shared/api/httpClient.ts:100-108`
- **Detail:** Clears `noc_token` but not `noc_user`. Stale user data persists in localStorage.

### H-24: No Retry Logic in HttpService
- **File:** `httpClient.ts`
- **Detail:** No retry for 502/503/504. One failed request breaks polling cycle.

### H-25: `database.go sync.Once` Prevents Re-initialization
- **File:** `shared/database/database.go:86-91`
- **Detail:** If `Init()` fails (temporary network issue), it cannot retry. App needs full restart.

### H-26: Fabricated Resolution Timestamps in IncidentHistoryPage
- **File:** `ui/src/pages/incidents/IncidentHistoryPage.tsx:362-364`
- **Detail:** When `resolved_at` is missing, code generates random resolution time (5-65min). MTTR/SLA metrics are partially fabricated with no disclaimer.

### H-27: 11 Non-Functional Buttons/Features Across Pages
- **Locations:**
  - ConfigurationPage: Import button (no onClick), expanded row controls (5 buttons, no handlers)
  - IncidentHistoryPage: Prevention actions (6 buttons: Create Ticket, View Policy, etc.), Archive button
  - TrendsPage: PDF export button (PDF not implemented, only CSV exists)

### H-28: `common.go` Uses MySQL `CONCAT()` on PostgreSQL
- **File:** `handlers/common.go:1060`
- **Detail:** `CONCAT()` is MySQL-specific. Will fail on PostgreSQL (the target database).

### H-29: Runbooks Are Entirely In-Memory (No DB Table)
- **File:** `handlers/runbooks.go`
- **Detail:** Uses package-level `demoRunbooks` slice. All data lost on restart. Race condition on concurrent writes.

### H-30: Audit Log Entries Are Never Written
- **File:** `shared/database/audit_repo.go`
- **Detail:** Repository has only read operations. No handler or middleware WRITES audit log entries. The table is always empty.

### H-31: `isAuthenticated()` OR Condition Creates Inconsistent State
- **File:** `authService.ts:260-262`
- **Detail:** `_currentUser !== null || HttpService.hasToken()` — user can be null while token exists, causing null reference in UI.

### H-32: App.tsx Audit Log Route Has No RBAC Guard
- **File:** `ui/src/App.tsx:147-149`
- **Detail:** `/admin/audit-log` route renders for any authenticated user who types the URL. Sidebar hides it for non-sysadmin, but URL access is unprotected.

### H-33: No Error Boundary Around Lazy-Loaded Components
- **File:** `ui/src/App.tsx:53-57`
- **Detail:** `withSuspense` wraps with `Suspense` but no `ErrorBoundary`. Failed chunk loads = white screen.

### H-34: Search Debounce Missing on RunbooksPage and AuditLogPage
- **Files:** `RunbooksPage.tsx:607-608`, `AuditLogPage.tsx:603-606`
- **Detail:** Every keystroke fires an API call. Typing "network" sends 7 requests.

### H-35: ConfigurationPage Has 23 Raw `fetch()` Calls
- **File:** `ui/src/pages/configuration/ConfigurationPage.tsx`
- **Detail:** 23 direct `fetch()` calls bypassing the service layer. Duplicates auth header logic.

### H-36: Duplicate Alert Polling (Double Network Overhead)
- **File:** `ui/src/components/layout/AppHeader.tsx:98-113, 461`
- **Detail:** NotificationDropdown polls every 30s AND AppHeader polls every 30s. Same endpoint, separate requests.

### H-37: SysAdminView User Stats — Hardcoded Role Permissions Matrix
- **File:** `ui/src/pages/dashboard/views/SysAdminView.tsx:1392-1396`
- **Detail:** Role permissions are hardcoded in the frontend, not fetched from backend RBAC.

### H-38: Weak Temporary Password Generation
- **File:** `ui/src/features/auth/services/userService.ts:187-194`
- **Detail:** Uses `Math.random()` (not cryptographically secure) for password generation. Password generated client-side and sent over network.

---

## 4. MEDIUM Issues

### M-01: 190+ Inline Styles Across Frontend Pages
Pages with heaviest inline styles:
- ProfilePage.tsx: 60+ inline style attributes, no SCSS file
- SLAReportsPage.tsx: 60+ inline style attributes
- ConfigurationPage.tsx: 50+ inline style attributes
- TopologyPage.tsx: ~290 lines of CSS as template literal
- OnCallPage.tsx: ~250 lines of CSS as template literal

### M-02: 29+ Hardcoded Hex Color Values
Every page uses raw hex values (`#24a148`, `#da1e28`, `#0f62fe`, etc.) instead of Carbon design tokens. At least 4 different green shades used inconsistently.

### M-03: 26+ `console.error`/`console.warn` Statements Instead of Logger
Logger service exists (`shared/utils/logger.ts`) with category loggers but NONE of the 23+ pages use it.

### M-04: 12+ `as any` Type Assertions Across Frontend
Multiple type-unsafe casts that defeat TypeScript's purpose.

### M-05: 2 `@ts-ignore` Suppressions (SettingsPage.tsx)
Lines 130 and 261 suppress type errors that should be properly typed.

### M-06: Settings Page Features That Do Nothing
- Language selector: 6 languages defined, zero i18n framework. Changing language does nothing.
- Timezone selector: Value saved to localStorage, never consumed. Dates never formatted with user timezone.
- Auto-refresh toggle: Stored in localStorage, no code reads it to actually auto-refresh.
- Sound notifications toggle: Not implemented.

### M-07: 9 localStorage Keys That Should Be Backend-Persisted
- Report generation counts/timestamps (ReportsHubPage)
- General settings (language, timezone, refresh) (SettingsPage)
- Global config settings fallback (ConfigurationPage)
- Notification preferences primary storage (SettingsPage)

### M-08: Missing Error States (8 Pages)
These pages show empty state instead of error when API fails:
- TopologyPage, OnCallPage, AuditLogPage (no error state variable at all)
- TrendsPage, SLAReportsPage, IncidentHistoryPage (console.error only)
- ConfigurationPage (3 table types with no empty state)
- SettingsPage (silent API failure)

### M-09: Missing useEffect Cleanup / AbortController (5+ Pages)
- AlertDetailsPage, DeviceDetailsPage, TrendsPage: No fetch abort on unmount
- ServiceStatusPage: `setTimeout` for toast not cleaned up
- Multiple pages: `isMounted` guard only prevents invocation, not in-flight state updates

### M-10: `resolved_at` Not Cleared on Ticket Reopen
- **File:** `ticket_repo.go:128-132`
- **Detail:** Setting status back to `open` doesn't clear `resolved_at`. Corrupts MTTR calculations.

### M-11: ILIKE Search Without Metacharacter Escaping
- **Files:** `user_repo.go:159-163`, `audit_repo.go:61-66`
- **Detail:** `%` and `_` in search input match unintended rows.

### M-12: Rate Limiter Is Fixed Window (Not Sliding)
- **File:** `shared/middleware/ratelimit.go:88-110`
- **Detail:** Client can make 2x the rate limit in a short window by timing requests at period boundaries.

### M-13: `handleToggleGlobalSetting` — Optimistic Update With No Rollback
- **File:** `ConfigurationPage.tsx:220-231`
- **Detail:** If PUT fails, UI shows toggled state but server has old state.

### M-14: Missing Validation on Configuration Forms
- ConfigurationPage: No validation on condition value range, duration, description length
- RunbooksPage: No title length validation, no character limit on TextArea
- AuditLogPage: No date range validation (start can be after end)

### M-15: Pagination Not Reset on Filter Change
- TopologyPage: `connPage` not reset when filters change
- DeviceExplorerPage: Pagination state not reset on filter change

### M-16: KPICard Missing `onKeyDown` Handler
- **File:** `ui/src/components/ui/KPICard/KPICard.tsx:104-111`
- **Detail:** Has `role="button"` and `tabIndex={0}` but no keyboard activation handler.

### M-17: `formatTimestamp` in AuditLogPage Doesn't Handle Invalid Dates
- **File:** `AuditLogPage.tsx:217-232`
- **Detail:** `new Date(invalid)` returns `Invalid Date` object that isn't caught by try/catch.

### M-18: CSV Export Only Exports Current Page
- **File:** `AuditLogPage.tsx:457-486`
- **Detail:** Only exports currently loaded page of data, not all records.

### M-19: ServiceStatusPage Restart Button Is a No-Op
- **File:** `ServiceStatusPage.tsx:740-747`
- **Detail:** Shows "not yet implemented" toast. No indication to user that button is placeholder.

### M-20: ServiceStatusPage Uses Own Toast Instead of Shared ToastProvider
- **File:** `ServiceStatusPage.tsx:925-934`
- **Detail:** Inconsistent with project's shared toast pattern.

### M-21: Logs Modal Doesn't Reset State on Close
- **File:** `ServiceStatusPage.tsx:858`
- **Detail:** Previous service's logs briefly visible when reopening for different service.

### M-22: RunbooksPage `isSaving` Not Reset on Modal Close
- **File:** `RunbooksPage.tsx:393-398`
- **Detail:** If modal closed during save, next open shows "Saving..." state.

### M-23: RunbooksPage Delete — No Loading State
- **File:** `RunbooksPage.tsx:484-504`
- **Detail:** Delete button not disabled during operation. User can click multiple times.

### M-24: `httpClient.ts` Returns `{} as T` on Empty Response
- **File:** `httpClient.ts:133`
- **Detail:** If `T` is `string[]` or `number`, `{}` causes runtime errors.

### M-25: Browser-Specific Error Check in httpClient
- **File:** `httpClient.ts:160`
- **Detail:** `error.message.includes('fetch')` — Firefox says "NetworkError" not "Failed to fetch".

### M-26: Missing Indexes in init.sql vs GORM Tags
- Multiple tables have Go GORM `index` tags for fields that init.sql doesn't create indexes for (e.g., `google_id`, `verification_token`, `reset_token`, `category`, `assignee`).

### M-27: `AuditLog.ToResponse()` Nil Map Panic Risk
- **File:** `shared/models/audit.go:90`
- **Detail:** `map[string]interface{}(a.Details)` produces nil map when Details is nil. Downstream code accessing keys will panic.

### M-28: Hardcoded Refresh Intervals
- SLAReportsPage: 60s (`setInterval(doFetch, 60000)`)
- TrendsPage: 60s
- IncidentHistoryPage: 60s
- OnCallPage: 60s
- ServiceStatusPage: 15s
- All hardcoded, none configurable via settings.

### M-29: ToastContext Double Auto-Dismiss
- **File:** `ui/src/contexts/ToastContext.tsx:110-113, 144`
- **Detail:** Custom setTimeout AND Carbon's internal timeout both try to dismiss. Race condition.

### M-30: Form Step List Uses Array Index as Key
- **File:** `RunbooksPage.tsx:810`
- **Detail:** `key={index}` causes React reconciliation issues when steps reordered/removed.

### M-31: No Global Error Boundary in main.tsx
- **File:** `ui/src/main.tsx:17-21`
- **Detail:** `<StrictMode><App /></StrictMode>` has no Error Boundary. React rendering errors cause full white screen.

### M-32: Login Page OAuth Error — URL Parameter Injection
- **File:** `ui/src/pages/auth/login/index.tsx:45`
- **Detail:** `decodeURIComponent(oauthError)` from URL displayed directly. Potential phishing via crafted URLs.

### M-33: Registration Username Auto-Derived from Email
- **File:** `ui/src/pages/auth/register/index.tsx:65`
- **Detail:** `email.split('@')[0]` — problematic for `john+tag@` or very long local parts. No conflict check.

### M-34: Registration Missing Password Complexity Validation
- **File:** `register/index.tsx:44-58`
- **Detail:** Only checks length >= 8. No uppercase/lowercase/number/special char requirements.

### M-35: `ticketService` Has `console.log` in Production Code
- **File:** `ticketService.ts:351, 367`
- **Detail:** Logs sensitive ticket data (descriptions, assignees) to browser console.

### M-36: Threshold Rule Severity Validation Internally Inconsistent
- **File:** `shared/models/ticket.go` CreateRuleRequest binding
- **Detail:** Binding allows `critical major warning info` but Go constants define `critical high medium low info`. `major` and `warning` not in constants; `high` and `low` not in binding.

### M-37: Unused `_resolvedTickets` State in IncidentHistoryPage
- **File:** `IncidentHistoryPage.tsx:299`
- **Detail:** Tickets are fetched and stored but never rendered. Wasted API call.

### M-38: Direct DOM Manipulation in IncidentHistoryPage
- **File:** `IncidentHistoryPage.tsx:903-906`
- **Detail:** `document.querySelector` to click Carbon's expand button. Fragile if Carbon changes class names.

### M-39: TrendsPage "Updated 5m ago" Is Hardcoded Static Text
- **File:** `TrendsPage.tsx:698`
- **Detail:** Always says "Updated 5m ago" regardless of when data was actually fetched.

### M-40: TrendsPage "System Operational" Badge Is Hardcoded
- **File:** `TrendsPage.tsx:397, 424, 439`
- **Detail:** Always shows "System Operational" regardless of actual system health.

### M-41: OnCallPage "Schedule Coverage" Always 100%
- **File:** `OnCallPage.tsx:300`
- **Detail:** KPI value `'100%'` is hardcoded, not computed from actual data.

### M-42: Logger `saveToStorage()` Called on Every Log Entry
- **File:** `ui/src/shared/utils/logger.ts:87-88`
- **Detail:** Every log entry triggers `JSON.stringify` + `localStorage.setItem`. Hundreds of writes per minute with debug logging.

### M-43: Logger `child()` Creates Throwaway LogStorage
- **File:** `logger.ts:163-167`
- **Detail:** Constructor creates LogStorage (reads localStorage), then immediately overwrites with parent's storage.

### M-44: `Total Processed` Metric Hardcoded to 100
- **File:** `alertService.ts:384`
- **Detail:** `value: 100` regardless of API response.

### M-45: `UserService.getUsers()` Swallows Permission Errors
- **File:** `userService.ts:85-88`
- **Detail:** 403 Forbidden looks identical to "endpoint not available". Admin dashboard shows empty user list.

### M-46: User ID Type Inconsistency (`string` vs `number`)
- **Files:** `userService.ts:28`, `authService.ts:93`
- **Detail:** ManagedUser.id is `string`, auth User.id is `number`. Same user has different ID types in different contexts.

### M-47: `alertService.exportReport` Always Downloads as `.csv`
- **File:** `alertService.ts:514`
- **Detail:** File extension hardcoded to `.csv` even when `format === 'pdf'`.

### M-48: Runbooks Nested Interactive Elements
- **File:** `RunbooksPage.tsx:674-696`
- **Detail:** Edit/Delete `IconButton` inside `ClickableTile` — accessibility violation.

### M-49: Multiple Status Dot Spans Without Accessible Labels
- **Files:** `OnCallPage.tsx:446-451`, `ServiceStatusPage.tsx:684, 773`
- **Detail:** Visual-only indicators with no `aria-label` for screen readers.

### M-50: `ProtectedRoute` Token Processing Timer
- **File:** `ProtectedRoute.tsx:47-51`
- **Detail:** 50ms `setTimeout` that sets `tokenProcessed` — fragile timing assumption.

### M-51: Login `from` State Lost During OAuth Flow
- **File:** `login/index.tsx:37, 86`
- **Detail:** OAuth involves full page navigation to Google. Router state with redirect destination is lost.

### M-52: Post-Registration setTimeout Not Cleaned Up
- **File:** `register/index.tsx:74-76`
- **Detail:** 2s redirect timer not cleaned up on unmount.

---

## 5. LOW Issues

*(60+ issues — abbreviated for readability. Key categories:)*

### Inline Styles & CSS
- ProfilePage: No SCSS file at all (60+ inline styles)
- Badge hardcoded `#ffffff` text color fails on light-colored badges
- PageLoader hardcoded dark background `#161616`
- PageHeader breadcrumbs use `crumb.label` as key (collision risk)

### Missing Endpoints in api.config.ts
- `/devices/:id/metrics`, `/on-call/*`, `/topology`, `/runbooks/*`, `/reports/sla/*` — all use hardcoded paths instead of `API_ENDPOINTS`

### Dead Code
- APIKey model defined but no repository
- `CORS()` in middleware/headers.go never used (main.go uses gin-contrib/cors)
- `ErrorHandler()` middleware defined but never registered
- `RateLimiterConfig.BurstSize` field never used
- Custom `intToString()` instead of `strconv.Itoa()`
- `InjectRoleFromHeader()` testing helper with no env guard

### Missing Features
- No 404 page for public routes (only protected routes have catch-all)
- 3 pages missing from searchablePages (topology, runbooks, on-call)
- No PDF export (only CSV exists)
- No WebSocket/SSE for real-time updates
- `env.ts` doesn't exist as separate file

### Type Safety
- `CARBON_COLORS` CSS custom properties can't be used in JS-only contexts (Canvas, chart libs)
- `SEVERITY_COLORS.info` (#0043ce) differs from `CHART_COLORS.info` (#4589ff)
- `createDonutChartOptions` hardcodes center label as 'Alerts'
- `high` and `major` share same priority value in severity config

### Database
- 4 SQL tables have no Go GORM model (`ingestion_data`, `ai_results`, `ai_metrics`, `alert_history`)
- 11 entity types have no TypeScript interface
- No FK constraints on most relationships
- `audit_logs` uses `TIMESTAMP WITH TIME ZONE` while all other tables use plain `TIMESTAMP`

---

## 6. Systemic / Cross-Cutting Issues

### 6.1 Inconsistent Service Patterns

| Service | Has Mock? | Falls back to mock on error? | Uses `API_ENDPOINTS`? |
|---------|-----------|------------------------------|----------------------|
| alertService | No | No (throws) | Yes |
| ticketService | Yes | No (throws in API mode) | Yes |
| deviceService | Yes | Yes (silently!) | Partially |
| authService | N/A | No | Partially (6 wrong paths) |
| userService | No | No (returns []) | Yes |
| topologyService | No (inline) | Returns empty | No (hardcoded) |
| onCallService | No (inline) | Returns empty | No (hardcoded) |
| runbookService | No (inline) | Returns empty | No (hardcoded) |
| auditLogService | No (inline) | Returns empty | No (hardcoded) |
| serviceStatusClient | No (inline) | Throws | No (hardcoded) |

### 6.2 Token Key Fragmentation
- `httpClient.ts`: `TOKEN_KEY = 'noc_token'`
- `authService.ts`: References `'noc_token'` as raw string (not importing TOKEN_KEY)
- `PriorityAlertsPage.tsx`: Uses `'auth_token'` (WRONG)
- `TicketsPage.tsx`: Uses `'auth_token'` (WRONG)
- `httpClient.ts` 401 handler clears `noc_token` but not `noc_user`

### 6.3 Base URL Construction Duplicated
Same pattern repeated in 5 service files:
```typescript
const baseUrl = env.apiBaseUrl.replace(/\/$/, '');
const apiPath = baseUrl ? `${baseUrl}/api/${env.apiVersion}` : `/api/${env.apiVersion}`;
```

### 6.4 No Centralized Error Interceptor
Each service handles errors independently: throw, return null, return empty array, log and rethrow. No common pattern for toast on 500, retry on transient failure, or error logging.

### 6.5 Singleton Initialization at Module Load
All services instantiated at import time. If constructor throws, entire module graph crashes. `console.info` fires during evaluation.

### 6.6 Missing 5 Backend GORM Models for SQL Tables
`ingestion_data`, `ai_results`, `ai_metrics`, `alert_history`, `devices` (proper model) have SQL tables but no GORM models in `shared/models/`.

### 6.7 No Foreign Key Constraints
Most relationships have no FK: `tickets.alert_id`, `tickets.device_id`, `sessions.user_id`, `api_keys.user_id`, `audit_logs.user_id`, `ticket_comments.ticket_id`.

---

## 7. Full Issue Index

| ID | Severity | Category | File(s) | Summary |
|----|----------|----------|---------|---------|
| C-01 | CRITICAL | Security | middleware/auth.go, main.go | RBAC middleware never applied to routes |
| C-02 | CRITICAL | API | api.config.ts, main.go | 6 auth endpoints have wrong paths (404) |
| C-03 | CRITICAL | Auth | authService.ts:123 | Role parsing broken; all users get network-ops |
| C-04 | CRITICAL | Auth | authService.ts:132 | Permissions hardcoded for all roles |
| C-05 | CRITICAL | Backend | users.go:343 | Nil pointer crash on GetByID error |
| C-06 | CRITICAL | Security | auth.go:142-189 | Demo mode accepts any credentials |
| C-07 | CRITICAL | Data | ticket.go:36, init.sql | Tags never persist (gorm:"-", no column) |
| C-08 | CRITICAL | Data | common.go, init.sql | Device model has no GORM backing, column mismatches |
| C-09 | CRITICAL | Data | alert.go:43 | AIConfidence GORM column name wrong |
| C-10 | CRITICAL | Data | severity.go, init.sql | Alert severity mismatch (5 vs 7 values) |
| C-11 | CRITICAL | Data | constants, init.sql | Alert status mismatch (4 vs 6 values) |
| C-12 | CRITICAL | Security | auth.go:577,607 | OAuth state never validated (CSRF) |
| C-13 | CRITICAL | Backend | auth.go:168 | strings.Split panic on single-word names |
| C-14 | CRITICAL | Security | auth.go:696 | OAuth bypasses account deactivation |
| C-15 | CRITICAL | Auth | ProtectedRoute.tsx:75 | tokenProcessed creates persistent auth bypass |
| C-16 | CRITICAL | Auth | N/A | No AuthContext; no reactive auth state |
| C-17 | CRITICAL | Auth | authService.ts:267 | OAuth login never loads user profile |
| C-18 | CRITICAL | Security | main.go:309-315 | Internal API key allows all when not configured |
| H-01 | HIGH | Auth | PriorityAlertsPage.tsx:166 | Wrong token key (auth_token vs noc_token) |
| H-02 | HIGH | Auth | TicketsPage.tsx:91 | Wrong token key (auth_token vs noc_token) |
| H-03 | HIGH | Security | authService.ts:250-255 | Logout doesn't invalidate server session |
| H-04 | HIGH | Auth | authService.ts | No token refresh mechanism |
| H-05 | HIGH | Data | deviceService.ts:290 | Silent mock fallback on all errors |
| H-06 | HIGH | Data | alertService.ts | No mock fallback at all |
| H-07 | HIGH | Types | alertService.ts:90 | transformAlert uses any/any |
| H-08 | HIGH | Data | alertService.ts:219 | similarEvents falls back to Math.random() |
| H-09 | HIGH | Data | alertService.ts:220 | Fabricated history entries |
| H-10 | HIGH | Logic | alertService.ts:263 | Time filter comparison always true |
| H-11 | HIGH | Concurrency | alert_repo.go:354 | Race condition in GenerateAlertID |
| H-12 | HIGH | Concurrency | ticket_repo.go:162 | Race condition in GenerateTicketID |
| H-13 | HIGH | Data | database.go:117 | Transactions disabled, none used manually |
| H-14 | HIGH | Concurrency | auth.go:200 | Race condition on account lockout |
| H-15 | HIGH | Security | auth.go:725 | JWT in URL query parameter |
| H-16 | HIGH | Data | alert.go | 8 missing columns in Go model |
| H-17 | HIGH | Data | ticketService.ts:346 | category mapped to priority |
| H-18 | HIGH | Data | ticketService.ts:348 | device name sent as device ID |
| H-19 | HIGH | API | alertService.ts:499 | camelCase vs snake_case mismatch |
| H-20 | HIGH | Types | AppHeader.tsx:179 | Access non-existent alert properties |
| H-21 | HIGH | Types | AppHeader.tsx:252 | Search accesses wrong property names |
| H-22 | HIGH | Auth | authService.ts:267 | OAuth missing user profile load |
| H-23 | HIGH | Auth | httpClient.ts:100 | 401 doesn't clear noc_user |
| H-24 | HIGH | Resilience | httpClient.ts | No retry logic |
| H-25 | HIGH | Resilience | database.go:86 | sync.Once prevents DB reconnection |
| H-26 | HIGH | Data | IncidentHistoryPage.tsx:362 | Fabricated resolution timestamps |
| H-27 | HIGH | UX | Multiple | 11 non-functional buttons |
| H-28 | HIGH | Backend | common.go:1060 | MySQL CONCAT on PostgreSQL |
| H-29 | HIGH | Data | runbooks.go | In-memory only, no DB table |
| H-30 | HIGH | Data | audit_repo.go | Audit entries never written |
| H-31 | HIGH | Auth | authService.ts:260 | isAuthenticated OR inconsistency |
| H-32 | HIGH | Security | App.tsx:147 | Audit log route no RBAC guard |
| H-33 | HIGH | UX | App.tsx:53 | No ErrorBoundary for lazy loads |
| H-34 | HIGH | Performance | RunbooksPage, AuditLogPage | No search debounce |
| H-35 | HIGH | Architecture | ConfigurationPage | 23 raw fetch() calls |
| H-36 | HIGH | Performance | AppHeader.tsx | Duplicate alert polling |
| H-37 | HIGH | Security | SysAdminView.tsx:1392 | Hardcoded role permissions |
| H-38 | HIGH | Security | userService.ts:187 | Math.random() for passwords |

---

---

## 8. ROUND 2: Infrastructure, Security & Deep-Dive Findings

*(Additional 130+ issues found in targeted deep-dive audits)*

### 8.1 HARDCODED SECRETS & CREDENTIALS IN REPOSITORY (CRITICAL)

| File | Line | Secret | Impact |
|------|------|--------|--------|
| `infra/prod/.env` | 2 | `JWT_SECRET=noc-platform-dev-secret-key-2026` | Can forge auth tokens |
| `infra/prod/.env` | 6 | `POSTGRES_PASSWORD=secret` | Direct DB access |
| `infra/prod/.env` | 26 | `WATSONX_API_KEYS=bUhO1vxg...` | Real IBM Watson API key |
| `infra/prod/.env` | 28 | `WATSONX_PROJECT_ID=913d34b6-...` | Real project ID |
| `ai-core/.env` | 1 | Same Watson API key (duplicate) | |
| `ingestor/.env` | 22 | `JWT_SECRET=TNTnW8su1/wez...` | Different JWT secret |
| `ingestor/.env` | 27 | `GOOGLE_CLIENT_ID=708452771845-...` | Real OAuth client ID |
| `ingestor/.env` | 28 | `GOOGLE_CLIENT_SECRET=GOCSPX-lyZ...` | Real OAuth secret |
| `ingestor/.env` | 34-35 | `SMTP_USERNAME=ujjwalsidhu123@gmail.com`, `SMTP_PASSWORD=aftovybpmgmgqxor` | Real Gmail credentials |
| `ui/.env` | 22 | `VITE_GOOGLE_CLIENT_ID=708452771845-...` | OAuth client in frontend |
| `infra/prod/docker-compose.yml` | 35-36 | PGAdmin: `admin@admin.com` / `root` | Admin panel access |

### 8.2 Docker & Infrastructure Security (30 issues)

**Running as Root (5 Dockerfiles — no USER directive):**
- `ingestor/api_gateway/Dockerfile:17-24`
- `ingestor/event_router/Dockerfile:19-26`
- `ingestor/ingestor_core/Dockerfile:19-25`
- `ai-core/Dockerfile:15-19`
- `datasource/Dockerfile:16-21`

**Exposed Ports Without Authentication:**
- PostgreSQL on `0.0.0.0:5432` (docker-compose.yml:14)
- Kafka on `0.0.0.0:9092` with PLAINTEXT only (docker-compose.yml:62)
- Zookeeper on `0.0.0.0:2181` (docker-compose.yml:46)
- Kafka-UI admin on `0.0.0.0:8090` with NO auth (docker-compose.yml:86)
- PGAdmin on `0.0.0.0:5050` with default credentials

**Missing Docker Security:**
- No resource limits (memory/CPU) on any of 11 containers
- No .dockerignore for 5 Go services (build context includes .env files!)
- No health checks on datasource, ai-core, ui containers
- Source maps enabled in production build (`vite.config.ts:28`)
- Minification disabled (`vite.config.ts:30`)
- Database SSL disabled (`POSTGRES_SSL_MODE=disable`)

**Missing Security Headers in nginx.conf:**
- No `Strict-Transport-Security` (HSTS)
- No `Content-Security-Policy`
- No `Referrer-Policy`
- No `Permissions-Policy`

### 8.3 Go Backend Routing & Middleware Issues

**RBAC Missing on Configuration Endpoints (CRITICAL):**
- `handlers/configuration.go` — ALL 12 CRUD operations (CreateRule, UpdateRule, DeleteRule, CreateChannel, UpdateChannel, DeleteChannel, CreatePolicy, UpdatePolicy, DeletePolicy, CreateWindow, UpdateWindow, DeleteWindow) have NO role checks
- `handlers/global_settings.go:40-60` — `UpdateGlobalSettings()` has NO role check. Any user can toggle Maintenance Mode, Auto-resolve, AI Correlation globally.

**Missing Request Safety:**
- No request body size limits (no `MaxBytesReader` or `MaxMultipartMemory`)
- No HTTP request timeouts (`router.Run()` uses Gin defaults — vulnerable to Slowloris)
- No graceful shutdown (SIGTERM kills in-flight requests, DB connections never closed)
- `database.Get().Close()` never called before exit
- No request ID / correlation ID propagation
- CORS `MaxAge: 12 * time.Hour` too long (6h recommended)
- Rate limiter is global — no per-route limits (login brute force not differentiated from reads)

### 8.4 SCSS/CSS Issues (100+ findings)

**Hardcoded Values:**
- 50+ hardcoded pixel values across all SCSS files (should use Carbon spacing tokens `$spacing-*`)
- 30+ hardcoded font-size values NOT using Carbon type scale (e.g., `10px`, `13px`, `0.625rem`)
- Multiple hardcoded box-shadows instead of Carbon shadow tokens
- Hardcoded border-radius values instead of tokens

**Z-Index Chaos (no defined scale):**
- `index.scss:235` — `z-index: 9000` (auth dropdown)
- `index.scss:461` — `z-index: 8000` (search)
- `index.scss:546` — `z-index: 9999` (search results)
- `index.scss:630` — `z-index: 9999` (notification dropdown)
- `_ticket-details.scss:29` — `z-index: 9999` (toast)
- `_alert-details.scss:33` — `z-index: 9999` (toast)
- `_settings.scss:17` — `z-index: 9999` (toast)

**Duplicate Selectors:**
- `.kpi-row` defined 4+ times across `_trends.scss`, `_dashboard.scss`, `_incident-history.scss`
- `.chart-section` and `.chart-tile` duplicated with minor variations

**Carbon Internal Overrides (Fragile):**
- 20+ overrides of `.cds--*` internal Carbon classes
- `DataTableWrapper.scss:65-129` — extensive Carbon DataTable internals
- `_dashboard.scss:77-100` — `.cds--cc--donut` structure
- `_configuration.scss:132-154` — deep Carbon form overrides

**Media Query Inconsistencies:**
- Mixed use of `1055px`, `1056px`, `1057px` for tablet breakpoint
- No standardized breakpoint variables

**Missing Dark Theme Support:**
- `_alert-details.scss:560` — hardcoded `$gray-100` background
- `_trends.scss:502-514` — hardcoded icon badge colors

### 8.5 Datasource & Ingestor Pipeline Issues (80 findings)

**Critical Resource Leaks:**
- `event_router/storage/kafka.go:18-24` — Creates NEW Kafka producer for EVERY event published. Memory exhaustion in production.
- `event_router/main.go:85` — Kafka publish happens BEFORE validation (line 91). Invalid events enter Kafka.

**Race Conditions:**
- `datasource/pkg/snmptrap/generator.go:9-10` — Global `rand` usage acknowledged as TODO. Race condition with concurrent goroutines.
- `datasource/pkg/syslogsim/generator.go:9-10` — Same deprecated `rand.Seed()` race.
- `agents_api/watson.go:19-23` — IAM token cache uses `sync.Mutex` but token/expiry are global vars.

**Compile Errors:**
- `ingestor/internal/normalizer/normalizer.go:6` — Wrong import path `"ingestor/internal/model"` (should be full module path)
- `ingestor/internal/enricher/enricher.go:7` — Same broken import

**Missing Error Handling (10 instances):**
- `time.Parse()` errors ignored in 3 mapper files (`syslog.go:24`, `snmp.go:25`, `metadata.go:23`)
- `json.Marshal()` errors ignored in `kafka_producer.go:34`, `kafka.go:26`, `watson.go:141`
- UDP read errors silently consumed in `udplisten.go:41`

**No Retry Logic:**
- `ingestor_core/forwarder/forwarder.go` — Single HTTP attempt, no retry
- `agents_api/watson.go` — No retry on IAM token or Watsonx API failure

**No Graceful Shutdown:**
- 7 of 8 components have no SIGTERM/SIGINT handler
- `datasource/main.go:127` calls `os.Exit(0)` directly

**Dead Code / Stubs:**
- `datasource/simulator/` — Router/Switch implementations are STUBS that never generate actual traps
- `datasource/db/` — Entire package marked "NOT part of default runtime"
- `ingestor/internal/` — Duplicate models shadowing `ingestor/shared/`

**Disconnected Pipeline:**
- Events published to Kafka but NO Kafka consumer exists downstream
- `agents_api/main.go` not wired to event_router output

### 8.6 Database Init SQL Deep-Dive (13 findings)

**Already documented in C-10/C-11:** Alert severity/status CHECK mismatches.

**New findings:**
- **Missing FK constraints:** `sessions.user_id` (line 140), `api_keys.user_id` (line 155) — orphaned records possible
- **Seed data inconsistency:** `dev-007` has `alert_count = 0` but `alert-008` references it (line 309)
- **ON CONFLICT incomplete:** `ai_metrics` (line 321) and `alert_history` (line 379) use `ON CONFLICT DO NOTHING` without specifying conflict column
- **Missing CHECK constraints:** `notification_channels.type` (line 222) accepts any string, `devices.status` (line 87) accepts any string
- **Threshold rule severity mismatch:** Go binding allows `critical major warning info` but alert model uses `critical high medium low info` — no overlap on `major`/`warning` vs `high`/`medium`/`low`

### 8.7 Frontend Performance Issues

**Missing Memoization:**
- `KPICard` component not wrapped in `React.memo()` — re-renders in 20+ locations
- `PriorityAlertsPage:305` — `toggleQuickFilter` not wrapped in `useCallback`
- `TrendsPage:127` — `handleInsightAction` not wrapped in `useCallback`

**Potential Issues:**
- `DeviceDetailsPage:207-212` — `fetchDevice` is not memoized, could cause extra re-renders
- `AlertDetailsPage:28-50` — No `isMounted` check in useEffect for async operations

**Good Practices Found:**
- All 24+ pages code-split with `React.lazy()` ✓
- Timer cleanup generally proper ✓
- Object URL revocation done correctly ✓
- Paginated tables used instead of virtualization (appropriate) ✓

---

## 9. Updated Totals

| Category | Round 1 | Round 2 | Total |
|----------|---------|---------|-------|
| CRITICAL | 18 | 12 | **30** |
| HIGH | 38 | 24 | **62** |
| MEDIUM | 52 | 35 | **87** |
| LOW | 60+ | 60+ | **120+** |
| **Grand Total** | **168+** | **131+** | **~300** |

### New Top Issues Added to Priority List

| Priority | Issue | Source |
|----------|-------|--------|
| CRITICAL | Real credentials committed to repo (.env files with Watson API keys, Google OAuth, Gmail) | §8.1 |
| CRITICAL | Kafka producer per-event (memory leak) in event_router | §8.5 |
| CRITICAL | 12 configuration CRUD endpoints have no RBAC | §8.3 |
| CRITICAL | Global settings modifiable by any user | §8.3 |
| HIGH | All 5 Dockerfiles run as root | §8.2 |
| HIGH | PostgreSQL, Kafka, Zookeeper, PGAdmin, Kafka-UI all exposed without auth | §8.2 |
| HIGH | No request body size limits or HTTP timeouts | §8.3 |
| HIGH | No graceful shutdown in any Go service | §8.3/§8.5 |
| HIGH | Source maps + no minification in production build | §8.2 |
| HIGH | Database SSL disabled | §8.2 |

---

*This document is a READ-ONLY audit plan. No code changes have been executed. Awaiting user approval before proceeding with fixes.*
