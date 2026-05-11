# Many Faces AI (MFAI) - monorepo

MFAI Demo is a full-stack social platform demo built around the concept of **faces**: configurable community spaces with their own pages, roles, content, chats, stories, profiles, listings, albums, blogs, reels, and AI-assisted features.

The project shows how a modern social product can be assembled from reusable building blocks: dynamic page grids, role-aware user flows, media-rich content, real-time communication, profile directories, public and private spaces, admin-managed structure, and backend-enforced data separation between faces.

The monorepo includes the customer-facing frontend, the admin portal, the backend API, AI services, PostgreSQL and Redis infrastructure, Docker-based local orchestration, development scripts, documentation, and reusable AI-agent prompts that help continue implementation work consistently.

It is designed both as a runnable local demo and as an engineering playground for experimenting with configurable social experiences, face-specific content, access rules, media workflows, real-time features, and AI-powered interactions. Each app is its own **git submodule**.

Security and trust boundaries are a high priority in the architecture: the demo uses OAuth2/JWT authentication, signed access tokens, refresh-token based sessions, role-aware access control, capability-based UI flows, backend-enforced checks for face-specific data, protected admin operations, HTTPS-oriented local development, and documented crypto/TLS hardening work. Token handling covers signed JWTs, refresh-token rotation, server-side validation, explicit expiry handling, and protected API boundaries; the documentation also calls out key/certificate handling, hashing/encryption decisions, and future hardening work. The goal is to keep access rules and sensitive behavior explicit across the frontend, admin portal, and backend API, so the system remains understandable, reviewable, and safer to extend.

## What This Demo Shows

- Configurable **faces** with their own routes, pages, roles, visual identity, and content.
- Dynamic page grids managed from the admin portal and rendered by reusable frontend blocks.
- Social modules for profiles, albums, blogs, reels, stories, wall listings, chats, comments, likes, follows, blocks, and notifications.
- Real-time and asynchronous features through SignalR, Redis-backed infrastructure, and an AI gRPC service.
- Role-aware frontend flows backed by backend authorization and explicit capability checks.
- A Docker-first local environment that brings the API, SPAs, PostgreSQL, Redis, logging, and AI service up together.
- Long-lived documentation and agent prompts that preserve architectural context and implementation checklists.

## System Overview

```mermaid
flowchart LR
    visitor["Users / Members"] --> fe["fe_demo<br/>User-facing React SPA"]
    adminUser["Admins / Operators"] --> admin["admin_demo<br/>Admin React SPA"]

    fe --> api["be_demo<br/>ASP.NET Core API"]
    admin --> api

    api --> auth["OAuth2 / JWT<br/>roles + capabilities"]
    api --> db["db_demo<br/>PostgreSQL"]
    api --> redis["redis_demo<br/>Redis"]
    api --> realtime["SignalR<br/>real-time updates"]
    api --> ai["ai_demo<br/>Python gRPC AI service"]

    scripts["scripts/ + dev/<br/>local orchestration"] --> fe
    scripts --> admin
    scripts --> api
    scripts --> db
    scripts --> redis
    scripts --> ai
    scripts --> logs["logger_demo<br/>container logs"]

    docs["docs/ + APP_CONTEXT.md<br/>guides, prompts, architecture notes"] -.-> fe
    docs -.-> admin
    docs -.-> api
    docs -.-> ai
```

## Frontend Route And Grid Rendering

The user-facing frontend turns a face URL and backend-managed page schema into a responsive grid of reusable social components:

```mermaid
flowchart TD
    url["Browser URL<br/>/:facePath/:locale/..."] --> router["React Router<br/>localized route elements"]
    router --> guards["GuestRoute / ProtectedRoute"]
    guards --> face["FaceConfigContext<br/>selectedFace + available faces"]

    face --> api["Typed OpenAPI client<br/>face-aware API requests"]
    api --> backend["Backend API<br/>page + grid schema"]
    backend --> schema["gridSchema JSON<br/>items, breakpoints, cols, rowHeight"]

    schema --> layout["PageGridLayout<br/>parse schema + build responsive layouts"]
    layout --> block["ComponentBlock<br/>shared header, actions, footer, panels"]
    block --> components["Grid components<br/>Album, Blog, Reel, Story, ChatRoom,<br/>UserProfile, Ad + grid/carousel variants"]

    face --> block
    block --> actions["Role/capability-aware actions<br/>create, list, sort/filter, settings"]
```

## Frontend Component Interaction Flow

Grid blocks use the same wrapper and route contract, so list/detail/create behaviour stays consistent across content modules:

