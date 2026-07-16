# Sentrix — NOC Intelligence Platform

Architecture documentation for Sentrix, a network operations center (NOC) dashboard that ingests SNMP traps and syslogs, runs IBM WatsonX AI analysis, and surfaces actionable alerts to network engineers.

## Live Deployment

| | |
|--|--|
| **Frontend** | https://ui-bionics-projects.vercel.app |
| **API** | https://bionicop-sentrix-api.hf.space/api/v1/health |
| **Demo credentials** | `admin@admin.com` / `admin123` |

## Architecture Docs

Detailed UML diagrams (component, sequence, class, deployment, use-case, activity) for each service layer are in [`docs/arch/`](docs/arch/):

| Folder | Service |
|--------|---------|
| [`AIProcessing/`](docs/arch/AIProcessing/) | Watson AI core — CVE scoring, RAG, LLM prompt pipeline |
| [`DataSource/`](docs/arch/DataSource/) | SNMP trap + syslog collectors, metadata registration |
| [`Ingestor/`](docs/arch/Ingestor/) | Event ingestion, normalization, API gateway, RBAC |
| [`UI/`](docs/arch/UI/) | React/Carbon dashboard, role-based views, alert details |
| [`Output&Integration/`](docs/arch/Output&Integration/) | Notification channels, ticket integrations |

## Recent Changes

- **Security hardening (2026-07-16)**: PostgreSQL SSL enforced, 4 MB request body cap, CSP headers on Vercel, password strength on all auth flows, GIN release mode
- **CVE matching**: BM25+IDF multi-signal scoring engine with vendor alias expansion replaces keyword-only matching
- **AI loading states**: three-state Watson card (analyzing / pending / ready) with Carbon InlineLoading + SkeletonText
- **RBAC**: server-side permission guards on all 80 API routes with JWT-enforced role authority
