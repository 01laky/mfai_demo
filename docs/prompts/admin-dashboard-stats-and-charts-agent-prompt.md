# Admin dashboard — statistics, charts, and data coverage — Agent prompt

## 1. Mission

Turn the **`many_faces_admin`** dashboard from a **minimal KPI strip** (three numbers + one placeholder) into a **credible operator console** that reflects **as much of the BeDemo domain as is practical**: entity counts, status breakdowns where enums exist, **optional time-bucketed series** for growth/activity, and a **super-admin moderation snapshot** wired to the **existing** moderation metrics API.

**Primary repositories**

| Repo                 | Scope                                                                 |
| -------------------- | --------------------------------------------------------------------- |
| `many_faces_backend` | Expand or replace dashboard data APIs (`StatsController` and/or new). |
| `many_faces_admin`   | `DashboardPage`, hooks, charts, i18n, navigation polish, tests.       |

**Success criteria (acceptance)**

- [ ] **Backend** returns a **single consolidated JSON** document (or two coordinated endpoints: **summary** + **timeseries**) suitable for the admin home page without dozens of sequential HTTP calls from the browser.
- [ ] **Authorization** for expanded metrics is **at least as strict** as other admin-wide operations (see **§4**); no accidental leakage of platform-wide counts to non-operator JWTs.
- [ ] **Admin UI** shows **real counts** for **Faces** (today hard-coded `—`), **Pages**, and other agreed KPIs; **charts** render from API data with **empty-state** and **error-state** UX.
- [ ] **Super-admin** users see a **compact moderation health widget** sourced from **`GET /api/contentmoderation/metrics`** (reuse `unwrapModerationMetricsResponse` / existing hook patterns — do not duplicate server-side moderation math in `StatsController`).
- [ ] **OpenAPI** regenerated where applicable; admin client types updated (`yarn generate:api` in `many_faces_admin` if the project uses generated services for `Stats`).
- [ ] **Tests**: new **API tests** for the expanded stats contract; **frontend unit tests** for parsing + presentational components (no render-heavy full dashboard unless already the house style).
- [ ] **i18n**: all new user-visible strings in **`many_faces_admin`** locale files (`en`, `sk`, `cz` minimum parity with existing pages).

**Explicit non-goals (first delivery)**

- Real-time WebSocket dashboards, geographic maps, or per-second live traffic.
- **Data warehouse** / OLAP / BigQuery-style retention analytics.
- Rewriting **`ContentModerationPage`** — only **surface a subset** of its metrics on the dashboard with deep links.
- **Mobile** (`many_faces_portal` / `many_faces_mobile`) — out of scope unless a shared type is trivially reused.

---

## 2. Current state (baseline for the agent)

### 2.1 Backend — `StatsController`

**File:** `many_faces_backend/BeDemo.Api/Controllers/StatsController.cs`

- **Route:** `GET /api/Stats` (ASP.NET Core default casing: `Stats` controller name).
- **Auth:** `[Authorize]` only — **any authenticated user** can call it today.
- **Payload today:** anonymous object with `usersCount`, `friendRequestsCount` (**Pending only**), `messagesCount` (all rows in `Messages`).

### 2.2 Admin — `DashboardPage`

**File:** `many_faces_admin/src/pages/DashboardPage.tsx`

- Uses `useStats()` → **`useStatsApi.ts`** → `GET /api/Stats`.
- **Faces card** shows **`—`** (not wired to API).
- **No charts**; quick actions cover users and faces only.

### 2.3 Admin — navigation shell

**Files:** `many_faces_admin/src/components/AdminLayout.tsx`, `Sidebar.tsx`

- Primary nav: dashboard, users, faces, chat; **moderation** nav item only when **`isSuperAdminFromToken(token)`**.
- **Pages** CRUD routes exist (`CreatePagePage`, `EditPagePage`, `PageDetailPage` in `lazyAdminPages.tsx`) but **Pages are not first-class in the main sidebar/header nav** — operators discover them indirectly.
- **Routing reality (do not assume a global pages index):** In `many_faces_admin/src/routes/AppRoutes.tsx`, pages are reached as **`/:lang/pages/:id`**, **`/:lang/pages/:id/edit`**, and **`/:lang/{faces}/:faceId/pages/create`** (under the localized **faces** path segments). There is **no** dedicated **`/pages` list** route today. IA options: (1) dashboard copy + deep link to **Faces** explaining per-face page creation, (2) add a **new** admin “all pages” list backed by a new **`GET /api/admin/pages-summary`** (or extend an existing controller) — only if product explicitly wants it; document the choice in the PR.

