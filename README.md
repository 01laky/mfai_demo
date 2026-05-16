# Many Faces AI (MFAI) - monorepo

Many Faces AI is a full-stack social platform built around the concept of **faces**: configurable community spaces with their own pages, roles, content, chats, stories, profiles, listings, albums, blogs, reels, and AI-assisted features.

The project shows how a modern social product can be assembled from reusable building blocks: dynamic page grids, role-aware user flows, media-rich content, real-time communication, profile directories, public and private spaces, admin-managed structure, and backend-enforced data separation between faces.

The monorepo includes the customer-facing frontend, the admin portal, the mobile shell (Expo), the backend API, AI services, PostgreSQL and Redis infrastructure, **nested `many_faces_proto` git submodules** inside each gRPC consumer for **canonical `.proto` contracts**, **Elasticsearch** search tooling (`many_faces_elastic`), an **FCM push worker** (`many_faces_push`), a **transactional mailer worker** (`many_faces_mailer`, Java gRPC + SMTP templates)—all started together by `./scripts/start-all-dev.sh` unless you set **`ENABLE_ELASTICSEARCH=0`**, **`ENABLE_PUSH_WORKER=0`**, or **`ENABLE_MAILER_WORKER=0`**—Docker-based local orchestration, development scripts, documentation, and reusable AI-agent prompts that help continue implementation work consistently.

It is designed both as a runnable local reference stack and as an engineering playground for experimenting with configurable social experiences, face-specific content, access rules, media workflows, real-time features, and AI-powered interactions. Each app is its own **git submodule**.

**GitHub:** this tree is the **`many_faces_main`** repository; submodule remotes use the `many_faces_*` names (backend, portal, admin, mobile, ai, database, redis, logger, **elastic**, **push**, **mailer**). Shared wire contracts live in **nested** **`many_faces_proto`** inside those consumer repos (not as a separate top-level submodule). Local directory names stay `many_faces_backend/`, `many_faces_portal/`, … — see [`.gitmodules`](./.gitmodules) and [`docs/guides/git-submodules.md`](./docs/guides/git-submodules.md).

Security and trust boundaries are a high priority in the architecture: this stack uses OAuth2/JWT authentication, signed access tokens, refresh-token based sessions, role-aware access control, capability-based UI flows, backend-enforced checks for face-specific data, protected admin operations, HTTPS-oriented local development, and documented crypto/TLS hardening work. Token handling covers signed JWTs, refresh-token rotation, server-side validation, explicit expiry handling, and protected API boundaries; the documentation also calls out key/certificate handling, hashing/encryption decisions, and future hardening work. The goal is to keep access rules and sensitive behavior explicit across the frontend, admin portal, and backend API, so the system remains understandable, reviewable, and safer to extend.

## What this stack covers

- Configurable **faces** with their own routes, pages, roles, visual identity, and content.
- Dynamic page grids managed from the admin portal and rendered by reusable frontend blocks.
- Social modules for profiles, albums, blogs, reels, stories, wall listings, chats, comments, likes, follows, blocks, and notifications.
- Real-time and asynchronous features through SignalR, Redis-backed infrastructure, and an AI gRPC service.
- Role-aware frontend flows backed by backend authorization and explicit capability checks.
- A Docker-first local environment that brings the API, SPAs, PostgreSQL, Redis, **Elasticsearch + search-worker**, **push-worker**, **mailer-worker**, logging, and AI service up together via `./scripts/start-all-dev.sh` (set **`ENABLE_ELASTICSEARCH=0`**, **`ENABLE_PUSH_WORKER=0`**, or **`ENABLE_MAILER_WORKER=0`** to skip any of those workers).
- Long-lived documentation and agent prompts that preserve architectural context and implementation checklists.
- AI-assisted content approval for user-created albums, blogs, and reels: **My submissions** and detail `?edit=1` on the user app, Redis-backed AI review jobs, **sanitization and prompt-injection defenses** on the path to gRPC `ReviewContent` (also in `many_faces_ai`), superadmin moderation with **filters, metrics, alerts, bulk actions**, in-app **notifications**, optional **retention** redaction of internal AI fields, and a full **audit** trail. Reference: [`docs/guides/ai-assisted-content-approval.md`](./docs/guides/ai-assisted-content-approval.md).
- **Admin operator dashboard + optional AI statistics:** consolidated **`GET /api/Stats`** / **`timeseries`**, anonymous aggregate **`GET /api/Stats/public`** (via **`public`** face prefix), **Settings** modes (**off / inline / live**) for attaching totals to **SignalR** admin AI chat, and gRPC **`stats_context_json`** / **`FetchPublicStats`** / **`OperatorStatsChat`** in **`many_faces_ai`**. Reference: [`docs/guides/admin-dashboard-metrics.md`](./docs/guides/admin-dashboard-metrics.md) and [`docs/prompts/admin-ai-public-stats-operator-chat-agent-prompt.md`](./docs/prompts/admin-ai-public-stats-operator-chat-agent-prompt.md).

