# Admin operator AI — public aggregate statistics (SignalR + gRPC) — Agent prompt

## Status

**Engagement:** completed **2026-05-13** (implementation landed on `main` in `many_faces_backend`, `many_faces_admin`, `many_faces_ai`; monorepo documents the contract here).

**Companion checklist (all items ticked):** [admin-ai-public-stats-operator-chat-implementation-checklist.md](./admin-ai-public-stats-operator-chat-implementation-checklist.md)

---

## 1. Mission

Give **platform operators** (users with **`CanManageAllFaces`** under the **admin** face scope) an optional way to attach **non-identifying aggregate statistics** to the existing **admin AI chat** (`SignalR` → `ChatHub` → Python **`many_faces_ai`** over gRPC). Statistics must reflect **only public-style totals** (counts), never private message bodies, OAuth secrets, or moderation audit payloads.

**Primary repositories**

| Repo                 | Scope |
| -------------------- | ----- |
| `many_faces_backend` | `GET /api/Stats/public`, `IPlatformStatsQueryService`, `StatsController` refactor, `ChatHub` + `IAiGrpcService`, `health.proto`, appsettings `AiStats`. |
| `many_faces_admin`   | Settings page (localStorage mode), dashboard AI strip, `ChatPage` hub method, routes/i18n, `absolutePublicFaceUrl` helper for anonymous-safe fetch. |
| `many_faces_ai`      | `Generate` prepends `stats_context_json`; `FetchPublicStats`; `OperatorStatsChat`; `generate_proto.sh` prefers `.venv`. |

**Explicit non-goals**

- Storing operator preferences server-side (browser **`localStorage`** only for mode).
- Teaching the model on PII; no new endpoints that return row-level user content for AI.

---

## 2. Product behaviour

### 2.1 Modes (`admin_ai_public_stats_mode` in `localStorage`)

| Mode     | Behaviour |
| -------- | --------- |
| **`off`** | Same as legacy: `Generate` with conversation prompt only. |
| **`inline`** | API reads **`PublicStatsSnapshotDto`** from EF, serializes camelCase JSON, passes as **`stats_context_json`** on `GenerateRequest`. |
| **`live`** | .NET calls gRPC **`OperatorStatsChat`**; Python **HTTP GET**s **`AiStats:PublicSnapshotAbsoluteUrl`** (must be **`/public/...`** so anonymous GET works), then runs **`Generate`** with the fetched JSON as context. |

### 2.2 SignalR contract

- **Legacy (unchanged for non-admin callers):** `SendToAi(message, history?)` → `ReceiveAiMessage`.
- **Operator stats path:** `SendToAiWithOperatorStats(message, history?, statsMode)` → same **`ReceiveAiMessage`** callback.
- **ACL:** `SendToAiWithOperatorStats` requires **`CanManageAllFaces()`**; otherwise a fixed caller-visible error string is returned.
- **Rate limit:** Reuse existing **`IChatHubAiRateLimiter`** window (`ChatHub` settings).

---

## 3. Backend design notes

### 3.1 `GET /api/Stats/public`

- Controller stays **`[Authorize]`** at class level; action uses **`[AllowAnonymous]`** override.
- **Routing:** Callers must use the **`public`** face prefix (e.g. **`/public/api/Stats/public`**) so **`FaceScopeEnforcementMiddleware`** allows unauthenticated access on a **public** face.
- Payload: **`PublicStatsSnapshotDto`** — counts only (users, faces, pages, friendships, pending friend requests, messages, albums, blogs, reels, stories, story views, wall tickets, face chat rooms/messages).

### 3.2 `IPlatformStatsQueryService`

- **`GetOperatorDashboardSummaryAsync`** — full **`AdminDashboardSummaryDto`** (same shape as previous inline `StatsController` body).
- **`GetPublicSnapshotAsync`** — builds **`PublicStatsSnapshotDto`**.

### 3.3 gRPC (`Protos/health.proto`)

- **`GenerateRequest`**: optional **`stats_context_json`**.
- **`FetchPublicStatsRequest/Response`**: **`absolute_url`** → **`json_body`** or **`error`**.
- **`OperatorStatsChatRequest`** → **`GenerateResponse`**: optional live fetch + composed prompt.

### 3.4 `IAiGrpcService`

- **`GenerateAsync(..., statsContextJson?, ...)`** — sets protobuf field when non-empty.
- **`OperatorStatsChatAsync(...)`** — unary RPC wrapper with retry/channel invalidation consistent with existing **`Generate`** / **`ReviewContent`**.

### 3.5 Configuration

- **`AiStats:PublicSnapshotAbsoluteUrl`** — required for **`live`** server-side path; example in **`appsettings.Development.json`** using **HTTP** on port **8000** to avoid local TLS friction for the Python worker.

---

## 4. Python (`many_faces_ai`) design notes

- **`Generate`**: If **`stats_context_json`** is set, prepend a short English banner + JSON + separator before the conversational prompt.
- **`FetchPublicStats`**: Reject non-http(s) URLs; for **localhost / 127.0.0.1 / ::1** HTTPS, allow insecure TLS for dev self-signed certs only. **Production URL allow-list / SSRF hardening** if AI gRPC is reachable: [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) **AI-3** (not re-specified here).
- **`OperatorStatsChat`**: Optionally **`FetchPublicStats`**, then build **`GenerateRequest`** with **`stats_context_json`** + final **`User:` / `AI:`** prompt tail.
- **Regeneration:** `proto/health_pb2*.py` are **gitignored**; run **`scripts/generate_proto.sh`** (uses **`.venv/bin/python`** when present).