### 2.4 Existing moderation metrics (do not reimplement)

**Backend:** `many_faces_backend/BeDemo.Api/Controllers/ContentModerationController.cs` — **`GET /api/contentmoderation/metrics`** (wrapped `{ metrics, alerts }` vs flat — already handled in admin).

**Admin:** `many_faces_admin/src/hooks/api/useContentModerationApi.ts` — `unwrapModerationMetricsResponse`, `useModerationMetrics`, types `ModerationMetrics`, `ModerationAlert`, etc.

**UI:** `many_faces_admin/src/pages/ContentModerationPage.tsx` — full queue; dashboard only needs a **summary card row**.

### 2.5 Domain surface in EF (`ApplicationDbContext`)

The dashboard spec should **map KPIs to these `DbSet`s** (names are authoritative; adjust if refactors rename entities):

| Area            | DbSets (representative) |
| --------------- | ----------------------- |
| Identity/users | `Users` (Identity), `UserProfiles`, `UserFaceProfiles`, `UserFaceRoles`, `UserRoles` |
| Social graph    | `FriendRequests`, `Friendships`, `UserFollows`, `UserBlocks` |
| Messaging       | `Messages` (`SentAt`, `IsMessageRequest`, `MessageRequestStatus`) |
| Faces / CMS     | `Faces`, `Pages`, `PageTypes`, `PageRouteTranslations`, `PageComponents`, `ComponentTypes`, `DisplayModes` |
| User content    | `Albums`, `Blogs`, `Reels`, `Stories` (+ related comments, likes, join tables, `StoryViews`) |
| Chat            | `FaceChatRooms`, `FaceChatRoomMembers`, `FaceChatRoomMessages`, `FaceChatRoomJoinRequests` |
| Wall            | `FaceWallTickets`, `FaceWallTicketComments`, `FaceWallTicketLikes` |
| Profiles extras | `UserFaceProfileLikes`, `UserFaceProfileComments`, `UserFaceProfileReviews` |
| Notifications   | `Notifications` |
| Moderation / AI | `AiReviewJobs`, `ContentModerationEvents` (+ content approval fields on Album/Blog/Reel — already aggregated via moderation service) |
| OAuth           | `OAuthClients`, `OAuthRefreshTokens` |

**Agent task:** when adding a KPI, **cite the exact entity + property** (e.g. `FriendRequest.Status`, `Message.SentAt`) in backend XML doc comments or short inline comments so future refactors stay traceable.

---

## 3. Authorization and roles

### 3.1 Problem

`StatsController` is currently **`[Authorize]`** without **`IAccessEvaluator`**. Expanded stats (faces, pages, global wall counts, OAuth clients) are **sensitive** in multi-tenant or partially-scoped deployments.

### 3.2 Required alignment

- [ ] **Decide and implement** one policy (document in PR description):

  **Policy A (recommended):** Restrict **expanded** `GET /api/Stats` (or replacement route) to the **same capability** used for **platform-wide user management** — mirror **`UsersController`** pattern: `IAccessEvaluator` / **`CanManageAllFaces(User)`** (or stricter if product dictates). Return **`403 Forbidden`** when the caller lacks scope.

  **Policy B (legacy compatibility):** Keep the **existing three-field** payload for broad `[Authorize]` but add **`GET /api/admin/dashboard-summary`** with the expanded operator metrics. *Only choose B if breaking existing non-admin API clients is unacceptable — verify callers via repo-wide search.*

- [ ] **Super-admin-only** UI blocks (moderation widget) remain **client-gated** by `isSuperAdminFromToken` **and** server already forbids non-super-admin on moderation routes — **no change** to moderation authorization rules except fixing accidental client calls (handle `403` gracefully).

---

## 4. API design

### 4.1 Naming and versioning

- **Preferred:** extend **`StatsController`** with a **versioned DTO** returned from `GET /api/Stats` **after** authorization hardening, **or** introduce `AdminDashboardController` under `api/admin/...` if Policy B is chosen.
- **JSON naming:** use **camelCase** in responses to match existing anonymous object and typical TS clients (`usersCount` style).