```mermaid
flowchart LR
    block["ComponentBlock"] --> render["Render child component<br/>single, grid, or carousel"]

    block --> listBtn["List action"]
    listBtn --> listRoute["/list/:componentTypeId"]
    listRoute --> listPage["ComponentListPage"]

    render --> itemClick["User opens an item"]
    itemClick --> detailRoute["/detail/:componentTypeId/:entityId<br/>or module detail route"]
    detailRoute --> detailPage["ComponentDetailPage<br/>AlbumDetailPage / BlogDetailPage / ReelDetailPage"]

    block --> createBtn["Create action"]
    createBtn --> capabilities{"Allowed for this<br/>face and component?"}
    capabilities -->|yes| topPanel["GridTopPanelContext<br/>openGridCreate"]
    topPanel --> createBody["GridTopPanelContent"]
    createBody --> forms["AlbumForm / BlogForm / ReelForm / ChatRoomForm"]
    forms --> api["Typed API service"]
    api --> refresh["Saved content reloads<br/>or navigates to detail"]

    capabilities -->|no| disabled["Disabled action<br/>localized unavailable message"]
```

## Admin Configuration Flow

The admin portal configures the structural data that the backend stores and the user-facing frontend later renders:

```mermaid
flowchart LR
    operator["Admin / Operator"] --> admin["admin_demo<br/>React admin panel"]
    admin --> auth["ProtectedRoute<br/>OAuth2 / JWT"]
    auth --> caps["/me/capabilities<br/>role + permission state"]

    admin --> users["Users<br/>CRUD + detail/edit"]
    admin --> faces["Faces<br/>community spaces"]
    admin --> pageTypes["Page Types<br/>page classification"]
    admin --> pages["Pages<br/>metadata, paths, index"]

    pages --> translations["Route translations<br/>en / sk / cz"]
    pages --> grid["GridLayoutEditor<br/>responsive schema editing"]

    users --> api["Backend API"]
    faces --> api
    pageTypes --> api
    translations --> api
    grid --> api
    api --> db["PostgreSQL<br/>stored admin data"]
```

## Admin Grid Schema Lifecycle

Admin page edits create and update the `gridSchema` consumed by the frontend as a read-only layout:

```mermaid
flowchart TD
    editPage["EditPagePage"] --> load["Load page + route translations<br/>usePage / usePageRouteTranslations"]
    load --> parse["Parse page.gridSchema JSON"]
    parse --> editor["GridLayoutEditor"]

    editor --> picker["ComponentPickerModal<br/>choose component type"]
    picker --> item["Grid item<br/>componentType, title, icon, bound ids"]
    item --> layout["react-grid-layout<br/>drag, resize, order"]
    layout --> preserve["applyLayoutToSchema<br/>preserve metadata"]

    preserve --> serialize["JSON.stringify(gridSchema)"]
    serialize --> save["updatePage mutation"]
    save --> invalidate["Invalidate page / pages / face queries"]
    invalidate --> frontend["fe_demo reads schema<br/>PageGridLayout renders blocks"]
```

## Backend Request And Trust Boundary

The backend is the main trust boundary: it resolves face scope, validates signed tokens, enforces roles/capabilities, persists data, and serves typed contracts to both React apps.

```mermaid
flowchart TD
    client["fe_demo / admin_demo"] --> request["HTTP(S) request<br/>/{face-prefix}/api/... or /api/oauth2/..."]
    request --> routing["RoutingMiddleware<br/>resolve face prefix + rewrite path"]
    routing --> scope["Trusted face scope<br/>requestFaceID + HttpContext.Items"]
    scope --> auth["JWT Bearer auth<br/>ES512 signature, issuer, audience, lifetime"]
    auth --> session["Session version check<br/>token atv == AccessTokenVersion"]
    session --> acl["Authorization + capabilities<br/>global role + face role"]
    acl --> controllers["Controllers / SignalR hubs"]
    controllers --> services["Domain services<br/>OAuth, faces, pages, social modules"]
    services --> db["PostgreSQL via EF Core"]
    services --> redis["Redis queue/cache infrastructure"]
    services --> ai["Python gRPC AI service"]
    controllers --> dto["Typed DTOs / OpenAPI contracts"]
```

## Backend Security And Token Lifecycle

