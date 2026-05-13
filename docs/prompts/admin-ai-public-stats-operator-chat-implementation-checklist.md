# Admin operator AI — public aggregate statistics — Implementation checklist

**Canonical spec:** [admin-ai-public-stats-operator-chat-agent-prompt.md](./admin-ai-public-stats-operator-chat-agent-prompt.md)

This file records the **2026-05-13** delivery; every item is **`[x]`** by design.

- [x] Add **`PublicStatsSnapshotDto`** (`many_faces_backend/BeDemo.Api/Models/DTOs/PublicStatsSnapshotDto.cs`).
- [x] Add **`IPlatformStatsQueryService`** + **`PlatformStatsQueryService`** with **`GetOperatorDashboardSummaryAsync`** and **`GetPublicSnapshotAsync`**.
- [x] Refactor **`StatsController`**: delegate full operator summary to the service; keep timeseries implementation on the controller.
- [x] Add **`GET /api/Stats/public`** with **`[AllowAnonymous]`** (callers use **`/public/api/Stats/public`** for anonymous access).
- [x] Register **`IPlatformStatsQueryService`** in **`Program.cs`**.
- [x] Update **`Protos/health.proto`**: **`stats_context_json`** on **`GenerateRequest`**; **`FetchPublicStats`**; **`OperatorStatsChat`**.
- [x] Mirror proto in **`many_faces_ai/proto/health.proto`** and implement **`server.py`** (`Generate` context block, **`FetchPublicStats`**, **`OperatorStatsChat`**).
- [x] Update **`many_faces_ai/scripts/generate_proto.sh`** to prefer **`.venv/bin/python`** when present.
- [x] Extend **`IAiGrpcService`** / **`AiGrpcService`**: optional stats JSON on **`GenerateAsync`**; **`OperatorStatsChatAsync`** with same retry semantics as existing RPCs.
- [x] Extend **`ChatHub`**: inject **`IPlatformStatsQueryService`** + **`IConfiguration`**; add **`SendToAiWithOperatorStats`** (operator-only, rate-limited, three modes).
- [x] Add **`AiStats:PublicSnapshotAbsoluteUrl`** to **`appsettings.json`** (empty default) and example in **`appsettings.Development.json`**.
- [x] Update **`FakeAiGrpcService`** in **`ContentModerationTests.cs`** for the expanded **`IAiGrpcService`** surface.
- [x] Add **`StatsControllerTests.GetPublicStats_ShouldReturnOk_WithoutAuth_OnPublicFaceScope`**.
- [x] **`many_faces_admin`**: **`adminAiStatsSettings.ts`** (`off` / `inline` / `live` in **`localStorage`**).
- [x] **`many_faces_admin`**: **`SettingsPage`** + styles; routes (**`useAdminRoutePaths`**, **`routeTranslations`**, **`lazyAdminPages`**, **`AppRoutes`**).
- [x] **`many_faces_admin`**: **`DashboardAiStatsPanel`** + styles; embed on **`DashboardPage`**.
- [x] **`many_faces_admin`**: **`usePublicStatsApi`** + **`PublicStatsSnapshot`** type; fetch via **`absolutePublicFaceUrl('/api/Stats/public')`**.
- [x] **`many_faces_admin`**: **`faceApiRouting`** — **`scopePathForPublicFace`**, **`absolutePublicFaceUrl`**.
- [x] **`many_faces_admin`**: **`ChatPage`** calls **`SendToAiWithOperatorStats`** with the saved mode.
- [x] **`many_faces_admin`**: **`Sidebar`** links for chat + settings; i18n **`en` / `sk` / `cz`** for new copy and **`routes.settings`**.
- [x] Add integration tests for **`GET /api/Stats/public`**: admin face without JWT (**401**), bare `/api/Stats/public` (**400**), authenticated operator on public face (**200**), response excludes operator-only fields, numeric shape for all public snapshot keys.
- [x] Add **`many_faces_ai`** pytest coverage for **`Generate`** + **`stats_context_json`**, invalid **`FetchPublicStats`** URLs, **`OperatorStatsChat`** validation and unreachable live URL.
- [x] Add **`many_faces_admin`** Vitest tests for **`adminAiStatsSettings`** and **`faceApiRouting`** public-face path helpers.
- [x] Update monorepo **`README.md`** (mermaid + bullet), **`docs/guides/admin-dashboard-metrics.md`**, submodule READMEs (**backend**, **admin**, **AI**) for operator statistics and AI modes.