### 4.2 Suggested response shape — `DashboardSummary` (illustrative)

The agent should **freeze a C# record/DTO** in `BeDemo.Api` (e.g. `Models/Dtos/AdminDashboardSummaryDto.cs`) instead of anonymous objects — **Swagger/OpenAPI** must list every field.

**Tier 1 — counts (required MVP)**

| Field | Source idea |
| ----- | ----------- |
| `usersCount` | `_context.Users.CountAsync()` |
| `facesCount` | `_context.Faces.CountAsync()` |
| `pagesCount` | `_context.Pages.CountAsync()` |
| `pageComponentsCount` | `_context.PageComponents.CountAsync()` |
| `friendRequestsPendingCount` | existing filter `Status == Pending` |
| `friendRequestsAcceptedCount` / `rejectedCount` | optional breakdown |
| `friendshipsCount` | `Friendships` count |
| `messagesCount` | all `Messages` |
| `messagesPendingRequestCount` | `IsMessageRequest && MessageRequestStatus == Pending` (nullable handling per model) |
| `notificationsCount` | total `Notifications` rows; **do not** promise `unreadCount` unless the **`Notification`** model gains a read flag (today it has `CreatedAt` / `Type` only — verify schema before exposing “unread”). |
| `albumsCount`, `blogsCount`, `reelsCount`, `storiesCount` | simple totals |
| `storyViewsCount` | `StoryViews` if table is populated in demo |
| `faceChatRoomsCount`, `faceChatRoomMessagesCount`, `faceChatRoomJoinRequestsPendingCount` | as feasible |
| `faceWallTicketsCount` | global; plus **`byStatus`** breakdown keyed by **`FaceWallTicketStatus`** (`FaceWallTicket.Status`) |
| `userFaceProfilesCount` | optional |
| `oauthClientsCount` | **only** if deemed non-sensitive for operators |

**Tier 2 — charts / time series (recommended phase 2)**

- [ ] Add **`GET /api/Stats/timeseries`** (or `GET /api/admin/dashboard-timeseries`) with query parameters:

  - `metric` — enum string: e.g. `users` (bucket by **`ApplicationUser.CreatedAt`** UTC), `messages` (**`Message.SentAt`**), `stories`, `blogs`, `reels`, `albums`, `friendRequests` (**`FriendRequest.CreatedAt`**), `wallTickets` (**`FaceWallTicket.CreatedAt`**), …
  - `fromUtc`, `toUtc` — ISO-8601; **clamp** max window (e.g. 366 days) server-side.
  - `bucket` — `day` | `week` (default `day`).

- [ ] Response: `{ "buckets": [ { "periodStartUtc": "...", "count": 123 } ] }`.

- [ ] Implementation options (pick one, justify in PR):

  - **EF + `GroupBy`** on `DateTime` truncated in LINQ (watch **server-side translation** for PostgreSQL).
  - **Raw SQL** via `FromSql` / ADO for `date_trunc('day', ...)` — often clearer for perf.

**Tier 3 — “top N” lists (optional)**

- [ ] Top faces by `UserFaceProfiles` count, top faces by open wall tickets — **paginated** sub-endpoints or capped arrays (e.g. max 10) to avoid huge JSON.

### 4.3 Performance and reliability

- [ ] Use **`AsNoTracking()`** for read-only aggregates.
- [ ] Prefer **`Task.WhenAll`** for independent counts **or** a **single SQL batch** if round-trips dominate — measure on seeded dev DB.
- [ ] Add **cancellation tokens** to all async EF calls (`CancellationToken` parameter on action methods).
- [ ] Consider **response caching** (`ResponseCache` or short in-memory cache) **only** if verified safe under multi-instance (otherwise skip for MVP).

### 4.4 Errors

- [ ] Consistent problem details / `{ "error": "..." }` shape matching other controllers on validation (bad date range).

### 4.5 Security and abuse (recommended prompt extensions)

- [ ] **Rate limiting / cost:** Aggregates + timeseries over wide windows can be **CPU/IO heavy**. Consider ASP.NET **rate limiting** middleware (per user/IP) on `Stats` / timeseries routes, or cap concurrent requests — document limits in Swagger description.
- [ ] **ETag / `If-None-Match`:** Optional for the large summary DTO so dashboards polling on a timer do not re-download unchanged JSON (implement only if quick win; otherwise skip for MVP).
- [ ] **Audit log (optional):** One structured log line per successful operator stats read (`UserId`, duration ms, row counts hash) — helps detect scraping; avoid logging full response bodies.