```mermaid
sequenceDiagram
    participant Client as Frontend/Admin
    participant OAuth as OAuth2Controller
    participant Tokens as OAuth2Service
    participant JWT as OAuthAccessTokenFactory
    participant Refresh as OAuthRefreshTokenStore
    participant DB as PostgreSQL

    Client->>OAuth: password grant
    OAuth->>Tokens: validate OAuth client + user credentials
    Tokens->>JWT: issue ES512 access JWT with atv claim
    JWT->>DB: read role + AccessTokenVersion
    Tokens->>Refresh: create opaque refresh token
    Refresh->>DB: store SHA-256 refresh hash
    OAuth-->>Client: access token + refresh token + expiry

    Client->>OAuth: refresh_token grant
    OAuth->>Tokens: redeem refresh token
    Tokens->>Refresh: rotate single-use refresh token
    Refresh->>DB: revoke old hash + insert new hash
    Tokens->>JWT: issue new signed access JWT
    OAuth-->>Client: new access token + rotated refresh token
```

## Backend Face Scope And Grid Data

```mermaid
flowchart LR
    admin["admin_demo<br/>page/grid editor"] --> pagesApi["PagesController<br/>save gridSchema"]
    pagesApi --> db["PostgreSQL<br/>Pages, Faces, PageTypes"]
    db --> facesApi["FacesController<br/>face config + pages"]
    facesApi --> frontend["fe_demo<br/>PageGridLayout"]

    userRequest["/{face-prefix}/api/..."] --> routing["RoutingMiddleware"]
    routing --> trusted["Trusted FaceId<br/>strips spoofed faceId"]
    trusted --> capabilities["/api/me/capabilities<br/>global + face roles"]
    trusted --> social["Face-scoped social APIs<br/>albums, blogs, reels, stories, chats"]
    capabilities --> frontend
    social --> frontend
```

## AI-Assisted Content Approval

Regular users can create albums, blogs, and reels from the user-facing frontend, but the approval workflow keeps that content out of public views until it is approved. The backend owns the approval status and public visibility rules, creates AI review job records, stores moderation audit events, and enforces that only `SUPER_ADMIN` can approve, reject, or remove submitted content in the current phase. The AI service remains a future structured recommender, while the admin portal now has a first moderation queue for superadmin review. Detailed design: [`docs/guides/ai-assisted-content-approval.md`](./docs/guides/ai-assisted-content-approval.md).

```mermaid
flowchart TD
    user["FE user creates<br/>album / blog / reel"] --> api["Backend create endpoint"]
    api --> pending["Store as PendingApproval"]
    pending --> hidden["Exclude from public<br/>grid/list/detail views"]
    pending --> queue["Queue AI review job"]

    queue --> ai["AI reviewer<br/>bounded queue + structured recommendation"]
    ai --> policy["Backend policy<br/>validate confidence, risk, flags"]

    policy --> admin["Admin moderation queues"]
    admin --> approve["Approve<br/>publicly visible"]
    admin --> reject["Reject<br/>creator sees safe reason"]
    admin --> remove["Remove<br/>audit kept"]

    super["SUPER_ADMIN"] --> admin
    super --> remove

    approve --> public["FE public content views"]
    reject --> creator["Creator status views"]
    remove --> audit["Moderation audit log"]
    policy --> audit
    admin --> audit
```

## Architecture Overview

| Layer | Path | Purpose |
| --- | --- | --- |
| User frontend | [`fe_demo/`](./fe_demo/) | React SPA for public/private face pages, page grids, social content, profiles, messaging, and user flows. |
| Admin portal | [`admin_demo/`](./admin_demo/) | React SPA for managing faces, pages, grid layouts, roles, admin data, and operational views. |
| Backend API | [`be_demo/`](./be_demo/) | ASP.NET Core API for auth, face-scoped routes, EF Core data access, SignalR hubs, ACL/capabilities, and social modules. |
| AI service | [`ai_demo/`](./ai_demo/) | Python gRPC service used by AI-assisted workflows and health checks. |
| Data stores | [`db_demo/`](./db_demo/), [`redis_demo/`](./redis_demo/) | PostgreSQL for persisted application data and Redis for queue/cache-style infrastructure. |
| Logging | [`logger_demo/`](./logger_demo/) | Local log viewing with Dozzle / container log tooling. |
| Orchestration | [`scripts/`](./scripts/), [`dev/`](./dev/) | Local startup, rebuild, lint/test, HTTPS, and Docker orchestration scripts. |
| Documentation | [`docs/`](./docs/) | Guides, component notes, submodule overviews, architecture notes, and reusable implementation prompts. |

## Tech Stack Highlights

- **Backend:** ASP.NET Core, EF Core, OAuth2/JWT, SignalR, OpenAPI, PostgreSQL, Redis.
- **Frontend/Admin:** React, Vite, TypeScript, React Router, TanStack Query, i18next, Vitest, Cypress, ESLint.
- **AI/infra:** Python gRPC service, Docker Compose, local HTTPS tooling, log viewer, Bash orchestration scripts.
- **Quality:** linting, type checks, unit tests, narrow integration tests, local CI script, documented security and dependency audit prompts.

