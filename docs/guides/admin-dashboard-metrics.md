# Admin dashboard metrics (`GET /api/Stats`)

This guide documents the **operator dashboard** statistics API consumed by **`many_faces_admin`** and how it fits into ACL and routing.

## Purpose

- **`GET /api/Stats`** returns a single JSON document (`AdminDashboardSummaryDto`) with **platform-wide counts**: users, faces, pages, social graph, messaging, notifications, UGC (albums/blogs/reels/stories), chat, wall, profile engagement, moderation-related table sizes, and OAuth client count.
- **`GET /api/Stats/timeseries`** returns **histogram buckets** for a selected metric (users, messages, stories, blogs, reels, albums, friend requests, wall tickets) over a UTC date range (`bucket=day|week`).

The admin UI renders **KPI cards**, **Recharts** (line / donut / bar), a **full metrics table**, and (for **`SUPER_ADMIN`**) a **moderation health** strip that still uses **`GET /api/contentmoderation/metrics`** — queue logic is **not** duplicated inside `StatsController`.

## Authorization (critical)

Both endpoints require:

1. A valid **JWT** (`[Authorize]`).
2. **`CanManageAllFaces`** — the same predicate as **`UsersController`**: **admin face HTTP scope** (`IFaceScopeContext.IsAdminFaceScope`, typically URL prefix from `VITE_DEFAULT_FACE_PREFIX`, default `admin`) **and** a global **Admin** or **SuperAdmin** role on the token.

If the SPA calls **`/api/...`** from the **public** face prefix, the user may be authenticated but still receives **`403 Forbidden`** for stats. The admin dashboard shows a localized warning in that case.

Implementation references:

- `many_faces_backend/BeDemo.Api/Controllers/StatsController.cs`
- `many_faces_backend/BeDemo.Api/Utils/PlatformAccessRules.cs`
- `many_faces_backend/BeDemo.Api/Services/AccessEvaluator.cs`

## Frontend wiring

| Area | Location |
| ---- | -------- |
| Types | `many_faces_admin/src/types/adminDashboardStats.ts` |
| TanStack Query | `many_faces_admin/src/hooks/api/useStatsApi.ts` (`useStats`, `useStatsTimeseries`) |
| Charts + merge helpers | `many_faces_admin/src/utils/dashboardChartData.ts` |
| UI | `many_faces_admin/src/pages/DashboardPage.tsx`, `src/components/dashboard/*` |

Charts default to the **last 30 days (UTC)** for the line series (new users vs messages). Content mix and friend-request charts use **snapshot totals** from the summary payload.

## Performance notes

Summary counts are implemented as **sequential `CountAsync`** calls for **EF Core compatibility** (including the **InMemory** test provider). For very large production databases, consider:

- Batched SQL with scalar subselects, or
- `IDbContextFactory<ApplicationDbContext>` with bounded parallelism, or
- Materialized views / read replicas (product decision).

Timeseries currently **loads timestamp columns** in range and **buckets in memory** — acceptable for demo volumes; add database-side `date_trunc` grouping before exposing to large tenants.

## Tests

- **API:** `many_faces_backend/BeDemo.Api.Tests/StatsControllerTests.cs` — unauthorized, forbidden on wrong scope, full summary for admin-scoped operator, timeseries validation and happy path.
- **Admin:** `many_faces_admin/src/utils/__tests__/dashboardChartData.test.ts` — pure merge/chart data helpers.

## Related documentation

- [Admin portal overview](../readmes/admin-portal-overview.md) — high-level admin UX.
- [ACL and capabilities](./acl-and-capabilities.md) — platform vs tenant scope.
- [AI-assisted content approval](./ai-assisted-content-approval.md) — moderation queue (separate from raw table counts on `Stats`).