---

## 5. Frontend design (`many_faces_admin`)

### 5.1 Data fetching

- [ ] Replace / extend **`useStatsApi.ts`** with typed models matching DTOs (manual `__request` is acceptable if that is the existing pattern for non-generated endpoints).
- [ ] If OpenAPI generation includes `StatsService`, **prefer generated client** after regenerating spec.
- [ ] Use **TanStack Query** (`useQuery`) with a **stable `queryKey`** including any date-range params for timeseries.
- [ ] **Super-admin widget:** `useModerationMetrics()` (or direct `fetch` wrapper) with **disabled query** when `!isSuperAdminFromToken(token)` to avoid avoidable `403` noise.

### 5.2 Layout and UX

- [ ] **Above the fold:** KPI cards in a **responsive grid** (reuse Bootstrap grid already used on `DashboardPage`).
- [ ] **Charts section:** at least **two** charts in MVP:

  1. **Stacked or multi-line** — user registrations + messages (or stories) over last 30 days.
  2. **Bar or donut** — content mix (`albums` / `blogs` / `reels` / `stories`) **or** friend-request status breakdown.

- [ ] **Empty state:** when all counts are zero (fresh DB), show a friendly explanation, not broken charts.
- [ ] **Loading skeletons** or spinners consistent with other admin pages.
- [ ] **Deep links:** each KPI card or chart footnote links to the relevant admin route (`/users`, `/faces`, `/chat`, `/moderation`, face wall tickets route pattern).

### 5.3 Charting library

- [ ] Add **one** supported chart dependency (project decision in PR):

  - **Recharts** (React-friendly, common in SPAs), or
  - **Chart.js** via `react-chartjs-2`.

- [ ] **Bundle impact:** verify Vite chunking; lazy-load chart module if easy (`React.lazy` around chart section).

### 5.4 Navigation / information architecture

- [ ] Because there is **no** global pages list route (**§2.3**), **do not** add a dead nav link to **`/pages`**. Prefer: **dashboard quick action** “Manage pages” → **`Faces`** list (or first face) + short i18n hint (“Create or edit pages under each face”), **or** implement the new **all-pages** admin screen + API if product chooses that scope.
- [ ] Keep **`useAdminRoutePaths`** / `routeTranslations.ts` in sync if new first-class routes are introduced.

### 5.5 Styling

- [ ] Extend **`DashboardPage.scss`**; follow existing **Solarized-friendly** / admin palette variables if present; **no inline magic colors** except CSS variables already used for accent.

### 5.6 Accessibility

- [ ] Charts must have **`aria-label` / `title`** summarizing the dataset; **no color-only** status semantics.

---

## 6. Internationalization

**Files:** `many_faces_admin/src/i18n/locales/en.json`, `sk.json`, `cz.json` (and any others registered in `i18n/config.ts`).

- [ ] Add keys under e.g. `pages.dashboard.stats.*`, `pages.dashboard.charts.*`, `pages.dashboard.moderationWidget.*`.
- [ ] Replace hard-coded emoji labels where product prefers translated text (optional — if emojis stay, still translate adjacent strings).

---

## 7. Testing matrix

### 7.1 Backend (`BeDemo.Api.Tests`)

- [ ] **Happy path:** authorized operator receives expected **non-negative** integers; seeded integration DB yields **non-zero** counts where `DatabaseSeeder` guarantees data.
- [ ] **Forbidden:** non-operator token cannot read expanded stats (per **§3**).
- [ ] **Timeseries:** invalid `fromUtc > toUtc` → **400**; range beyond clamp → **400** or silently clamp — **document chosen behavior**.
- [ ] **Regression:** existing consumers of old `GET /api/Stats` still deserialize (if shape is superset-only, TS optional fields / JSON extra properties are fine).

### 7.2 Frontend (`many_faces_admin`)

- [ ] Unit tests for **DTO → chart data** mappers (pure functions).
- [ ] Optional: **RTL** test that dashboard renders KPI labels from i18n keys (lightweight snapshot discouraged — prefer explicit text queries).

---

## 8. OpenAPI and client generation

