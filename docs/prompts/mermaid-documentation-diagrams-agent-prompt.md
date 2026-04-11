# Agent prompt: exhaustive Mermaid diagrams for `docs/` (copy entire file into AI chat)

**Completed (full diagram pass + checklist in repo):** `2026-04-10T22:23:28Z` (UTC).

**Audience:** Autonomous coding agent (Cursor, Codex, etc.). **Not** human readers.  
**Goal:** Insert **correct, detailed, visually coherent** Mermaid diagrams into the monorepo documentation under `docs/` (and update `docs/prompts/README.md` index only if you add new prompt files—do not bloat unrelated files).  
**Language of diagram labels:** **English** (match the rest of `docs/`).  
**Constraint:** Preserve existing prose; **add** diagrams in sensible places (usually after the section heading that introduces the concept, or after a table that the diagram summarizes). Do **not** remove documentation content unless a diagram fully replaces a redundant bullet list **and** you confirm no information loss.

---

## 0. Your mission (execute in order)

1. Read the target markdown file from disk **before** editing (content drifts).
2. For **each diagram specification** below, implement **one** fenced block (unless the spec explicitly allows two related diagrams, e.g. D-CHAT-01):

   ````markdown
   ```mermaid
   ... valid mermaid source ...
   ```
   ````

