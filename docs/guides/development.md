# Development — monorepo, CI, Node, Python, errors

This document covers **how we build and test** the **`many_faces_main`** root repo (with submodules / nested apps) and **contracts** shared by FE, admin, BE, and tooling.

## Documentation layout

- **Hub:** [**`docs/README.md`**](../README.md) — index of `guides/`, `components/`, `prompts/`, `readmes/`.
- **Structure rationale:** [`docs/STRUCTURE.md`](../STRUCTURE.md).

## Layout

| Area                 | Path           | Stack                     |
| -------------------- | -------------- | ------------------------- |
| Backend API          | `many_faces_backend/`     | .NET, EF Core, PostgreSQL |
| Main frontend        | `many_faces_portal/`     | Vite, React, Yarn 4       |
| Admin UI             | `many_faces_admin/`  | Vite, React, Yarn 4       |
| AI gRPC service      | `many_faces_ai/`     | Python 3.11+, gRPC, Ruff  |
| PostgreSQL dev stack | `many_faces_database/`     | Docker Compose            |
| Redis dev stack      | `many_faces_redis/`  | Docker Compose            |
| Logger UI (Dozzle)   | `many_faces_logger/` | Docker Compose            |
| Mobile app           | `many_faces_mobile/`   | Expo, React Native, Yarn 4  |

### Diagram: monorepo layout

```mermaid
flowchart TB
  BE[many_faces_backend .NET EF PostgreSQL]
  FE[many_faces_portal Vite React Yarn]
  AD[many_faces_admin Vite React Yarn]
  AI[many_faces_ai Python gRPC]
  DB[many_faces_database Docker Postgres]
  RD[many_faces_redis Docker Redis]
  LG[many_faces_logger Dozzle]

  classDef apiFill fill:#fff3e0,stroke:#ef6c00
  class BE,FE,AD,AI,DB,RD,LG apiFill
```

The **root** repository runs aggregated CI (see below). Each submodule that ships code also has its own `.github/workflows/ci.yml` for standalone pushes to that repo.

## Node.js (many_faces_portal, many_faces_admin)

- **Version**: `22.14.0` (`.nvmrc` in repo root, `many_faces_portal`, and `many_faces_admin`).
- **Package manager**: **Yarn 4** via Corepack (`packageManager` in each `package.json`). Do **not** use `npm` or `npx` for `many_faces_portal` / `many_faces_admin` (install, scripts, hooks, Docker) — use `yarn` / `yarn exec` / `yarn run` instead.
- **`engines.node`**: `>=22.14.0` in `many_faces_portal` and `many_faces_admin`.

Use `nvm use` (or your version manager) before `yarn install`. Older Node versions cause Vite warnings or failures.

### ESLint 10 and `eslint-plugin-react-hooks` (`many_faces_portal`, `many_faces_admin`)

Both SPAs use **ESLint 10** with **`@eslint/js` ^10** and **`typescript-eslint` ^8.58**. Stable **`eslint-plugin-react-hooks@latest`** (7.0.x) did not yet list ESLint **10** in `peerDependencies`, which produced Yarn **`YN0060`** against ESLint 10. The repos therefore pin an **exact** **canary** build whose peers include **`^10.0.0`** (strategy **A2** in [`docs/prompts/eslint10-react-hooks-peer-yarn-agent-prompt.md`](../prompts/eslint10-react-hooks-peer-yarn-agent-prompt.md)).

- **Submodule docs:** [`many_faces_portal/docs/eslint-plugin-react-hooks-peer.md`](../../many_faces_portal/docs/eslint-plugin-react-hooks-peer.md), [`many_faces_admin/docs/eslint-plugin-react-hooks-peer.md`](../../many_faces_admin/docs/eslint-plugin-react-hooks-peer.md) — removal trigger, risk, upstream links.
- **Flat config:** `eslint.config.js` extends **`reactHooks.configs.flat.recommended`** (full React Compiler–aligned hooks rules) with **`eslint-config-prettier` last**. Violations were cleared in both SPAs (`set-state-in-effect` refactors, TanStack Table / RHF **`react-hooks/incompatible-library`** remain at **`warn`** upstream).
- **Yarn:** after the pin, **`YN0060`** for the ESLint ↔ react-hooks conflict should be **gone**. A generic **`YN0086`** (“peer dependencies incorrectly met by **dependencies**”) may still appear from **transitive** trees (e.g. tooling); investigate with `yarn explain peer-requirements` if it blocks CI policy.
- **Gradual rollout** of the full `eslint-plugin-react-hooks` `flat.recommended` preset (React Compiler–oriented rules): agent prompt [`docs/prompts/react-hooks-compiler-rules-rollout-agent-prompt.md`](../prompts/react-hooks-compiler-rules-rollout-agent-prompt.md).