## Security Highlights

- OAuth2/JWT authentication with signed access tokens and refresh-token based sessions.
- Explicit JWT expiry handling, server-side validation, protected API boundaries, and documented token flows.
- Role-aware access control and capability-based UI behaviour for user-facing and admin workflows.
- Backend-enforced checks for face-specific data access, protected admin operations, and documented ACL/capability APIs.
- HTTPS-oriented local development, TLS/key/certificate notes, hashing/encryption decisions, and a tracked hardening backlog.
- Repeatable validation through linting, type checks, automated tests, and CI-style local scripts.

## How To Review The Repo

1. Start with this README for the product and architecture overview.
2. Open [`docs/README.md`](./docs/README.md) for the documentation hub.
3. Read [`APP_CONTEXT.md`](./APP_CONTEXT.md) for the current product and engineering north star.
4. Use [`docs/readmes/README.md`](./docs/readmes/README.md) to jump into each submodule.
5. Check [`docs/prompts/README.md`](./docs/prompts/README.md) for long-lived implementation prompts and active engineering checklists.

## Demo Access

Demo users and passwords are documented in [`docs/guides/demo-users-and-passwords.md`](./docs/guides/demo-users-and-passwords.md). Keep demo credentials separate from real secrets; local environment values and certificates are documented under [`docs/guides/`](./docs/guides/).

## Project Status

This is an active demo codebase, not a production deployment. Security, architecture, and hardening work are documented so production-grade decisions remain explicit and reviewable as the system evolves.

## Documentation (start here)

**[`docs/README.md`](./docs/README.md)** — hub: `guides/`, `components/`, `prompts/`, `readmes/`.  
Folder layout: [`docs/STRUCTURE.md`](./docs/STRUCTURE.md).  
Development, CI, scripts: [`docs/guides/development.md`](./docs/guides/development.md).

### Quick links

| Topic                     | Document                                                                                     |
| ------------------------- | -------------------------------------------------------------------------------------------- |
| Auth / JWT / `rememberMe` | [`docs/guides/authentication-and-sessions.md`](./docs/guides/authentication-and-sessions.md) |
| ACL / capabilities API    | [`docs/guides/acl-and-capabilities.md`](./docs/guides/acl-and-capabilities.md)               |
| OAuth2 + Stories (curl)   | [`docs/guides/api-oauth-stories-curl.md`](./docs/guides/api-oauth-stories-curl.md)           |
| Git submodules            | [`docs/guides/git-submodules.md`](./docs/guides/git-submodules.md)                           |
| Local HTTPS (`dev/`)      | [`docs/guides/dev-https.md`](./docs/guides/dev-https.md)                                     |
| TLS / crypto backlog      | [`docs/guides/security-crypto-sockets.md`](./docs/guides/security-crypto-sockets.md)         |
| Submodule README index    | [`docs/readmes/README.md`](./docs/readmes/README.md)                                         |

Backend details: [`be_demo/README.md`](./be_demo/README.md). Other services — see the table in [`docs/readmes/README.md`](./docs/readmes/README.md).

## Layout (short)

```
be_demo/       # API (OAuth2, JWT, SignalR, EF Core)
fe_demo/       # User-facing SPA
admin_demo/    # Admin SPA
db_demo/       # PostgreSQL compose
redis_demo/    # Redis (job queue)
ai_demo/       # gRPC health / AI
logger_demo/   # Dozzle
scripts/       # monorepo orchestration (start-all-dev, ci-local, lint-all, …)
```

## Quick start

**Requirements:** Docker, Docker Compose, Bash.

```bash
git submodule update --init --recursive
./scripts/start-all-dev.sh
```

**Common ports:** API HTTP `8000`, HTTPS `8001`, FE `8081`, admin `8082`, Seq `5341`, DB `54320`. Exact mapping: [`docs/guides/dev-https.md`](./docs/guides/dev-https.md) and submodule READMEs.

**Run all tests:**

```bash
export SKIP_CYPRESS=1   # optional; without it FE may run e2e
./scripts/ci-local.sh   # lint → build → test (same idea as monorepo_scripts in CI)
```

## Other root files (archive / reference)

Some guides were moved under **`docs/guides/`** (git submodules, Husky, boilerplate checklist, proposals). Search by filename in `docs/guides/` or use the hub above.

## License / contributing

Fill in per your project policy.