3. Prefer **one diagram per major subsection** where specified. If a section would become crowded: **prefer a new markdown subsection** `### Diagram: …` over HTML `<details>`—GitHub/clients differ on sanitizing `<details>`. Use `<details>` only when the **same file already** uses that pattern consistently.
4. After edits, verify Mermaid renders on **GitHub-flavored Markdown** (avoid exotic syntax; align with [Mermaid docs](https://mermaid.js.org/)).
5. Use **`flowchart TB`** or **`flowchart LR`** for architecture; **`sequenceDiagram`** for time-ordered protocols; **`stateDiagram-v2`** for lifecycles; **`erDiagram`** for entities; **`graph TB`** only if equivalent to flowchart (prefer `flowchart`).
6. **Styling (`classDef` + `class`):** Apply primarily to **`flowchart`** / **`graph`** nodes. For **`sequenceDiagram`**, participant styling is inconsistent across renderers—**do not rely on colors** for meaning there. Instead use clear `participant` names, **`Note over A,B:`** / **`Note right of A:`** blocks, and **text prefixes** on messages where helpful (`API:`, `DB:`).
7. **Sequence diagrams — avoid ugly self-calls:** Do **not** use `Middleware->>Middleware:` for internal steps. Use **`Note over OAuth2Middleware: validates client_id / client_secret`** (or equivalent) for intra-component validation.
8. **Sequence diagrams — response path:** Showing **`Service-->>Client`** for the token response is acceptable as a **logical** summary. Alternatively draw the return through **`OAuth2Controller` → `Client`** for a closer HTTP shape. Add a one-line prose note under the diagram if you abbreviate the stack.
9. **Label length:** Keep text on **arrows and small nodes** to **~40 characters** or less; put nuance in the **markdown paragraph below** the diagram.
10. **Subgraphs:** Use `subgraph id["Human-readable title"]` for layers: Transport, Middleware, Application, Data. Subgraph IDs follow the same rules as node IDs (alphanumeric + underscore).
11. **Long node text in flowcharts:** Prefer short node labels + prose; `<br/>` in node text is allowed in many renderers but test rendering.
12. **Node IDs:** Alphanumeric + underscore only (no spaces).
13. **Mindmap:** GitHub Mermaid supports `mindmap` in recent versions; if a renderer fails, fall back to **`flowchart TB`** with grouped subgraphs (as already specified for D-ACL-01).
14. **Styling palette for flowcharts** (WCAG-friendly, distinguishable—use with `classDef` where applicable):
    - `clientFill:#e3f2fd,stroke:#1565c0`
    - `apiFill:#fff3e0,stroke:#ef6c00`
    - `dbFill:#e8f5e9,stroke:#2e7d32`
    - `queueFill:#fce4ec,stroke:#c2185b`
    - `extFill:#f3e5f5,stroke:#7b1fa2`
15. **Verify names against code before finalizing:** **`grep` / read `be_demo/BeDemo.Api`** for **`MapHub`**, hub **class names** (e.g. `ChatHub`, `MessengerHub`, `ChatRoomHub`), and **URL path segments** (`/hubs/...`). Diagram labels must match **current** code, not guesses.
16. **`docs/guides/security-crypto-sockets.md`:** The **“Current baseline”** table may lag behind code. Before any diagram that states “current” behaviour, **cross-check** `Program.cs`, `OAuth2Service`, `JwtBearerOptions`, and refresh-token handling. Prefer labeling diagrams **“target architecture”** vs **verified current** explicitly.
17. **Validation tooling:** If **`mmdc`** (Mermaid CLI) or IDE Mermaid preview is available, validate a **sample** of diagrams. At minimum verify each **mermaid** fenced block has a **closing fence** (pair-count sanity check).
18. **Duplication / single source of truth:** **`D-COMP-ACL-01`** must **not** fully duplicate **`D-ACL-03`**—use a **small** high-level diagram plus a **markdown link** to the section in `guides/acl-and-capabilities.md` that contains the canonical file-flow diagram (anchor or heading text).
19. **Every diagram ID in §2 is REQUIRED:** implement each in its target file **or** report **`skipped`** with reason (e.g. missing path). **No** diagram may be skipped as “low priority” or “optional”.

---

## 1. Repository context (do not skip—ground truth for labels)

- Monorepo root: `_mfai_demo`.
- Backend: `be_demo/BeDemo.Api` — ASP.NET Core, OAuth2 (`OAuth2Controller`, `OAuth2Middleware`, `OAuth2Service`), JWT (`ECDSAKeyService`), refresh store (`OAuthRefreshTokenStore`), face routing (`RoutingMiddleware`), SignalR hubs (`ChatHub`, `MessengerHub`, chat room hub), EF Core, PostgreSQL.
- Frontends: `fe_demo`, `admin_demo` — Vite/React, axios interceptors for `/{face}/` prefix, `localStorage` keys `auth_token`, `auth_refresh_token`, `auth_user`, JWT utils, React Query, SignalR clients.
- Job queue: Redis lists / ZSET (`bedemo:jobs:ready`, `bedemo:jobs:delayed`), worker `RedisJobWorkerService`, job types e.g. `wall.ticket-delete`, `chatroom.idle-check`, `reel.postprocess`.
- Submodules: `be_demo`, `fe_demo`, `admin_demo`, `ai_demo`, `db_demo`, `redis_demo`, `logger_demo`.
- When docs disagree with code, **prefer code** and update diagram labels to match code; optionally file a separate doc fix (out of scope unless asked).

---

## 2. Complete diagram inventory

### 2.1 All diagrams are REQUIRED

- **Every `### D-*` specification below** must be satisfied by **one or more** valid **` ```mermaid `** fenced blocks in the named file **or** by a **`skipped`** row in the final report with a concrete reason (missing file, merge conflict, etc.). A spec that explicitly allows multiple blocks (e.g. **D-CHAT-01**) is fulfilled only when **all** of those blocks are present (or the whole ID is `skipped` with reason).
- **Do not** treat any diagram as optional or “nice to have.” Formerly optional IDs (`D-README-HUB-01`, `D-REDIS-SUB-02`, `D-README-READMES-01`, `D-BOILER-01`) are **required** like all others.

### 2.2 Recommended execution order (reduces rework and contradictions)

1. **`docs/guides/authentication-and-sessions.md`** and **`docs/guides/acl-and-capabilities.md`** (shared authz/token story).
2. **Remaining `docs/guides/*.md`** (api-oauth, chat-rooms, wall-tickets, security-crypto-sockets, dev-https, development, git-submodules, husky-setup, boilerplate-checklist, proposal-mfai-demo-state).
3. **`docs/readmes/*.md`** (fe/admin overview, redis-subrepo, `readmes/README`).
4. **`docs/prompts/super-admin-api.md`**, **`docs/components/acl-capabilities-module.md`**.
5. **`docs/STRUCTURE.md`**, **`docs/README.md`** (hub).

### 2.3 File-specific rules

- **`docs/guides/boilerplate-checklist.md`:** **`D-BOILER-01` is REQUIRED.** If section headings are sparse, build a **`flowchart TB`** from top-level bullets / checklist groups anyway (aggregate items into 5–12 nodes); do **not** skip.
- **`docs/guides/husky-setup.md`:** **`D-HUSKY-01` is REQUIRED**; read the file first and draw **only** hooks the document describes (do not invent `pre-commit` if the doc only mentions `commit-msg`).

---

### D-STRUCT-01 — `docs/STRUCTURE.md`

- **Placement:** Immediately after the markdown table under `# Layout of docs/` (diagram visualizes the same table).
- **Type:** `flowchart TB`.
- **Content specification:**
  - Four nodes: `guides`, `components`, `prompts`, `readmes`.
  - One node `hub["docs/README.md hub"]` at top center.
  - Edges: each folder → `hub` **or** `hub` → each folder (pick downward tree: `hub` → four children).
  - Each folder node: multiline label with **role** exactly paraphrased from STRUCTURE (long-form reference; catalog; AI prompts; README index + overviews).
  - One node `root_readme["Root ../README.md short entry"]` → `hub`.
  - `classDef` folder vs hub vs root.
- **Detail:** subgraph `subgraph docs["docs/"]` wrapping folder nodes + hub.

---

### D-README-HUB-01 — `docs/README.md`

- **Placement:** After first paragraph, before `---`.
- **Type:** `flowchart LR`.
- **Content:** `User` → `docs/README` → branches to `guides` / `components` / `prompts` / `readmes` with one-line “what you find there”.
- **Style:** compact, single row of subgraphs.

---

### D-AUTH-01 — `docs/guides/authentication-and-sessions.md`

- **Placement:** After `## 1. Why this exists (mental model)` table (diagram summarizes concepts).
- **Type:** `flowchart TB`.
- **Nodes:** `AccessToken[JWT access token]`, `Exp[exp claim]`, `RememberMe[rememberMe flag]`, `Refresh[Opaque refresh token]`, `Storage[Browser localStorage]`, `ApiVal[API JWT validation]`.
- **Edges:** `RememberMe` → influences `AccessToken` lifetime; `AccessToken` has `Exp`; `Refresh` stored server-side hashed; client stores `AccessToken`+`Refresh` in `Storage`; requests use `AccessToken` → `ApiVal`; expired → 401.
- **Note in diagram:** small text node “Capabilities / face roles read from DB, not embedded in JWT (see §6)”.

---

### D-AUTH-02 — `docs/guides/authentication-and-sessions.md`

- **Placement:** After `### 2.1 Endpoint: POST /api/oauth2/token` bullet list.
- **Type:** `sequenceDiagram`.
- **Participants:** `Client`, `OAuth2Middleware`, `OAuth2Controller`, `OAuth2Service`, `UserStore` (Identity), `RefreshStore` (`OAuthRefreshTokenStore`), `JwtSigner` (ECDSA / token creation).
- **Messages (happy path password):**
  - Client→Middleware: POST JSON grant
  - **Note over OAuth2Middleware:** validates `client_id` / `client_secret` (no self-arrow on Middleware)
  - Middleware→Controller: forward request
  - Controller→Service: GenerateTokenAsync(password)
  - Service→UserStore: validate credentials
  - Service→RefreshStore: persist hashed refresh
  - Service→JwtSigner: build access JWT (rememberMe selects lifetime)
  - **Either** `Service-->>Client` **(logical response)** **or** `Service-->>Controller-->>Middleware-->>Client` with a prose note that the diagram may abbreviate the HTTP stack
- **Alt block:** `refresh_token` grant: validate opaque token, rotate (single-use), reject if access JWT presented as refresh.
- **Notes:** middleware runs before controller; use `Note` blocks for clarity instead of relying on `classDef` colors on participants.

---

### D-AUTH-03 — `docs/guides/authentication-and-sessions.md`

- **Placement:** After `### 2.2 Field: rememberMe`.
- **Type:** `flowchart LR`.
- **Decision diamond:** `RememberMe == true?`
- **Branches:** Yes → `Jwt:ExpiresInMinutesRememberMe`; No/omit/null → `Jwt:ExpiresInMinutes`.
- **Join:** both → issue JWT with chosen `exp`.

---

### D-AUTH-04 — `docs/guides/authentication-and-sessions.md`

- **Placement:** After `## 3. Main frontend (fe_demo)` intro, before storage table.
- **Type:** `sequenceDiagram`.
- **Participants:** `LoginPage`, `useAuthApi`, `OpenAPIClient`, `API`, `localStorage`, `AxiosDefault`.
- **Flow:** login form → buildPasswordGrantTokenRequest (strict boolean rememberMe) → POST token → store keys → set default Authorization header → subsequent API calls.
- **Parallel note:** `useAuthToken` query reads storage; if expired clear keys.

---

### D-AUTH-05 — `docs/guides/authentication-and-sessions.md`

- **Placement:** After `### 3.3 Detecting expiry` / `### 3.4 React Query + AuthContext` (combine one diagram).
- **Type:** `flowchart TB`.
- **Nodes:** `jwtUtils[isTokenExpired]`, `interval[30s interval]`, `windowEvt[auth:unauthorized]`, `clear[Clear storage + queries]`, `toast[Session toast]`.
- **Edges:** malformed JWT → expired path; missing exp → defensive not expired; interval detects expiry → clear + toast; 401 event → clear.

---

### D-AUTH-06 — `docs/guides/authentication-and-sessions.md`

- **Placement:** After `## 6. JWT strategy (thin token + invalidation)`.
- **Type:** `flowchart TB`.
- **Subgraphs:** `JWT[JWT contents]` (only global role claim etc.) vs `DB[DB-backed authorization]` (face roles, capabilities service) vs `Refresh[Refresh rotates + reloads role from DB]`.
- **Show:** stale JWT until exp; refresh updates role in new access token.

---

### D-ACL-01 — `docs/guides/acl-and-capabilities.md`

- **Placement:** After `## 1. What was implemented (summary)` table.
- **Type:** `mindmap` **or** if mindmap unsupported, use `flowchart TB` with grouped subgraphs.
- **Branches:** OAuth/JWT lifetime; Refresh tokens; OAuth2 rate limit; SignalR face URL; Chat AI rate limit; Capabilities API; Permission catalog; PageTypes mutations; Face role picker; Self-service role; SUPER_ADMIN vs ADMIN; SignalR social rules A19.
- **Each leaf:** max 5 words.

---

### D-ACL-02 — `docs/guides/acl-and-capabilities.md`

- **Placement:** After `## 2. Permission strings`.
- **Type:** `flowchart TB`.
- **Layers:** `platform_super[platform:super]` → only `SUPER_ADMIN`; `platform_admin[platform:admin]` → admin face + global admin/super; `tenant_session[tenant:session]`; `face_member[face:member]`; `face_self[face:role:self-service]`.
- **Edges:** show that `platform_super` implies highest platform power; `platform_admin` for manage faces / page types; tenant permissions nested under authenticated face scope.

---

### D-ACL-03 — `docs/guides/acl-and-capabilities.md`

- **Placement:** After `## 3. Backend file map` (or combine with §4).
- **Type:** `flowchart LR`.
- **Nodes:** key files as boxes: `AclPermissionKeys`, `PlatformAccessRules`, `AccessEvaluator`, `AccessCapabilitiesService`, `MeController`, `TenantSocialScopeRules`, `OAuthRefreshTokenStore`.
- **Edges:** data/control flow: MeController → AccessCapabilitiesService → AccessEvaluator → PlatformAccessRules; keys constant source.

---

### D-ACL-04 — `docs/guides/acl-and-capabilities.md`

- **Placement:** After `## 4. Frontend` table.
- **Type:** `sequenceDiagram`.
- **Participants:** `Browser`, `AxiosInterceptor`, `API`, `MeController`, `AccessCapabilitiesService`.
- **Flow:** GET with Bearer → interceptor prepends `/{face}/` before `/api/me/capabilities` → API resolves face scope → JSON permissions; React Query cache; AuthContext warmup; useAuthApi invalidates on login/logout/refresh.

---

### D-ACL-05 — `docs/guides/acl-and-capabilities.md`

- **Placement:** New subsection under §1 or §7: `### Diagram: SignalR / tenant social (A19) overview`.
- **Type:** `flowchart TB`.
- **Branches:** `ChatHub` broadcast group per face; `SendPrivateMessage` directory check; `MessengerHub` messaging rules; `ChatRoomHub` FaceId must match scoped face on tenant URL.
- **Each branch:** decision nodes “admin face URL vs tenant URL” where applicable.

---

### D-ACL-06 — `docs/guides/acl-and-capabilities.md`

- **Placement:** After `## 7. Operational notes`.
- **Type:** `sequenceDiagram`.
- **Show:** Admin changes `UserFaceRole` in DB → existing JWT unchanged → next `GET capabilities` reflects DB; contrast with refresh grant updating global role claim.

---

### D-OAUTH-CURL-01 — `docs/guides/api-oauth-stories-curl.md`

- **Placement:** After `## 1. Base URL` or before `## 3. Register`.
- **Type:** `sequenceDiagram`.
- **Full story:** Register → password token (optional rememberMe) → optional refresh_token grant → GET faces → GET face-roles → PUT my-role → POST story draft → POST image → POST publish → GET list stories.
- **Participants:** `curl`, `API`, `DB`, `Storage` (optional).
- **Annotate:** which calls need Bearer.

---

### D-OAUTH-CURL-02 — `docs/guides/api-oauth-stories-curl.md`

- **Placement:** After `## 8. One-shot bash smoke test`.
- **Type:** `flowchart TB`.
- **One node per script step** (Swagger check, register, token, face id, role id, my-role, create story, optional image, list).
- **Error path:** Swagger fail → exit 1.

---

### D-CHAT-01 — `docs/guides/chat-rooms-testing-and-operations.md`

- **Placement:** After `### 1.3 REST API` table.
- **Problem:** Mixing **room states** with **user actions** (join, join-request) in one `stateDiagram-v2` is confusing (`PublicJoin` is an action, not a room state).
- **Preferred approach (pick one):**
  - **Option A — two diagrams:**
    1. **`stateDiagram-v2`** — **room lifecycle only**: e.g. `Open` (room exists and active) → `ClosingOrIdle` (optional) → `Deleted` / `Closed`; annotate side effects (Redis idle job).
    2. **`flowchart TB`** — **user/operator flow**: create room → public join _or_ private join-request → approve/deny → membership → messages; parallel swimlane for **host** (view vs participate rules per doc).
  - **Option B — single simplified `stateDiagram-v2`:** only **`active`** / **`closed`** (or equivalent) for the _room_, and use **`flowchart`** for join/request flows in the same section **below** (two fenced blocks = allowed for D-CHAT-01).
- **Do not** overload one state machine with `Member` and `HostObserve` as if they were room states—express membership and host rules in the **flowchart** (Option A2 or B).

---

### D-CHAT-02 — `docs/guides/chat-rooms-testing-and-operations.md`

- **Placement:** After `### 1.4 SignalR`.
- **Type:** `sequenceDiagram`.
- **Participants:** `Client`, `ChatRoomHub` (or exact class name from `be_demo`), `OtherClients`, `MessengerHub`.
- **Before drawing:** confirm **hub class name** and **URL path** (e.g. `/hubs/chatroom` vs other) via **`MapHub`** / hub registration in **`Program.cs`**.
- **Messages:** JoinRoom, SendRoomMessage, ReceiveRoomMessage; idle close → ChatRoomClosed; notification path to MessengerHub ReceiveNotification. Use **`Note`** for transport details; avoid relying on `classDef` for sequence participants.

---

### D-CHAT-03 — `docs/guides/chat-rooms-testing-and-operations.md`

- **Placement:** After `### 1.5 Idle lifecycle (Redis)`.
- **Type:** `flowchart TB`.
- **Nodes:** `LastActivity`, `ScheduleJob[Schedule chatroom.idle-check]`, `Worker[RedisJobWorkerService]`, `ProcessIdle[IChatRoomLifecycleService]`, `Reschedule`, `DeleteRoom`, `NotifyClosed`.
- **Logic:** if activity < 1h reschedule else delete + notify.

---

### D-CHAT-04 — `docs/guides/chat-rooms-testing-and-operations.md`

- **Placement:** After `### 3.2 Routing`.
- **Type:** `flowchart LR`.
- **Show:** `/:lang/detail/4/:entityId` and `/:lang/list/4` with note component type id 4 = chat.

---

### D-CHAT-05 — `docs/guides/chat-rooms-testing-and-operations.md`

- **Placement:** After `## 5. Manual checklist`.
- **Type:** `flowchart TB` numbered nodes 1..7 matching checklist.

---

### D-WALL-01 — `docs/guides/wall-tickets.md`

- **Placement:** After `## Data model`.
- **Type:** `erDiagram`.
- **Entities (choose one style after checking EF model names in code):**
  - **Minimal:** only `FaceWallTicket`, `FaceWallTicketComment`, `FaceWallTicketLike` with relationships and cardinality (`||--o{`, `}o--||`, etc.).
  - **Full:** add `Face` and `User` / `ApplicationUser` entities with FK-style relationships **only if** Mermaid `erDiagram` syntax supports your naming; align **field names** with the real model.
- **Relationships:** ticket has many comments; ticket has many likes; **unique** `(ticket, user)` on like; **cascade** delete comments/likes when ticket deleted (as per doc).
- **Do not** use vague “reference only as label”—either omit parent entities or model them with proper `erDiagram` lines.

---

### D-WALL-02 — `docs/guides/wall-tickets.md`

- **Placement:** After `## Status and rules` table.
- **Type:** `stateDiagram-v2`.
- **States:** `active`, `approved`, `denied`.
- **Transitions:** author edit/delete only active; approve from active; deny from active; denied schedules delete; approved frozen interactions.
- **Notes:** host cannot create/like/comment.

---

### D-WALL-03 — `docs/guides/wall-tickets.md`

- **Placement:** After user vs admin API sections.
- **Type:** `flowchart TB`.
- **Subgraphs:** `UserAPI` vs `AdminAPI`.
- **Per endpoint group:** show authz: global admin for admin routes; host restrictions on user routes.

---

### D-WALL-04 — `docs/guides/wall-tickets.md`

- **Placement:** After `## Redis worker`.
- **Type:** `sequenceDiagram`.
- **Flow:** deny → enqueue `wall.ticket-delete` payload wallTicketId → worker → `DeleteTicketHardAsync`; note Testing NoOp queue.

---

### D-WALL-05 — `docs/guides/wall-tickets.md`

- **Placement:** After `## Frontend` / `## Admin UI`.
- **Type:** `flowchart LR`.
- **Nodes:** `FaceWallPage`, `CreatePanel`, `DetailPanel`, `AdminFaceDetail`, `AdminModerationTable`.
- **Edges:** navigation triggers.

---

### D-SEC-01 — `docs/guides/security-crypto-sockets.md`

- **Placement:** After intro, before P0 sections.
- **Type:** `flowchart TB`.
- **Layers (subgraphs):** Signing keys (K\*) → JWT validation (J\*) → OAuth endpoint (O\*) → TLS transport (T\*) → SignalR (S\*) → Headers/OpenAPI/Monitoring (H/D/M).
- **Edges:** “depends on” downward.
- **Note:** This diagram describes the **backlog structure**, not a claim that every K/J/O item is implemented—cross-check code when labeling anything as “done”.

---

### D-SEC-02 — `docs/guides/security-crypto-sockets.md`

- **Placement:** After `## Suggested implementation order`.
- **Type:** `flowchart TB`.
- **Phases:** Phase1 K+J foundation; Phase2 T+S; Phase3 O; Phase4 H/D/M as parallel cluster.
- **Style:** phase nodes distinct color.

---

### D-SEC-03 — `docs/guides/security-crypto-sockets.md`

- **Placement:** New subsection before “Current baseline”.
- **Type:** `sequenceDiagram`.
- **Target architecture:** Client → TLS edge → API → JWKS verify → optional refresh store → SignalR WSS with same validation.
- **Mark explicitly in diagram title or Note:** **“Target / roadmap — not fully implemented”**.
- **Critical:** Do **not** copy the markdown table **“Current baseline”** into the diagram as fact without **verifying** `Program.cs` (e.g. `JwtBearerOptions`, `ValidateLifetime`), `OAuth2Service`, and refresh-token storage. If the table conflicts with code, the diagram should reflect **code** and optionally add a prose callout that the table needs a doc update (separate task).

---

### D-DEVHTTPS-01 — `docs/guides/dev-https.md`

- **Placement:** After `## One-time setup`.
- **Type:** `flowchart LR`.
- **Steps:** `generate-https-certs.sh` → `dev/certs` PEM+PFX → optional `mkcert -install` → Docker mounts / Vite cert dir → browsers trust.

---

### D-DEVHTTPS-02 — `docs/guides/dev-https.md`

- **Placement:** After `## Ports (default)`.
- **Type:** `flowchart TB` or `C4` unavailable—use **subgraph** per service: `API http:8000 https:8001`, `FE docker host 9081→8081`, `FE host yarn https:8081`, `Admin https:8082`.
- **Show:** env `VITE_API_URL=https://localhost:8001`.

---

### D-DEV-01 — `docs/guides/development.md`

- **Placement:** After `## Layout` table.
- **Type:** `flowchart TB`.
- **Monorepo:** each submodule node with stack label from table.

---

### D-DEV-02 — `docs/guides/development.md`

- **Placement:** After commitlint examples.
- **Type:** `flowchart TB`.
- **Decision tree:** type valid? scope? subject case? length? trailing period? → pass/fail.

---

### D-DEV-03 — `docs/guides/development.md`

- **Placement:** After CI jobs table.
- **Type:** `flowchart TB`.
- **Parallel jobs:** be_demo, fe_demo, admin_demo, ai_demo, infra\* as parallel nodes; `monorepo_scripts` runs `scripts/ci-local.sh` chain—show relationship “parity check”.

---

### D-DEV-04 — `docs/guides/development.md`

- **Placement:** After monorepo `scripts/` table.
- **Type:** `flowchart TB`.
- **`scripts/ci-local.sh` → lint-all → build-all → test-all** with branch `SKIP_CYPRESS`.

---

### D-DEV-05 — `docs/guides/development.md`

- **Placement:** After `### Data sources` under face home grid.
- **Type:** `flowchart LR`.
- **Each tile type** → **GET endpoint** exactly as table (Ad, Album, Blog, Chat room, User profile, Story, Reel).

---

### D-DEV-06 — `docs/guides/development.md`

- **Placement:** After `Database seeding` bullets.
- **Type:** `flowchart TB`.
- **Nested loops:** for each demo user × each face × content classes → ensure count 5; idempotent refill.

---

### D-GITMOD-01 — `docs/guides/git-submodules.md`

- **Placement:** After initial “Creating GitHub repositories” section.
- **Type:** `flowchart TB`.
- **Steps:** create empty GH repos → push each submodule → edit `.gitmodules` → `submodule add` / commit → root remote → push root with pinned SHAs.

---

### D-GITMOD-02 — `docs/guides/git-submodules.md`

- **Placement:** After `## Day-to-day usage`.
- **Type:** `sequenceDiagram`.
- **Developer:** commit in `be_demo` → push submodule → cd root → `git add be_demo` → commit pointer → push root.

---

### D-HUSKY-01 — `docs/guides/husky-setup.md`

- **Placement:** After overview paragraph.
- **Type:** `flowchart LR`.
- **Hooks:** `commit-msg` → commitlint; `pre-commit` → lint-staged (match what file actually documents—read file first).

---

### D-PROPOSAL-01 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After monorepo `scripts/` / `start-all-dev` description.
- **Type:** `flowchart TB`.
- **Ordered chain:** DB → backend+Seq → FE → AI → logger → admin + side note auto-restart monitor.

---

### D-PROPOSAL-02 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After BE controllers + hubs overview.
- **Type:** `flowchart TB`.
- **Subgraphs:** `HTTP_Controllers`, `SignalR_Hubs`, `Core_Services`, `Middleware`.
- **Edges:** realistic high-level call paths (HTTP → services → DB; hubs → services / gRPC).

---

### D-PROPOSAL-03 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After `### Middleware`.
- **Type:** `flowchart LR`.
- **Request path:** Client → `RoutingMiddleware` (face rewrite) → `OAuth2Middleware` → endpoints.

---

### D-PROPOSAL-04 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After `### Data (EF Core)` roles subsection.
- **Type:** `erDiagram`.
- **Entities:** `ApplicationUser`, `UserRole`, `UserFaceProfile`, `UserFaceRole`, `Face` — **verify** table and FK names in **`ApplicationDbContext`** / entity classes before drawing.
- **Syntax:** Use valid `erDiagram` relationships with cardinality; Mermaid does not support arbitrary “comments on entities” in all versions—put extra field lists in **prose under** the diagram if needed.

---

### D-PROPOSAL-05 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After default pages when creating face.
- **Type:** `flowchart TB`.
- **POST /faces** → creates Home; if non-public add Wall; page types home/static/wall.

---

### D-PROPOSAL-06 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After private face first visit / my-role.
- **Type:** `sequenceDiagram`.
- **FE** config load with token → **GET face-roles** → user picks → **PUT my-role** → **localStorage** gate for panel.

---

### D-PROPOSAL-07 — `docs/guides/proposal-mfai-demo-state.md`

- **Placement:** After AI service section.
- **Type:** `sequenceDiagram`.
- **be_demo** startup HealthCheck → **ai_demo**; **ChatHub SendToAi** → gRPC Generate → streaming/error handling note.

---

### D-SUPERADMIN-01 — `docs/prompts/super-admin-api.md`

- **Placement:** After §2.2 inventory.
- **Type:** `flowchart TB`.
- **Compare:** `IsGlobalAdmin` vs `IsGlobalSuperAdmin` vs `CanManageAllFaces` vs `CanMutateGlobalPageTypes`—AND/OR of admin face scope + JWT role.

---

### D-SUPERADMIN-02 — `docs/prompts/super-admin-api.md`

- **Placement:** After §4.1 MVP validations list.
- **Type:** `flowchart TB`.
- **Decision tree** for `PUT global-role`: auth checks → load user → forbid self → validate role row global + whitelist → last super check → persist → audit → response; error nodes 400/401/403/404/409.

---

### D-SUPERADMIN-03 — `docs/prompts/super-admin-api.md`

- **Placement:** After §7 test plan.
- **Type:** `flowchart TB` matrix style: rows test cases, columns token type / face client / expected code (compact labels).

---

### D-COMP-ACL-01 — `docs/components/acl-capabilities-module.md`

- **Placement:** After “Where in the repo” table.
- **Type:** `flowchart LR` — **small** (fewer nodes than **D-ACL-03**).
- **Single source of truth:** Add an explicit **markdown link** under the diagram to the **canonical** section in `docs/guides/acl-and-capabilities.md` where the full file-flow (**D-ACL-03**) lives (e.g. “Full diagram: see … §3–4”). **Do not** duplicate the entire D-ACL-03 graph—avoid drift between `components/` and `guides/`.

---

### D-FE-OVERVIEW-01 — `docs/readmes/fe-demo-overview.md`

- **Placement:** After `## 2. What is a “face”`.
- **Type:** `flowchart TB`.
- **Public vs private** paths; private first visit opens role panel; face switch from side panel.

---

### D-FE-OVERVIEW-02 — `docs/readmes/fe-demo-overview.md`

- **Placement:** After `## 3. Navigation and layout`.
- **Type:** `flowchart TB` **subgraphs** `Header`, `Main`, `Footer`, `SidePanel` with listed tabs inside SidePanel node.

---

### D-FE-OVERVIEW-03 — `docs/readmes/fe-demo-overview.md`

- **Placement:** After `## 6. Dynamic face pages`.
- **Type:** `flowchart TB`.
- **Page** → **blocks** → **component type** → **display mode** (single/grid/carousel).

---

### D-FE-OVERVIEW-04 — `docs/readmes/fe-demo-overview.md`

- **Placement:** After `## 10. Messenger` (and optionally AI Chat).
- **Type:** `sequenceDiagram` simplified messenger message send/receive.

---

### D-ADMIN-OVERVIEW-01 — `docs/readmes/admin-demo-overview.md`

- **Placement:** After `## 2. Layout and navigation`.
- **Type:** similar to D-FE-OVERVIEW-02 with admin-specific items (Dashboard, Users, Faces, AI Chat).

---

### D-ADMIN-OVERVIEW-02 — `docs/readmes/admin-demo-overview.md`

- **Placement:** After `#### Grid layout editor`.
- **Type:** `flowchart LR`.
- **Add block → DnD → resize → assign component category → variants**.

---

### D-ADMIN-OVERVIEW-03 — `docs/readmes/admin-demo-overview.md`

- **Placement:** After `## 9. Typical admin workflow`.
- **Type:** `flowchart TB` numbered 1–6.

---

### D-REDIS-SUB-01 — `docs/readmes/redis-subrepo.md`

- **Placement:** After backend connection bullets.
- **Type:** `flowchart LR`.
- **`docker-compose.dev.yml` `be-demo-dev` → host.docker.internal:6379 → `redis-dev` container**.

---

### D-REDIS-SUB-02 — `docs/readmes/redis-subrepo.md` (queue internals extension)

- **Placement:** After **`D-REDIS-SUB-01`** in the same file (or after connection section).
- **Type:** `flowchart TB`.
- **Content:** `bedemo:jobs:ready` (FIFO list), `bedemo:jobs:delayed` (sorted set, score = run time), worker loop promoting due jobs to ready—aligned with monorepo **`RedisJobWorkerService`** behaviour.
- **Required prose:** Add **1–3 sentences** above the diagram citing backend queue usage if not already in the paragraph (so the diagram is grounded). **Do not** skip this diagram.

---

### D-README-READMES-01 — `docs/readmes/README.md`

- **Placement:** After the intro paragraph or after the submodule README table.
- **Type:** `flowchart TB`.
- **Content:** Each submodule (`be_demo`, `fe_demo`, …) as a node → its **`README.md`** path (as in the table). Show hub role of this index file.

---

### D-BOILER-01 — `docs/guides/boilerplate-checklist.md`

- **Placement:** After the first major heading or overview.
- **Type:** `mindmap` if section structure supports it; otherwise **`flowchart TB`** grouping checklist items into clusters.
- **REQUIRED:** Always deliver **one** diagram; if headings are flat, cluster by **prefix** (e.g. all `✅` lines sharing a theme) or by **first-level list** items.

---

## 3. Quality bar (agent self-check before finishing)

- [x] **Every** diagram ID **`D-*`** from §2 is **added** in the target file **or** listed as **`skipped`** with reason (e.g. missing file). None may be omitted from the report.
- [x] No broken markdown fences: every fenced **`mermaid`** block has a matching closing fence (e.g. search for triple-backtick pairs per file). Prefer **`grep`** or a small script if no Mermaid CLI.
- [x] Mermaid parses without syntax errors—use **`mmdc`** or IDE preview **on a sample** of diagrams if available.
- [x] Labels match **current** code and doc terms; **SignalR** paths and hub names verified via **`be_demo`** search.
- [x] **Diagram coverage (heuristic):** For each `docs/**/*.md` file you modified, skim the longest **process-heavy** section; if it still has **no** visual after your pass, consider one diagram **or** document in the report why text-only is sufficient (edge case). Do **not** treat “400 lines” as a hard automated metric.
- [x] **Accessibility:** do not rely on color alone—use distinct **node shapes** / **subgraphs** / **text prefixes** (`API:`, `DB:`). For **sequence** diagrams, prefer **Notes** over participant coloring.
- [x] **`security-crypto-sockets.md`:** Any “current state” claim in a diagram was **verified** against code **or** explicitly labeled target/roadmap only.

---

## 4. Deliverables

**Completed for this repo (diagram pass):** treat the items below as satisfied unless you re-run the agent on a fresh tree.

- [x] All edits in `docs/**/*.md` as specified (all **62** `D-*` specs implemented in target files).
- [x] **No** repo-root `## Mermaid diagrams` index added; diagrams live in context inside each target doc.
- [x] Final human report: **one** table **Diagram ID → file → status** — for this pass, every ID is **`added`** in its target file (no `skipped` rows).

---

## 5. Master checklist (every requirement in this prompt)

**Status:** **Done** for the current `_mfai_demo` documentation tree — all subsections **5.1–5.7** use **[x]** below. If you rerun the agent from scratch, reset relevant lines to **[ ]** before execution. **Convention:** this file is the **exception** where `[x]` records a completed diagram pass; most other prompts keep `[ ]` as PR-only templates—see [docs/prompts/README.md](./README.md).

Work through **top to bottom** when executing a **new** pass; this copy reflects a **completed** pass you can diff against.

### 5.1 Header goals and constraints (lines under the title)

- [x] Treated the prompt as instructions for an **autonomous agent**, not end-user documentation.
- [x] **Diagram labels in English**, consistent with existing `docs/`.
- [x] **Preserved** existing markdown prose; only **added** diagrams (or replaced content only where a spec allows and information loss is ruled out).
- [x] Placed diagrams **after** the heading or table they summarize, unless a spec names a different anchor.
- [x] Did **not** bloat unrelated files; **`docs/prompts/README.md`** updated **only** if new prompt files were added (separate from diagram work).

### 5.2 §0 — Your mission (execute in order)

- [x] **0.1** Read each target file from disk **before** editing.
- [x] **0.2** For each `D-*` spec: **one** fenced mermaid block, **except** where the spec allows more (e.g. **D-CHAT-01** → **all** allowed blocks present).
- [x] **0.3** Prefer `### Diagram: …` over `<details>` unless the file already uses `<details>` consistently.
- [x] **0.4** Verified diagrams are valid for **GitHub-flavored Markdown** / mainstream Mermaid (no exotic syntax).
- [x] **0.5** Used correct diagram **types**: `flowchart` / `sequenceDiagram` / `stateDiagram-v2` / `erDiagram` / `mindmap` per rules; prefer `flowchart` over `graph` when equivalent.
- [x] **0.6** `classDef` / `class` mainly on **flowchart**/**graph**; **sequenceDiagram**: no reliance on participant color for meaning—use **Notes** and message text prefixes.
- [x] **0.7** **No** self-arrows on middleware/participants for internal work—use **`Note over …`**.
- [x] **0.8** Token/response path in sequences: logical `Service-->>Client` OK, or full stack return; **prose note** if abbreviated.
- [x] **0.9** Arrow/small-node labels **~≤40 characters**; extra detail in markdown **below** the diagram.
- [x] **0.10** Subgraphs: `subgraph id["Title"]`, IDs **alphanumeric + underscore**.
- [x] **0.11** Long flowchart labels: short nodes + prose; `<br/>` only if tested.
- [x] **0.12** Node IDs: **alphanumeric + underscore** only.
- [x] **0.13** `mindmap`: fallback to `flowchart TB` + subgraphs if renderer fails.
- [x] **0.14** Flowchart styling: used the **WCAG palette** from §0 where `classDef` applies (`clientFill`, `apiFill`, `dbFill`, `queueFill`, `extFill`).
- [x] **0.15** **Hub names and `/hubs/...` paths** verified in **`be_demo`** (`MapHub`, hub classes).
- [x] **0.16** **`security-crypto-sockets.md`**: “current” vs **target/roadmap** explicit; cross-checked **`Program.cs`**, **`OAuth2Service`**, **`JwtBearerOptions`**, refresh storage when claiming current behaviour.
- [x] **0.17** **Closing fences**: every opening mermaid fence has a matching closing fence; optional **`mmdc`** / IDE sample validation.
- [x] **0.18** **`D-COMP-ACL-01`**: small diagram + **link** to canonical **`D-ACL-03`** section—**not** a full duplicate of the file-flow graph.
- [x] **0.19** **Every `D-*` in §2** implemented or **`skipped`** with concrete reason—**never** “optional” or “low priority” skip.

### 5.3 §1 — Repository context (ground truth)

- [x] Used **`_mfai_demo`** layout and submodule names when labeling.
- [x] Backend labels match **OAuth2 / JWT / refresh / RoutingMiddleware / hubs / EF / PostgreSQL** as in repo.
- [x] Frontend labels match **`fe_demo` / `admin_demo`**, `/{face}/`, **`localStorage`** keys, interceptors.
- [x] Queue labels match **Redis keys**, **`RedisJobWorkerService`**, example job types where relevant.
- [x] Where doc and **code** disagreed, diagram follows **code** (and noted doc drift in report only if helpful).

### 5.4 §2 — Inventory rules and workflow

- [x] **§2.1** Each `### D-*` satisfied by **one or more** valid mermaid blocks **or** one **`skipped`** row per ID (multi-block specs: **all** blocks or skip whole ID with reason).
- [x] **§2.2** Work order respected where practical: auth + ACL guides first → other guides → readmes → super-admin + components → STRUCTURE + docs README hub.
- [x] **§2.3** **`D-BOILER-01`**: never omitted—`flowchart` clusters if flat. **`D-HUSKY-01`**: hooks match **only** what **`husky-setup.md`** documents.

### 5.5 §2 — Every diagram ID (must appear in final table)

Check each row: **`added`** / **`updated`** / **`skipped` + reason**.

**Execution batches (check only when the whole batch is implemented in the repo):**

- [x] **Batch 1 — Auth + ACL guides:** `authentication-and-sessions.md` (`D-AUTH-01` … `D-AUTH-06`), `acl-and-capabilities.md` (`D-ACL-01` … `D-ACL-06`).
- [x] **Batch 2 — Curl + chat + wall:** `api-oauth-stories-curl.md` (`D-OAUTH-CURL-01`, `D-OAUTH-CURL-02`), `chat-rooms-testing-and-operations.md` (`D-CHAT-01` … `D-CHAT-05`), `wall-tickets.md` (`D-WALL-01` … `D-WALL-05`).
- [x] **Batch 3 — Security + dev + monorepo dev guide:** `security-crypto-sockets.md` (`D-SEC-01` … `D-SEC-03`), `dev-https.md` (`D-DEVHTTPS-01`, `D-DEVHTTPS-02`), `development.md` (`D-DEV-01` … `D-DEV-06`).
- [x] **Batch 4 — Git + hooks + boilerplate + proposal:** `git-submodules.md` (`D-GITMOD-01`, `D-GITMOD-02`), `husky-setup.md` (`D-HUSKY-01`), `boilerplate-checklist.md` (`D-BOILER-01`), `proposal-mfai-demo-state.md` (`D-PROPOSAL-01` … `D-PROPOSAL-07`).
- [x] **Batch 5 — Prompts + components + docs hub:** `super-admin-api.md` (`D-SUPERADMIN-01` … `D-SUPERADMIN-03`), `acl-capabilities-module.md` (`D-COMP-ACL-01`), `STRUCTURE.md` (`D-STRUCT-01`), `README.md` (`D-README-HUB-01`).
- [x] **Batch 6 — Readmes overviews:** `fe-demo-overview.md` (`D-FE-OVERVIEW-01` … `D-FE-OVERVIEW-04`), `admin-demo-overview.md` (`D-ADMIN-OVERVIEW-01` … `D-ADMIN-OVERVIEW-03`), `redis-subrepo.md` (`D-REDIS-SUB-01`, `D-REDIS-SUB-02`), `readmes/README.md` (`D-README-READMES-01`).

| File                                               | IDs                                                            |
| -------------------------------------------------- | -------------------------------------------------------------- |
| `docs/STRUCTURE.md`                                | `D-STRUCT-01`                                                  |
| `docs/README.md`                                   | `D-README-HUB-01`                                              |
| `docs/guides/authentication-and-sessions.md`       | `D-AUTH-01` … `D-AUTH-06` (6)                                  |
| `docs/guides/acl-and-capabilities.md`              | `D-ACL-01` … `D-ACL-06` (6)                                    |
| `docs/guides/api-oauth-stories-curl.md`            | `D-OAUTH-CURL-01`, `D-OAUTH-CURL-02`                           |
| `docs/guides/chat-rooms-testing-and-operations.md` | `D-CHAT-01` (state + flow per spec), `D-CHAT-02` … `D-CHAT-05` |
| `docs/guides/wall-tickets.md`                      | `D-WALL-01` … `D-WALL-05` (5)                                  |
| `docs/guides/security-crypto-sockets.md`           | `D-SEC-01` … `D-SEC-03` (3)                                    |
| `docs/guides/dev-https.md`                         | `D-DEVHTTPS-01`, `D-DEVHTTPS-02`                               |
| `docs/guides/development.md`                       | `D-DEV-01` … `D-DEV-06` (6)                                    |
| `docs/guides/git-submodules.md`                    | `D-GITMOD-01`, `D-GITMOD-02`                                   |
| `docs/guides/husky-setup.md`                       | `D-HUSKY-01`                                                   |
| `docs/guides/boilerplate-checklist.md`             | `D-BOILER-01`                                                  |
| `docs/guides/proposal-mfai-demo-state.md`          | `D-PROPOSAL-01` … `D-PROPOSAL-07` (7)                          |
| `docs/prompts/super-admin-api.md`                  | `D-SUPERADMIN-01` … `D-SUPERADMIN-03` (3)                      |
| `docs/components/acl-capabilities-module.md`       | `D-COMP-ACL-01`                                                |
| `docs/readmes/fe-demo-overview.md`                 | `D-FE-OVERVIEW-01` … `D-FE-OVERVIEW-04` (4)                    |
| `docs/readmes/admin-demo-overview.md`              | `D-ADMIN-OVERVIEW-01` … `D-ADMIN-OVERVIEW-03` (3)              |
| `docs/readmes/redis-subrepo.md`                    | `D-REDIS-SUB-01`, `D-REDIS-SUB-02`                             |
| `docs/readmes/README.md`                           | `D-README-READMES-01`                                          |

**Flat list (62 IDs):** `D-STRUCT-01`, `D-README-HUB-01`, `D-AUTH-01`, `D-AUTH-02`, `D-AUTH-03`, `D-AUTH-04`, `D-AUTH-05`, `D-AUTH-06`, `D-ACL-01`, `D-ACL-02`, `D-ACL-03`, `D-ACL-04`, `D-ACL-05`, `D-ACL-06`, `D-OAUTH-CURL-01`, `D-OAUTH-CURL-02`, `D-CHAT-01`, `D-CHAT-02`, `D-CHAT-03`, `D-CHAT-04`, `D-CHAT-05`, `D-WALL-01`, `D-WALL-02`, `D-WALL-03`, `D-WALL-04`, `D-WALL-05`, `D-SEC-01`, `D-SEC-02`, `D-SEC-03`, `D-DEVHTTPS-01`, `D-DEVHTTPS-02`, `D-DEV-01`, `D-DEV-02`, `D-DEV-03`, `D-DEV-04`, `D-DEV-05`, `D-DEV-06`, `D-GITMOD-01`, `D-GITMOD-02`, `D-HUSKY-01`, `D-BOILER-01`, `D-PROPOSAL-01`, `D-PROPOSAL-02`, `D-PROPOSAL-03`, `D-PROPOSAL-04`, `D-PROPOSAL-05`, `D-PROPOSAL-06`, `D-PROPOSAL-07`, `D-SUPERADMIN-01`, `D-SUPERADMIN-02`, `D-SUPERADMIN-03`, `D-COMP-ACL-01`, `D-FE-OVERVIEW-01`, `D-FE-OVERVIEW-02`, `D-FE-OVERVIEW-03`, `D-FE-OVERVIEW-04`, `D-ADMIN-OVERVIEW-01`, `D-ADMIN-OVERVIEW-02`, `D-ADMIN-OVERVIEW-03`, `D-REDIS-SUB-01`, `D-REDIS-SUB-02`, `D-README-READMES-01`.

- [x] **D-CHAT-01:** If using Option A or B, **both** the lifecycle **stateDiagram** (or approved single-state simplification) **and** the **flowchart** for user/join flows are present as the spec requires—**not** one overloaded state machine.

### 5.6 §3 — Quality bar (repeat before handoff)

- [x] Final report lists **every** ID above—none omitted.
- [x] All mermaid fenced blocks closed; optional **`mmdc`** / IDE parse sample.
- [x] **SignalR** / hub / path labels verified against **`be_demo`**.
- [x] For each edited doc: longest process-heavy section either has a diagram **or** report explains text-only (edge case).
- [x] **A11y:** meaning not by color alone; sequence diagrams use **Notes** over participant colors.
- [x] **`security-crypto-sockets.md`:** no unverified “current” claims in diagrams.

### 5.7 §4 — Deliverables

- [x] All specified edits under `docs/**/*.md` as specified.
- [x] **No** repo-root Mermaid index unless the user asked.
- [x] **One** human-facing table: **Diagram ID → file → status** (`added` / `updated` / `skipped` + reason) for **all 62** IDs.

---

_End of agent prompt — copy from line 1 through here into a new AI conversation to execute the work._