## Expo (`many_faces_mobile`)

The mobile submodule uses **Expo**, **TypeScript**, and **Yarn 4** via Corepack (`packageManager` in `many_faces_mobile/package.json`, `yarn.lock` — same family as `many_faces_portal` / `many_faces_admin`, separate install per app). Use Node from **`many_faces_mobile/.nvmrc`** (aligned with the monorepo, **22.14+**).

- **Start here:** [`mobile-expo-development.md`](./mobile-expo-development.md) — prerequisites, `corepack enable`, `yarn install`, `yarn start`, Expo Go, env vars, submodule pointer bumps.
- **Implementation prompt:** [`mobile-phase1-foundation-agent-prompt.md`](../prompts/mobile-phase1-foundation-agent-prompt.md) — config/auth parity with `many_faces_portal`, README style, ESLint/Prettier, tests, gitflow, parent `ci.yml` job.

## Python (many_faces_ai)

- **CI / recommended**: **Python 3.11** (matches `pyproject.toml` target and GitHub Actions).
- Generated gRPC files (`proto/*_pb2*.py`) are **gitignored**; CI and local dev generate them with:

  ```bash
  cd many_faces_ai
  ./scripts/generate_proto.sh
  ```

  or `python -m grpc_tools.protoc -I proto --python_out=proto --grpc_python_out=proto proto/health.proto`.

- **Lint**: `./scripts/lint.sh` (Ruff). **Tests**: after generating protos, `PYTHONPATH=. pytest test_server.py` (no PyTorch required for health-check tests).

## Git hooks (Husky + commitlint)

- Husky **9**: hooks **do not** source `husky.sh`. Use a shebang and direct commands, e.g. `yarn exec commitlint --edit "$1"` (same for `lint-staged`).
- **many_faces_portal** and **many_faces_admin**: Yarn `prepare` → Husky; `commitlint.config.js` (ESM).
- **many_faces_backend**: run **`yarn install`** in `many_faces_backend/` (Yarn 4 / PnP as in `package.json`) so Husky and commitlint are available; **`commitlint.config.cjs`** + `.husky/commit-msg` runs `yarn exec commitlint` (same rules as FE/admin). **`node_modules/`** is gitignored for edge cases; this repo uses Plug’n’Play (`.pnp.cjs`).

### Commit message rules (all repos with commitlint)

Conventional Commits: **`type(scope): subject`**

| Rule        | Detail                                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------------- |
| **type**    | One of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`                |
| **scope**   | Recommended, not empty (warning if missing): short area, e.g. `wall`, `fe`, `admin`, `api`, `ci`                    |
| **subject** | **lower-case** or **sentence-case**; no trailing period; max **100** chars                                          |
| **Avoid**   | Random **ALL CAPS** acronyms in the subject (e.g. write “ci workflow” not “CI Workflow”) — `subject-case` will fail |

**Examples (valid)**

```text
feat(wall): add host viewer detection for create button
fix(admin): show api error text in moderation toasts
test(api): cover wall list when face is missing
chore: bump many_faces_portal submodule pointer
docs: expand development and ci notes
```

**Examples (invalid)**

```text
feat: no scope (warning)
feat(WALL): WRONG CASE SUBJECT
fix(api): Ends with period.
```

### Diagram: commitlint decision tree

```mermaid
flowchart TB
  T{type valid}
  S{scope present}
  C{subject case ok}
  L{subject length ok}
  P{no trailing period}
  T -->|no| F[Fail]
  T -->|yes| S
  S -->|warn empty| W[Warning]
  S --> C
  C -->|no| F
  C -->|yes| L
  L -->|no| F
  L -->|yes| P
  P -->|no| F
  P -->|yes| OK[Pass]
  W --> C