## Elasticsearch & search-worker (`many_faces_elastic`)

This monorepo runs a **search projection** beside PostgreSQL when you use the full dev stack: **`many_faces_elastic`** is a separate git submodule that ships **Elasticsearch** (read-optimized index) and a colocated **Go gRPC search-worker**. **PostgreSQL stays the system of record**; browsers, SPAs, and the mobile app **never** call Elasticsearch or the worker directly—they only call **`many_faces_backend`** REST APIs.

- **Submodule & code:** [`many_faces_elastic/README.md`](./many_faces_elastic/README.md) (Docker Compose, `Dockerfile.search-worker`, `proto/`, `cmd/search-worker`, CI).
- **Feature overview (TLS, smoke, CI, tests):** [`docs/guides/elasticsearch-search-features-overview.md`](./docs/guides/elasticsearch-search-features-overview.md).
- **Local wiring (ports, env, Docker DNS, skip with `ENABLE_ELASTICSEARCH=0`):** [`docs/guides/elasticsearch-local-dev.md`](./docs/guides/elasticsearch-local-dev.md).
- **Backend config:** `Search__Enabled`, `Search__WorkerGrpcUrl` (e.g. `http://search-worker-dev:50052` on the dev Docker network, or `https://…` with TLS), optional `Search__WorkerAuthToken`, optional TLS paths (`Search__WorkerTlsServerCaPath`, `Search__WorkerTlsClientCertPath`, `Search__WorkerTlsClientKeyPath`, `Search__WorkerGrpcTlsServerName`); health probe: **`GET /{face-prefix}/api/search/health`**. TLS guide: [`docs/guides/elasticsearch-grpc-tls-mtls.md`](./docs/guides/elasticsearch-grpc-tls-mtls.md).
- **Agent checklist / roadmap:** [`docs/prompts/elasticsearch-search-infra-agent-prompt.md`](./docs/prompts/elasticsearch-search-infra-agent-prompt.md).

**Trust boundary (who talks to whom):**

```mermaid
flowchart LR
    subgraph clients["Clients never touch Elasticsearch or worker gRPC"]
        portal["many_faces_portal"]
        admin["many_faces_admin"]
        mobile["many_faces_mobile"]
    end
    be["many_faces_backend<br/>REST + JWT"]
    worker["Go search-worker<br/>many_faces_elastic<br/>gRPC :50052 / host :59202"]
    es["Elasticsearch<br/>HTTP :9200 / host :59200"]

    portal --> be
    admin --> be
    mobile --> be
    be -->|"Grpc.Net.Client<br/>when Search enabled"| worker
    worker -->|"official Go client<br/>only inside this submodule"| es
```

**Plain-text equivalent:** `portal | admin | mobile` → **HTTP** → `many_faces_backend` → **gRPC** → `search-worker` → **HTTP** → `Elasticsearch`.

## Push worker / FCM (`many_faces_push`)

**`many_faces_push`** is a separate git submodule implementing a **Go gRPC worker** that isolates **Firebase Admin / FCM** dispatch from **`many_faces_backend`**. The API persists device tokens and calls **`PushService.SendPush`** over gRPC.