---

## 5. Admin (`many_faces_admin`) design notes

- **`src/utils/adminAiStatsSettings.ts`** — get/set **`off` \| `inline` \| `live`**.
- **`SettingsPage`** — radio UI + save to **`localStorage`**.
- **`ChatPage`** — invokes **`SendToAiWithOperatorStats`** with current mode (read per send so changes apply without reload).
- **`DashboardAiStatsPanel`** — shows mode + optional **`usePublicStatsSnapshot`** via **`absolutePublicFaceUrl('/api/Stats/public')`** (not admin-prefixed fetch).
- **`faceApiRouting.ts`** — **`scopePathForPublicFace`**, **`absolutePublicFaceUrl`**.
- **Routes:** `settings` id in **`useAdminRoutePaths`**, **`routeTranslations`**, **`AppRoutes`**, **`lazyAdminPages`**.
- **i18n:** `en`, `sk`, `cz` for dashboard AI strip + settings + `routes.settings`.

---

## 6. Tests and verification

- **Backend:** `StatsControllerTests` — operator **`GET /api/Stats`** / **`timeseries`**; **`GET /api/Stats/public`** on **`public`** face without JWT; **401** on **`admin`** face without JWT; **400** bare `/api/Stats/public` (no face prefix); **200** with operator JWT on **`public`** face; public JSON **numeric** keys only and **no** operator-only fields (`oauthClientsCount`, etc.); **`FakeAiGrpcService`** updated for **`IAiGrpcService`**.
- **Admin:** `yarn tsc --noEmit`; Vitest — **`adminAiStatsSettings.test.ts`**, **`faceApiRouting.publicFace.test.ts`**, **`dashboardChartData.test.ts`**.
- **AI:** `test_server.py` — **`Generate`** + **`stats_context_json`** (mocked **`AIModelService`**), whitespace-only stats, **`FetchPublicStats`** invalid schemes, **`OperatorStatsChat`** validation and unreachable live URL.

---

## 7. Implementation record (all tasks done)

Use this section as the **canonical “what shipped”** list for audits. Every line is **`[x]`** by design for this engagement.

- [x] Add **`PublicStatsSnapshotDto`** and **`IPlatformStatsQueryService` / `PlatformStatsQueryService`** (operator summary + public snapshot).
- [x] Refactor **`StatsController`** to use the service for **`GET /api/Stats`**; keep **`GET /api/Stats/timeseries`** on controller using **`ApplicationDbContext`**.
- [x] Add **`GET /api/Stats/public`** with **`[AllowAnonymous]`** and document **`/public/...`** face requirement.
- [x] Register **`IPlatformStatsQueryService`** in **`Program.cs`**.
- [x] Extend **`health.proto`** (backend + AI copies): **`stats_context_json`**, **`FetchPublicStats`**, **`OperatorStatsChat`**; regenerate C# client via **`dotnet build`**.
- [x] Extend **`IAiGrpcService` / `AiGrpcService`** (`Generate` optional JSON context + **`OperatorStatsChatAsync`**).
- [x] Add **`ChatHub.SendToAiWithOperatorStats`** (operator ACL, rate limit, **`off` / `inline` / `live`** branches, config guard for live URL).
- [x] Add **`AiStats`** section to **`appsettings.json`** and development example URL.
- [x] Implement Python **`Generate`** context prefix, **`FetchPublicStats`**, **`OperatorStatsChat`**; harden **`generate_proto.sh`** for local **`grpc_tools`** via **`.venv`**.
- [x] **`many_faces_admin`**: settings page + SCSS; **`adminAiStatsSettings`**; **`usePublicStatsSnapshot`** + **`PublicStatsSnapshot`** type; **`DashboardAiStatsPanel`**; wire **`DashboardPage`**; **`ChatPage`** hub invoke; **`faceApiRouting`** public-face absolute URL helpers; sidebar links; routes + i18n (`en`/`sk`/`cz`).
- [x] Add integration tests for **`GET /api/Stats/public`**: **401** on admin face without JWT; **400** bare path; **200** with operator JWT on public face; numeric field set; no operator-only JSON keys.
- [x] Add **`many_faces_ai`** pytest classes **`TestGenerateWithStatsContext`**, **`TestFetchPublicStats`**, **`TestOperatorStatsChat`** in **`test_server.py`**.
- [x] Add **`many_faces_admin`** Vitest **`adminAiStatsSettings.test.ts`** and **`faceApiRouting.publicFace.test.ts`**.
- [x] Expand **`docs/guides/admin-dashboard-metrics.md`**, monorepo **`README.md`** (mermaid), submodule READMEs (**backend**, **admin**, **AI**), and refresh **`docs/prompts/admin-ai-public-stats-operator-chat-*.md`** test sections.
- [x] Document the work in **`docs/prompts/admin-ai-public-stats-operator-chat-implementation-checklist.md`** and register the prompt in **`docs/prompts/README.md`**.

---

## 8. Follow-ups (optional, not done here)

- [ ] E2E test: SignalR **`SendToAiWithOperatorStats`** with a fake **`IAiGrpcService`** (hub test harness if the repo adds one).
- [ ] Rate-limit **`GET /api/Stats/public`** separately if abuse becomes a concern.
- [ ] Docker-compose template env for **`AiStats__PublicSnapshotAbsoluteUrl`** pointing at the internal **`public`** face URL.