```

## Continuous integration

### Root `many_faces_main` — workflow `.github/workflows/ci.yml`

On push/PR to `main` / `master`, with **submodules recursive**:

| Job                   | What runs                                                                                                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **many_faces_backend**           | `dotnet restore`, `dotnet format --verify-no-changes`, Release build, `dotnet test`                                                                          |
| **many_faces_portal**           | Node from `many_faces_portal/.nvmrc`, `yarn install --immutable`, `yarn validate`, `yarn test`, `yarn build`, **`yarn npm audit`** (informational, always exits 0 in CI), then **Cypress smoke**: `yarn preview` on **HTTP** `127.0.0.1:4173` + **`yarn test:e2e:ci`** |
| **many_faces_admin**        | Same Node/Yarn gate as **many_faces_portal** through **`yarn build`**, plus informational **`yarn npm audit`**; **no** Cypress job in this workflow yet. |
| **many_faces_mobile**       | Node from **`many_faces_mobile/.nvmrc`**, **`corepack enable`** + **`yarn install --immutable`**, then **`./scripts/verify-ci.sh --quick`** (ESLint + Prettier check + `tsc`, Jest, `expo-doctor`, informational **`yarn npm audit`**). |
| **many_faces_ai**           | Python **3.11**, pip install **grpcio 1.68.x** + ruff + pytest (no torch), **generate protos**, `ruff` + `pytest test_server.py`                             |
| **infra_many_faces_database**     | `docker compose -f many_faces_database/docker-compose.yml config`                                                                                                        |
| **infra_many_faces_redis**  | `docker compose -f many_faces_redis/docker-compose.yml config`                                                                                                     |
| **infra_many_faces_logger** | `docker compose -f many_faces_logger/docker-compose.dev.yml config`                                                                                                |
| **docs_mermaid**      | Node from `many_faces_portal/.nvmrc`, runs **`./scripts/check-mermaid-docs.sh`** — validates every **mermaid**-labeled fenced code block via `@mermaid-js/mermaid-cli` |
| **monorepo_scripts**  | Yarn installs for **many_faces_portal** + **many_faces_admin** + **`many_faces_mobile`** (`yarn install --immutable` in each), **`./scripts/audit-monorepo-deps.sh`** (informational NuGet + Yarn audit including **many_faces_mobile**), then **`./scripts/ci-local.sh`**: `lint-all` → `build-all` → `test-all` (default **`SKIP_CYPRESS=1`**) |

The **monorepo_scripts** job is the parity check that root orchestration scripts match what individual jobs already cover; it fails if e.g. `scripts/lint-all.sh` or `verify-ci.sh` drifts from CI. Dependency-audit output is logged for triage but does not gate green by itself (`|| true` in the audit script and in **many_faces_portal** / **many_faces_admin** audit steps).

### Diagram: root CI jobs (parallel)

```mermaid
flowchart TB
  BEJ[many_faces_backend job]
  FEJ[many_faces_portal job]
  ADJ[many_faces_admin job]
  AIJ[many_faces_ai job]
  DBJ[infra many_faces_database config]
  RDJ[infra many_faces_redis config]
  LGJ[infra many_faces_logger config]
  DOCSJ[docs_mermaid Mermaid CLI]
  MONO[monorepo_scripts scripts/ci-local.sh]
  PARITY[Parity lint build test SKIP_CYPRESS]
  BEJ --- MONO
  FEJ --- MONO
  MONO --- PARITY

  classDef queueFill fill:#fce4ec,stroke:#c2185b
  class MONO,PARITY queueFill