- **Submodule:** [`many_faces_push/README.md`](./many_faces_push/README.md)
- **Local dev:** [`docs/guides/push-notifications-local-dev.md`](./docs/guides/push-notifications-local-dev.md) — copy **[`dev/push-dev.env.example`](./dev/push-dev.env.example)** hints into a root **`.env`** when using Docker Compose substitution.
- **Full dev stack:** `./scripts/start-all-dev.sh` starts the push worker by default; set **`ENABLE_PUSH_WORKER=0`** to skip. Place Firebase **service account** JSON at **`many_faces_push/firebase-sa.json`** (or set **`FIREBASE_SA_HOST_PATH`**) so the worker gets a bind mount and **`GOOGLE_APPLICATION_CREDENTIALS`** automatically.
- **Roadmap / checklist:** [`docs/prompts/push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md`](./docs/prompts/push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md)

## Mailer worker (`many_faces_mailer`)

**`many_faces_mailer`** is a **Java gRPC** worker that renders **localized HTML/text** templates and sends mail over **SMTP** (Mailpit in dev). **`many_faces_backend`** calls **`IMailerWorkerClient.SendTemplatedEmail`** directly for **email + code registration** (`account_registration_code`); optional **TLS/mTLS** matches the push/search worker pattern. See [`docs/guides/email-code-registration.md`](./docs/guides/email-code-registration.md).

- **Submodule:** [`many_faces_mailer/README.md`](./many_faces_mailer/README.md)
- **Local dev:** [`docs/guides/mailer-local-dev.md`](./docs/guides/mailer-local-dev.md) — Mailpit, `Mail:*`, grpcurl; TLS: [`docs/guides/mailer-grpc-tls-mtls.md`](./docs/guides/mailer-grpc-tls-mtls.md). Example env: [`dev/mail-dev.env.example`](./dev/mail-dev.env.example).
- **Full dev stack:** `./scripts/start-all-dev.sh` starts the mailer worker by default; set **`ENABLE_MAILER_WORKER=0`** to skip. Host gRPC **59204** by default; TLS smoke uses **59216** (see smoke script).
- **Spec / checklist:** [`docs/prompts/smtp-mailer-java-grpc-worker-agent-prompt.md`](./docs/prompts/smtp-mailer-java-grpc-worker-agent-prompt.md)

### Architecture (transactional mail — Mermaid)

```mermaid
sequenceDiagram
    autonumber
    participant U as User / ASP.NET Identity
    participant API as many_faces_backend
    participant MW as many_faces_mailer gRPC
    participant S as Mailpit or SMTP relay

    U->>API: Register request / password reset (domain flows)
    API->>API: Build template_id + params (e.g. account_registration_code)
    Note over API,MW: Metadata x-mailer-worker-token optional correlation headers
    API->>MW: SendTemplatedEmail
    MW->>MW: Validate template locale params
    MW->>MW: Pebble render + ResourceBundle i18n
    MW->>S: MIME message
    S-->>MW: Accepted Message-ID optional
    MW-->>API: correlation_id smtp_message_id
```

## Email-code registration (signup)

Public signup is **two-step**: request email → receive **verification code** + link with **`?hash=`** → complete on portal or mobile with password → **OAuth2 tokens** returned (auto-login). Mail uses template **`account_registration_code`** via gRPC (not legacy Identity `IEmailSender`).

```mermaid
flowchart LR
  subgraph clients [Clients]
    portal["many_faces_portal"]
    mobile["many_faces_mobile"]
  end
  api["many_faces_backend"]
  mailer["many_faces_mailer"]
  mailpit["Mailpit / SMTP"]
  portal -->|"register/request"| api
  mobile -->|"register/request"| api
  api -->|"SendTemplatedEmail"| mailer
  mailer --> mailpit
  mailpit -->|"code + link ?hash="| portal
  mailpit -->|"deep link"| mobile
  portal -->|"register/complete + tokens"| api
  mobile -->|"register/complete + tokens"| api
```

- **Guide:** [`docs/guides/email-code-registration.md`](./docs/guides/email-code-registration.md)
- **Agent prompt:** [`docs/prompts/email-code-registration-via-mailer-agent-prompt.md`](./docs/prompts/email-code-registration-via-mailer-agent-prompt.md)
- **Mailer dev:** [`docs/guides/mailer-local-dev.md`](./docs/guides/mailer-local-dev.md)

