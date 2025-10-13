# Alerts Dashboard

This project provides a comprehensive interface for monitoring, managing, and analyzing network alerts retrieved from the Agents API.

---

## Features

### Alerts List
- Display all active and historical alerts from the Agents API.
- Show alert summary with severity level prominently (e.g., Critical, Major, Minor).
- Provide filter and sort options by severity, time, device, or category.

### Alert Details Panel
- Plain-language explanation of each alert.
- Timestamp and affected device or interface.
- Suggested actions or recommended next steps.
- Related metadata such as vendor, device family, and region.

### Severity Indicators
- Color-coded severity levels (e.g., red for critical, yellow for warning).
- Include a severity legend or scale.

### Search and Filter Controls
- Search alerts by keywords such as device name or event type.
- Filters for severity, device family, region, and time intervals.

### Notifications & Real-Time Updates
- Pop-up or toast notifications for new critical alerts.
- Auto-refresh or live updates using web sockets or polling.

### Action Buttons
- Quick action buttons for common remediations



## Multi-Page Structure

### Alerts Overview Page
- Shows all active alerts with severity indicators.
- Includes filters, search, and summary widgets (counts, top devices, trends).

### Alert Details Page
- Displays full details of a selected alert.
- Suggested actions, related metadata, and history per device/region.

### Historical Analysis Page
- Access previous alerts and actions taken.
- Drill-down charts and trend analysis.

### Settings Page (future use)
- User preferences (notifications, saved filters, custom views).
- Accessibility and display settings.

---