- [ ] Update Swagger annotations / DTO references so **`openapi.json`** in admin (or generated fetch from running API) includes new schemas.
- [ ] Run **`yarn generate:api`** (or documented equivalent) and commit regenerated files **only** if the repo standard requires it for `Stats`.

---

## 9. Documentation (minimal)

- [ ] **`many_faces_admin/README.md`** — short subsection “Dashboard metrics” linking to backend endpoint and required role.
- [ ] **Do not** add large new `docs/guides/*` unless the user explicitly asks; a PR description may carry the detailed rationale.

---

## 10. Master task checklist (copy to PR / issue)

**Phase 0 — Discovery**

- [ ] Repo-wide search: all callers of **`/api/Stats`** (admin, scripts, tests, **portal/mobile** if any indirect use).
- [ ] Confirm **production** expectations for auth on stats (sync with `IAccessEvaluator` implementation).
- [ ] Note dual dashboard entry: **`/:lang` index** and **`dashboardPaths`** both render `DashboardPage` — avoid duplicate `useQuery` mounts causing double fetch unless `staleTime` / shared layout makes it harmless; document chosen pattern.

**Phase 1 — Backend summary counts**

- [ ] Introduce **DTO + XML docs** for expanded stats.
- [ ] Implement counts listed in **§4.2 Tier 1** (subset acceptable in first PR if split, but **must** include **`facesCount`** and **`pagesCount`**).
- [ ] Enforce **§3** authorization on expanded data.
- [ ] Add **`BeDemo.Api.Tests`** coverage per **§7.1**.

**Phase 2 — Admin dashboard UI (MVP)**

- [ ] Wire **Faces** and **Pages** cards to live numbers.
- [ ] Add **at least one** non-trivial chart using **Tier 1** breakdowns **without** timeseries if phase 3 slips.
- [ ] Super-admin: **moderation metrics widget** + link to `/moderation`.
- [ ] i18n + SCSS + empty/error states.

**Phase 3 — Timeseries API + charts**

- [ ] Implement **§4.2 Tier 2** endpoint + tests.
- [ ] Add second chart tied to timeseries; date range control (preset: 7 / 30 / 90 days).

**Phase 4 — Navigation / wall / polish**

- [ ] Pages discoverability (**§5.4**).
- [ ] Optional: global **wall ticket** summary table or top-N faces by tickets.
- [ ] Performance pass on dev DB (log slow queries; add indexes **only** if justified with migration).

**Phase 5 — Release hygiene**

- [ ] Regenerate OpenAPI / admin API client if applicable.
- [ ] Run **`dotnet test`** for backend and **`yarn test`** / **`yarn lint`** for admin in CI-equivalent commands locally.

---

## 11. Handoff notes for implementers

- **Do not duplicate** moderation aggregation in `StatsController` — call existing services only if you extract shared code **deliberately** into a neutral `IPlatformMetrics` service; otherwise keep moderation on `ContentModerationController`.
- **Keep commits focused** — backend DTO + auth + tests can merge before the full chart UI if checks pass.
- **Submodules:** if work spans `many_faces_main` parent pointers, follow normal submodule PR discipline (separate PRs per repo or documented bump).

---

## 12. Appendix — reference files (non-exhaustive)

| Path | Why |
| ---- | --- |
| `many_faces_backend/BeDemo.Api/Controllers/StatsController.cs` | Current stats endpoint |
| `many_faces_backend/BeDemo.Api/Data/ApplicationDbContext.cs` | DbSets inventory |
| `many_faces_backend/BeDemo.Api/Controllers/UsersController.cs` | `IAccessEvaluator` / operator patterns |
| `many_faces_backend/BeDemo.Api/Controllers/ContentModerationController.cs` | Moderation metrics source of truth |
| `many_faces_admin/src/pages/DashboardPage.tsx` | Dashboard UI baseline |
| `many_faces_admin/src/hooks/api/useStatsApi.ts` | Client fetch baseline |
| `many_faces_admin/src/hooks/api/useContentModerationApi.ts` | Metrics client + unwrap helper |
| `many_faces_admin/src/components/AdminLayout.tsx` | Nav items |
| `many_faces_admin/src/utils/contentModeration.ts` | `isSuperAdminFromToken` |

---

_End of prompt — leave `[ ]` unchecked in this canonical file per `docs/prompts/README.md` conventions._