## System Overview

```mermaid
flowchart LR
    visitor["Users / Members"] --> fe["many_faces_portal<br/>User-facing React SPA"]
    visitor --> mobile["many_faces_mobile<br/>Expo React Native"]
    adminUser["Admins / Operators"] --> admin["many_faces_admin<br/>Admin React SPA"]

    fe --> api["many_faces_backend<br/>ASP.NET Core API"]
    admin --> api
    mobile --> api

    api --> auth["OAuth2 / JWT<br/>roles + capabilities"]
    api --> db["many_faces_database<br/>PostgreSQL"]
    api --> redis["many_faces_redis<br/>Redis"]
    sw["many_faces_elastic<br/>Go search-worker gRPC"]
    esx["many_faces_elastic<br/>Elasticsearch HTTP"]
    sw --> esx
    api -.->|"Search enabled"| sw
    api --> realtime["SignalR<br/>real-time updates"]
    api --> ai["many_faces_ai<br/>Python gRPC + ReviewContent sanitizer"]
    pw["many_faces_push<br/>Go gRPC FCM"]
    mw["many_faces_mailer<br/>Java gRPC + templates"]
    smtp["Mailpit / SMTP relay"]
    api -.->|"Push:Enabled"| pw
    api -.->|"Mail:Enabled"| mw
    mw --> smtp

    scripts["scripts/ + dev/<br/>local orchestration"] --> fe
    scripts --> admin
    scripts --> api
    scripts --> db
    scripts --> redis
    scripts -.->|"start-all-dev (default)"| sw
    scripts -.->|"start-all-dev (default)"| pw
    scripts -.->|"start-all-dev (default)"| mw
    scripts --> ai
    scripts --> mobile
    scripts --> logs["many_faces_logger<br/>container logs"]

    docs["docs/ + APP_CONTEXT.md<br/>guides, prompts, architecture notes"] -.-> fe
    docs -.-> admin
    docs -.-> api
    docs -.-> ai
    docs -.-> mobile
    docs -.-> sw
    docs -.-> pw
    docs -.-> mw
```

### Search index (`many_faces_elastic`)

The **Elasticsearch & search-worker** section above is the primary architecture summary (trust boundary + Mermaid). Below are **operator-focused** reminders.

**Elasticsearch** is a separate submodule used as a **read-optimized search projection** (full-text and faceted queries later). **PostgreSQL** in `many_faces_database` remains the **system of record**. **`./scripts/start-all-dev.sh`** starts Elasticsearch + **search-worker** by default (when submodule scripts exist) and exports **`SEARCH_DEV_*`** so **`be-demo-dev`** gets **`Search__Enabled`** and **`Search__WorkerGrpcUrl`** (e.g. `http://search-worker-dev:50052`) via root **`docker-compose.dev.yml`**. Set **`ENABLE_ELASTICSEARCH=0`** to skip the stack; optional **`Search__WorkerAuthToken`** must match **`SEARCH_WORKER_EXPECTED_TOKEN`** on the worker when set (see [`docs/guides/elasticsearch-search-features-overview.md`](./docs/guides/elasticsearch-search-features-overview.md), [`docs/guides/elasticsearch-local-dev.md`](./docs/guides/elasticsearch-local-dev.md), [`docs/guides/elasticsearch-grpc-tls-mtls.md`](./docs/guides/elasticsearch-grpc-tls-mtls.md), and [`many_faces_elastic/README.md`](./many_faces_elastic/README.md)). Probe connectivity with **`GET /{face-prefix}/api/search/health`**. Agent checklist: [`docs/prompts/elasticsearch-search-infra-agent-prompt.md`](./docs/prompts/elasticsearch-search-infra-agent-prompt.md).

For how this submodule fits root **`docker-compose.dev.yml`** and lifecycle scripts, see [`docs/guides/docker-and-compose.md`](./docs/guides/docker-and-compose.md). When search containers misbehave (network attach, ports **59200** / **59202**, or gRPC `Unavailable`), use [`docs/guides/troubleshooting-local-dev.md`](./docs/guides/troubleshooting-local-dev.md) together with the Elasticsearch guide above.

