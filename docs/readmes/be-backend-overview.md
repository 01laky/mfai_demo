# Backend API — overview (`many_faces_backend`)

This page is a **narrative index** for the ASP.NET Core API submodule. **Source of truth** for ports, scripts, and stack-specific notes remains **[`many_faces_backend/README.md`](../../many_faces_backend/README.md)** (short entry + diagrams) and the split reference under **[`many_faces_backend/docs/`](../../many_faces_backend/docs/README.md)** (index → [`DETAILED_README.md`](../../many_faces_backend/docs/DETAILED_README.md) + [`docs/reference/`](../../many_faces_backend/docs/reference/)).

## What the backend owns

- OAuth2 / JWT sessions, refresh rotation, JWKS, face-scoped routing middleware.
- EF Core + PostgreSQL persistence for social modules, pages, grids, moderation, stats.
- SignalR hubs; Redis-backed workers; gRPC client to **`many_faces_ai`**.

## Where to read next

| Topic | Guide |
| ----- | ----- |
| Auth + tokens | [`authentication-and-sessions.md`](../guides/authentication-and-sessions.md) |
| Capabilities | [`acl-and-capabilities.md`](../guides/acl-and-capabilities.md) |
| Content moderation | [`ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md), [`content-moderation-operations.md`](../guides/content-moderation-operations.md) |
| Operator stats + admin AI | [`admin-dashboard-metrics.md`](../guides/admin-dashboard-metrics.md), [`backend-stats-and-admin-ai-runbook.md`](../guides/backend-stats-and-admin-ai-runbook.md) |
| OpenAPI clients | [`openapi-client-generation.md`](../guides/openapi-client-generation.md) |
| Migrations | [`efcore-migrations-and-seeding.md`](../guides/efcore-migrations-and-seeding.md) |