```

Commits that **only** bump submodule SHAs and/or `docs/` still trigger this pipeline so every merge is validated against the checked-in submodule tree.

## Monorepo scripts (`scripts/`)

Run from repository root (submodules checked out). Executable bits: match the **Make scripts executable** step in **monorepo_scripts** (`.github/workflows/ci.yml`) — `chmod` on `scripts/*.sh` plus `find` over each submodule’s **`scripts/*.sh`** (`many_faces_portal`, `many_faces_admin`, `many_faces_backend`, `many_faces_ai`, `many_faces_database`, `many_faces_redis`, `many_faces_logger`, `many_faces_mobile`).

| Script                              | Purpose                                                                                                                                                                                                                         |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`scripts/ci-local.sh`**           | One entrypoint: **lint-all** → **build-all** → **test-all**. Sets `SKIP_CYPRESS=1` unless you override. Includes **`many_faces_mobile`** when present (`yarn` scripts after **`yarn install --immutable`** in CI; locally reuse `node_modules` if already installed). |
| **`scripts/lint-all.sh`**           | Calls `many_faces_portal`, `many_faces_backend`, `many_faces_admin`, **`many_faces_mobile`** (`./scripts/lint.sh`: ESLint + Prettier check + `tsc`), `many_faces_ai` `./scripts/lint.sh` (FE/admin: `yarn validate`; BE: `dotnet format`; AI: Ruff). |
| **`scripts/build-all.sh`**          | `many_faces_backend`: `dotnet build -c Release`; `many_faces_portal` / `many_faces_admin`: `yarn build`; **`many_faces_mobile`**: `./scripts/build.sh` (`tsc` + `expo-doctor`); `many_faces_ai`: **`./scripts/verify-ci.sh`**. |
| **`scripts/test-all.sh`**           | `dotnet test` (BE), `yarn test` (FE/admin), **`many_faces_mobile`** `./scripts/test.sh` (Jest / `jest-expo`), **`many_faces_ai/scripts/verify-ci.sh`**, optional Cypress e2e unless `SKIP_CYPRESS=1`. |
| **`scripts/status-all.sh`**         | Docker / HTTP status of dev containers (does not run builds).                                                                                                                                                                   |
| **`scripts/format-all-doc.sh`**     | Prettier over all `*.md` / `*.mdx` (respects **`.prettierignore`**). Use **`--check`** for a no-write verify. Does **not** validate Mermaid syntax inside fences.                                                               |
| **`scripts/check-mermaid-docs.sh`** | Python walker + **`npx @mermaid-js/mermaid-cli`** (`mmdc`): each **mermaid** fence must render. Slower (Chromium); run before large doc merges. **`docs_mermaid`** CI job runs this. Not included in **`scripts/ci-local.sh`**. |

**Dev stack:** `scripts/start-all-dev.sh`, `scripts/stop-all-dev.sh`, `scripts/clear-all-dev.sh`, `scripts/rebuild-all-dev.sh`, `scripts/restart-all-dev.sh`, `scripts/start-missing-dev.sh`, `scripts/menu.sh`.

**`many_faces_ai/scripts/verify-ci.sh`**: local venv `.venv-ci-verify/`, gRPC stub generation, ruff, pytest — aligned with the **many_faces_ai** GitHub Actions job (no PyTorch).

### Diagram: ci-local chain

```mermaid
flowchart TB
  CLI[scripts/ci-local.sh]
  L[scripts/lint-all.sh]
  B[scripts/build-all.sh]
  T[scripts/test-all.sh]
  CY{SKIP_CYPRESS}
  CLI --> L --> B --> T
  T -->|default 1| SkipCy[Skip Cypress]
  CY -.-> T

  classDef apiFill fill:#fff3e0,stroke:#ef6c00
  class CLI,L,B,T apiFill
```

### Submodule-only repos

Each of `many_faces_backend`, `many_faces_portal`, `many_faces_admin`, **`many_faces_mobile`**, `many_faces_ai`, `many_faces_database`, `many_faces_redis`, `many_faces_logger` includes its own **CI** workflow for development outside the monorepo.

## Authentication, JWT, and “stay signed in” (`rememberMe`)

**Purpose:** Users log in through **`POST /api/oauth2/token`** (password grant). The optional **`rememberMe`** flag does **not** create a separate session type — it only selects a **longer JWT lifetime** from configuration (`Jwt:ExpiresInMinutesRememberMe` vs `Jwt:ExpiresInMinutes`). Both **`many_faces_portal`** and **`many_faces_admin`** store the access token in **`localStorage`**, decode **`exp`** in **`jwtUtils.isTokenExpired`**, and clear storage when the token is invalid so the UI matches API **401** behaviour.

**Why it matters:** Misunderstanding `rememberMe` leads to wrong ops expectations. With **`rememberMe: true`**, the API issues a **longer-lived access JWT**; **refresh tokens** are also supported server-side (rotation, single-use) — see `OAuthRefreshTokenStore` and [acl-and-capabilities.md](./acl-and-capabilities.md).

**Detailed guides (tables, file map, curl, tests):**

- [**authentication-and-sessions.md**](./authentication-and-sessions.md)
- Curl register/token (includes `rememberMe` example): [**api-oauth-stories-curl.md**](./api-oauth-stories-curl.md)

**Tests (auth slice):** `BeDemo.Api.Tests/OAuth2RememberMeTests.cs`; `many_faces_portal` / `many_faces_admin` — `src/utils/__tests__/jwtUtils.test.ts`, `src/hooks/api/__tests__/authTokenRequest.test.ts`.

## ACL, capabilities, and permission keys

**Purpose:** The UI should not re-implement authorization rules from JWT claims alone. The API exposes computed flags via **`GET /{face}/api/me/capabilities`**; **many_faces_portal** and **many_faces_admin** mirror permission strings in **`src/acl/`** and load data through **`fetchMeCapabilities`** + **`useMeCapabilities`** (React Query), with cache invalidation tied to login / logout / refresh in **`useAuthApi`**.

**Detailed reference (API shape, key catalog, file map, integration test users, list of test files):** [**acl-and-capabilities.md**](./acl-and-capabilities.md).  
**ACL / capabilities (operational):** [**acl-and-capabilities.md**](./acl-and-capabilities.md).

## API error messages in the browser

User-facing fetch wrappers use **`getApiErrorMessage`** (`many_faces_portal` / `many_faces_admin`: `src/utils/apiErrorMessage.ts`):

- Parses JSON bodies: `{ "error": "..." }`, ASP.NET **ProblemDetails** (`detail`, then `title`), and flat **`errors`** maps (validation).
- Non-JSON bodies shorter than ~280 characters are shown as plain text; longer bodies fall back to a generic message.

**Backend**: many endpoints return `new { error = "..." }` or ProblemDetails; both are covered.

## Testing (quick reference)

| Suite | Command                              | Notes                                                                                                                                                                                                                                                                                                                       |
| ----- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BE    | `dotnet test` in `many_faces_backend`           | Integration tests; `Testing` environment where configured. Includes **`OAuth2RememberMeTests`** (JWT TTL vs `rememberMe`), **`AclIntegrationTests`**, **`AclBearerJwtValidationTests`** (expired/malformed JWT), **`AccessCapabilitiesServiceTests`**, **`PlatformAccessRulesTests`**, **`FaceRoleSelfServiceRulesTests`**. |
| FE    | `yarn test` in `many_faces_portal`             | Vitest. Auth: **`jwtUtils`**, **`authTokenRequest`**. ACL: **`src/acl/__tests__`**, **`meCapabilitiesClient`**, **`useMeCapabilities`**, **`facePathRouting`** (includes `/api/me/capabilities`).                                                                                                                           |
| Admin | `yarn test` in `many_faces_admin`          | Vitest. Same patterns; plus **`faceApiRouting_acl`**, **`meCapabilitiesClient`**, **`useMeCapabilities`**.                                                                                                                                                                                                                  |
| AI    | `pytest test_server.py` in `many_faces_ai` | After proto generation; `PYTHONPATH=.`                                                                                                                                                                                                                                                                                      |

Wall ticket API behaviour: [wall-tickets.md](./wall-tickets.md).

## Face home grid & seeded sample content (FE + BE)

The **page grid** on a face home page (`PageGridLayout` + `many_faces_portal/src/components/grid/*`) supports **single**, **grid**, and **carousel** display modes per component type (Ad, Album, Blog, ChatRoom, UserProfile, Story, Reel).

### Data sources (authenticated, scoped by selected face)

| Type             | Source                                                                      | Notes                                                                               |
| ---------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Ad**           | `GET /api/faces/{faceId}/wall-tickets` (paged; FE may fetch multiple pages) | Listing-style UI; image is a **placeholder** (picsum) — tickets have no image URL.  |
| **Album**        | `GET /api/Albums?faceId=`                                                   | Cover is placeholder by album id; album has no cover field on API.                  |
| **Blog**         | `GET /api/Blogs?faceId=`                                                    | Uses first blog image when present.                                                 |
| **Chat room**    | `GET /api/faces/{faceId}/chat-rooms`                                        | Single tile: first room or `boundChatRoomId` from grid JSON.                        |
| **User profile** | `GET /api/faces/{faceId}/profiles` (paged; FE aggregates pages)             | Directory lists **non-host** face roles; links use `/{faceIndex}/profile/{userId}`. |
| **Story**        | `GET /api/stories?faceId=`                                                  | Published, non-expired, targeted to face; links to `/{faceIndex}/stories`.          |
| **Reel**         | `GET /api/Reels?faceId=`                                                    | Standard reel list filter.                                                          |

### Diagram: face grid tile data sources

```mermaid
flowchart LR
  Ad[Ad] --> W[GET wall-tickets paged]
  Album[Album] --> A[GET Albums faceId]
  Blog[Blog] --> B[GET Blogs faceId]
  Chat[Chat room] --> C[GET chat-rooms]
  Prof[User profile] --> P[GET profiles paged]
  Story[Story] --> S[GET stories faceId]
  Reel[Reel] --> R[GET Reels faceId]
```

**Pagination**: grid/carousel components compute **items per page** from container size; **`ComponentBlock`** footer prev/next is **wired** via `page` / `onPageChange` from `PageGridLayout` for all modes that declare a footer.

### Database seeding (`DatabaseSeeder`)

After **`SeedUsersAsync`** (seeded `@demo.com` users), **`SeedFaceGridContentAsync`** runs (non-fatal on failure):

- For **each** seeded user and **each** face, ensures **5** items per content class: wall tickets, albums (+ `AlbumFace`), blogs (+ image), reels (+ `ReelFace`), **published** stories (+ `StoryFace` + image), `FaceChatRoom`.
- **Regular** seeded users (`user01@demo.com` …) are normalized to **`FACE_USER`** per face (not `FACE_HOST`) so the **profile directory** is populated; **admins** stay **`FACE_HOST`** for moderation semantics.
- Logic is **idempotent** (counts per user+face, fills up to 5).

Implementation: `many_faces_backend/BeDemo.Api/Scripts/DatabaseSeeder.cs`; invoked from `Program.cs` after user seed in non-Testing environments.

### Diagram: seeding loops (idempotent)

```mermaid
flowchart TB
  Users[SeedUsersAsync seeded users]
  Grid[SeedFaceGridContentAsync]
  Loop[For each seeded user and each face]
  Five[Up to 5 items per content class]
  Classes[Wall Album Blog Reel Story ChatRoom]
  Users --> Grid
  Grid --> Loop
  Loop --> Five
  Five --> Classes
  Note1[Regular users FACE_USER for directory]
  Note2[Admins stay FACE_HOST]

  classDef dbFill fill:#e8f5e9,stroke:#2e7d32
  class Users,Grid,Loop,Five dbFill
```

## Functionality gaps (intentional / backlog)

Not implemented in this baseline (see also **Future** in [wall-tickets.md](./wall-tickets.md)):

- **Security / ops hardening**: rate limiting, strict CORS policy tuning (deferred).
- **Face-level moderators** (only global Admin/SuperAdmin for wall moderation today).
- **Notifications** for ticket state changes, **reports**, rich moderation filters.
- **Cancelling** delayed deny deletion jobs if workflow changes; configurable retention vs fixed 2 days.

i18n: wall and settings strings exist for **en / sk / cz**; other app areas may still be English-only — extend `src/i18n/locales` as needed.

## Related docs

- [**`docs/README.md`**](../README.md) — documentation hub.
- [authentication-and-sessions.md](./authentication-and-sessions.md) — login, JWT, `rememberMe`, config, FE/admin, tests, security.
- [wall-tickets.md](./wall-tickets.md) — feature behaviour, API tables, Redis worker, manual checks.
- [chat-rooms-testing-and-operations.md](./chat-rooms-testing-and-operations.md) — chat / rooms operations.
- [api-oauth-stories-curl.md](./api-oauth-stories-curl.md) — OAuth2 + Stories curl walkthrough.
- [acl-and-capabilities.md](./acl-and-capabilities.md) — capabilities API, permission keys, FE/admin wiring, tests.
- [redis-subrepo.md](../readmes/redis-subrepo.md) — Redis submodule.
- [fe-portal-overview.md](../readmes/fe-portal-overview.md) / [admin-portal-overview.md](../readmes/admin-portal-overview.md) — FE / admin extended overviews.
- [git-submodules.md](./git-submodules.md) — submodule checkout and updates.
- [security-crypto-sockets.md](./security-crypto-sockets.md) — TLS, JWT keys, WebSockets backlog.