```mermaid
flowchart LR
    pg[(PostgreSQL<br/>system of record)]
    es[(Elasticsearch<br/>read index)]
    sw2[Go search-worker<br/>gRPC]
    be2[many_faces_backend]

    be2 --> pg
    be2 -.->|Search tier| sw2
    sw2 --> es
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

## Admin operator statistics and optional AI context

Platform operators use **`many_faces_admin`** with the **admin** face URL prefix for **`GET /api/Stats`** (full KPIs and charts). For **optional** AI-assisted explanations in the admin **AI chat**, the stack can attach **aggregate counts only** via **`GET /api/Stats/public`** (callable **without** a JWT only under the **`public`** face prefix). The admin SPA stores **off / inline / live** in **`localStorage`**; **inline** injects JSON from the API process, **live** lets the Python worker **HTTP GET** a configured public URL before **`Generate`**. See [`docs/guides/admin-dashboard-metrics.md`](./docs/guides/admin-dashboard-metrics.md).

```mermaid
flowchart LR
    subgraph Browser["many_faces_admin"]
        set["Settings<br/>off / inline / live"]
        dash2["Dashboard<br/>public snapshot preview"]
        chat2["ChatPage<br/>SignalR"]
    end

    subgraph BE["many_faces_backend"]
        op["GET /api/Stats<br/>operator JWT + admin face"]
        anon["GET /api/Stats/public<br/>no JWT + public face"]
        hub2["ChatHub<br/>SendToAiWithOperatorStats"]
        grpc2["gRPC → many_faces_ai"]
    end

    subgraph Py["many_faces_ai"]
        gen2["Generate + optional stats_context_json"]
    end

    set --> chat2
    dash2 --> anon
    chat2 --> hub2
    hub2 --> op
    hub2 --> anon
    hub2 --> grpc2
    grpc2 --> gen2
```

## Admin Configuration Flow

The admin portal configures the structural data that the backend stores and the user-facing frontend later renders:

```mermaid
flowchart LR
    operator["Admin / Operator"] --> admin["many_faces_admin<br/>React admin panel"]
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
    invalidate --> frontend["many_faces_portal reads schema<br/>PageGridLayout renders blocks"]
```

## Backend Request And Trust Boundary

The backend is the main trust boundary: it resolves face scope, validates signed tokens, enforces roles/capabilities, persists data, and serves typed contracts to both React apps.

```mermaid
flowchart TD
    client["many_faces_portal / many_faces_admin"] --> request["HTTP(S) request<br/>/{face-prefix}/api/... or /api/oauth2/..."]
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
    services -.->|"Search enabled"| swg["many_faces_elastic<br/>search-worker gRPC"]
    services -.->|"Push enabled"| pwg["many_faces_push<br/>gRPC"]
    services -.->|"Mail enabled"| mwg["many_faces_mailer<br/>gRPC"]
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
    admin["many_faces_admin<br/>page/grid editor"] --> pagesApi["PagesController<br/>save gridSchema"]
    pagesApi --> db["PostgreSQL<br/>Pages, Faces, PageTypes"]
    db --> facesApi["FacesController<br/>face config + pages"]
    facesApi --> frontend["many_faces_portal<br/>PageGridLayout"]

    userRequest["/{face-prefix}/api/..."] --> routing["RoutingMiddleware"]
    routing --> trusted["Trusted FaceId<br/>strips spoofed faceId"]
    trusted --> capabilities["/api/me/capabilities<br/>global + face roles"]
    trusted --> social["Face-scoped social APIs<br/>albums, blogs, reels, stories, chats"]
    capabilities --> frontend
    social --> frontend
```

## AI-Assisted Content Approval

Regular users can create albums, blogs, and reels from the user-facing frontend, but the approval workflow keeps that content out of public views until it is approved. The backend owns approval status and visibility, enqueues **asynchronous** AI review work (`content.ai-review` on Redis), **sanitizes untrusted text and URLs before gRPC**, applies an optional **instruction-like** heuristic on stored submissions, validates structured recommendations (including **never auto-approving** when `instruction_like_text` is present), notifies creators and super-admins on key transitions, and restricts approve / reject / remove / bulk / requeue to **`SUPER_ADMIN`**. Creators use **`GET /api/my/content-submissions`** and the **My submissions** page; the admin app exposes the moderation queue with **filters, metrics + alerts, bulk actions**, and per-item audit. Optional **retention** hosting can redact internal AI trace fields after a policy delay. Full reference: [`docs/guides/ai-assisted-content-approval.md`](./docs/guides/ai-assisted-content-approval.md).

```mermaid
flowchart TD
    user["FE user creates<br/>album / blog / reel"] --> api["Backend create endpoint"]
    api --> pending["Store as PendingApproval"]
    pending --> hidden["Exclude from public<br/>grid/list/detail views"]
    pending --> notify1["Notifications<br/>creator + super-admins"]
    pending --> queue["Enqueue Redis job<br/>content.ai-review"]

    queue --> worker["Worker + ContentAiReviewService"]
    worker --> sanitize["Sanitize fields + caps<br/>bidi or control stripping"]
    sanitize --> ai["many_faces_ai ReviewContent<br/>same sanitizer + classifier"]
    ai --> policy["Backend policy<br/>normalize flags, risk, version, instruction guard"]

    policy --> admin["Admin moderation<br/>filters, metrics, bulk"]
    admin --> approve["Approve → public lists"]
    admin --> reject["Reject → safe user message"]
    admin --> remove["Remove → audit retained"]

    super["SUPER_ADMIN"] --> admin

    approve --> public["FE public grids / detail"]
    reject --> mysub["My submissions + detail ?edit=1"]
    pending --> mysub
    remove --> audit["ContentModerationEvents"]
    policy --> audit
    admin --> audit
```

## Architecture Overview

| Layer | Path | Purpose |
| --- | --- | --- |
| User frontend | [`many_faces_portal/`](./many_faces_portal/README.md) | **many_faces_portal** — React SPA for public/private face pages, page grids, social content, profiles, messaging, and user flows. |
| Mobile app | [`many_faces_mobile/`](./many_faces_mobile/README.md) | **many_faces_mobile** — Expo (React Native) client; runs outside Docker Compose (`yarn start` after `corepack enable` + `yarn install`). |
| Admin portal | [`many_faces_admin/`](./many_faces_admin/README.md) | **many_faces_admin** — React SPA for managing faces, pages, grid layouts, roles, admin data, and operational views. |
| Backend API | [`many_faces_backend/`](./many_faces_backend/README.md) | **many_faces_backend** — ASP.NET Core API for auth, face-scoped routes, EF Core data access, SignalR hubs, ACL/capabilities, and social modules. Nested **`many_faces_proto/`** holds gRPC `.proto` contracts for workers + AI. |
| AI service | [`many_faces_ai/`](./many_faces_ai/README.md) | **many_faces_ai** — Python gRPC service used by AI-assisted workflows and health checks. Nested **`many_faces_proto/`** for **`health.proto`**. |
| Data stores | [`many_faces_database/`](./many_faces_database/README.md), [`many_faces_redis/`](./many_faces_redis/README.md), [`many_faces_elastic/`](./many_faces_elastic/README.md), [`many_faces_push/`](./many_faces_push/README.md), [`many_faces_mailer/`](./many_faces_mailer/README.md) | **many_faces_database** + **many_faces_redis** — PostgreSQL and Redis. **many_faces_elastic** — Elasticsearch plus Go **search-worker** (gRPC). **many_faces_push** — **FCM push** worker (gRPC). **many_faces_mailer** — **transactional mail** worker (Java gRPC → SMTP; backend `Mail:*`). All three are started by **`./scripts/start-all-dev.sh`** by default (`ENABLE_*=0` to skip). PostgreSQL stays authoritative. |
| Logging | [`many_faces_logger/`](./many_faces_logger/README.md) | **many_faces_logger** — local log viewing with Dozzle / container log tooling. |
| Orchestration | [`scripts/`](./docs/guides/development.md#monorepo-scripts-scripts), [`dev/`](./dev/README.md) | Local startup, rebuild, lint/test, HTTPS, and Docker orchestration scripts. |
| Documentation | [`docs/`](./docs/README.md) | Guides, component notes, submodule overviews, architecture notes, and reusable implementation prompts. |

## Tech Stack Highlights

- **Backend:** ASP.NET Core, EF Core, OAuth2/JWT, SignalR, OpenAPI, PostgreSQL, Redis, Elasticsearch (search index) + FCM push worker + transactional mailer worker (gRPC) when using full **`./scripts/start-all-dev.sh`** (disable per worker with **`ENABLE_*=0`**).
- **Frontend/Admin/Mobile:** React, Vite, TypeScript, React Router, TanStack Query, i18next, Vitest, Cypress, ESLint; **many_faces_mobile:** Expo, React Native.
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

## Local development access

Local development accounts and passwords are documented in [`docs/guides/local-dev-accounts.md`](./docs/guides/local-dev-accounts.md). Keep local development credentials separate from real secrets; local environment values and certificates are documented under **`docs/guides/`** — start from [`docs/README.md`](./docs/README.md) (Guides table) and [`docs/guides/dev-https.md`](./docs/guides/dev-https.md) for HTTPS and ports.

## Project Status

This is an active Many Faces reference monorepo, not a production deployment. Security, architecture, and hardening work are documented so production-grade decisions remain explicit and reviewable as the system evolves.

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

Backend details: [`many_faces_backend/README.md`](./many_faces_backend/README.md). Other services — see the table in [`docs/readmes/README.md`](./docs/readmes/README.md).

## Layout (short)

```
many_faces_backend/       # many_faces_backend — API (OAuth2, JWT, SignalR, EF Core; nested many_faces_proto)
many_faces_portal/       # many_faces_portal — user-facing SPA
many_faces_mobile/       # many_faces_mobile — Expo React Native
many_faces_admin/    # many_faces_admin — admin SPA
many_faces_database/       # many_faces_database — PostgreSQL compose
many_faces_redis/    # many_faces_redis — job queue
many_faces_elastic/  # many_faces_elastic — Elasticsearch + search-worker (gRPC; start-all-dev default)
many_faces_push/     # many_faces_push — FCM push worker (Go gRPC; start-all-dev default)
many_faces_mailer/   # many_faces_mailer — transactional mailer worker (Java gRPC + SMTP; start-all-dev default)
many_faces_ai/       # many_faces_ai — gRPC health / AI
many_faces_logger/   # many_faces_logger — Dozzle
scripts/       # monorepo orchestration (start-all-dev, ci-local, lint-all, …)
```

**Full script inventory:** [`docs/guides/development.md`](./docs/guides/development.md) (section *Monorepo scripts*) lists `ci-local.sh`, `lint-all.sh`, `build-all.sh`, `test-all.sh`, `format-all-doc.sh`, `check-mermaid-docs.sh`, `audit-monorepo-deps.sh`, dev stack helpers, and how they relate to `.github/workflows/ci.yml`. Prefer updating that guide over growing duplicate tables in this README.

## Quick start

**Requirements:** Docker, Docker Compose, Bash.

```bash
git submodule update --init --recursive
./scripts/start-all-dev.sh
```

**Common ports:** API HTTP `8000`, HTTPS `8001`, FE `8081`, admin `8082`, Seq `5341`, DB `54320`, Elasticsearch HTTP `59200`, search-worker gRPC `59202`, push-worker gRPC `59203`, mailer-worker gRPC `59204` (with default **`./scripts/start-all-dev.sh`**); mailer TLS smoke gRPC `59216` (`many_faces_mailer/scripts/smoke-grpc-tls.sh`). Exact mapping: [`docs/guides/dev-https.md`](./docs/guides/dev-https.md) and submodule READMEs.

**Run all tests:**

```bash
export SKIP_CYPRESS=1   # optional; without it FE may run e2e
./scripts/ci-local.sh   # lint → build → test (same idea as monorepo_scripts in CI)
```

## Other root files (archive / reference)

Some guides were moved under **`docs/guides/`** (git submodules, Husky, boilerplate checklist, proposals). Search by filename in `docs/guides/` or use the hub above.

## License / contributing

Fill in per your project policy.
