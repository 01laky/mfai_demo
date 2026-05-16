# Many Faces — Push notifications (FCM) — Go gRPC Firebase worker — Agent prompt

**Language:** All **new** prose you add to repositories (README, guides, comments in new code) must be **English**.

**Mission:** Introduce **mobile push notifications** for the Many Faces stack using **Firebase Cloud Messaging (FCM)** as the delivery channel to **Expo / React Native** clients (`many_faces_mobile`), while keeping **Firebase credentials and FCM send logic** isolated in a **new standalone git submodule** implemented as a **Go gRPC server** (internal **“push worker”** / **FCM dispatcher**). **`many_faces_backend`** remains the **system of record** for users, devices, notification intent, and authorization; it talks to the push worker **only via gRPC**. **Browsers, mobile apps, and third parties** must **never** call the push worker directly. **Token and API path** (direct FCM vs Expo Push API) must follow **§1.1** once chosen for v1.

**Canonical precedent:** Mirror the **Elasticsearch + Go `search-worker`** pattern documented in [`elasticsearch-search-infra-agent-prompt.md`](./elasticsearch-search-infra-agent-prompt.md) and the existing **`many_faces_elastic`** submodule: dedicated infra repo, `docker-compose.yml`, `README.md`, optional CI, and **monorepo compose / network / documentation** alignment.

**Explicit non-goals for v1 (unless product reopens scope):**

- **No** in-app notification center schema or full product notification taxonomy — ship a **minimal vertical slice**: register device token, send one well-defined notification class end-to-end, handle invalid tokens.
- **No** SMS, email, or web push in this prompt — **FCM to native mobile only** (Android + iOS via FCM’s APNs integration).
- **No** public REST API on the push worker — **gRPC only** to trusted internal callers (`many_faces_backend` first; `many_faces_ai` or workers later if needed).
- **No** replacement of PostgreSQL with Firebase for domain data — Firebase is a **transport credential + FCM API** concern only.

---

## 1. Context — Why a separate Go worker

Many Faces is a **face-scoped social platform** (`many_faces_main` monorepo): ASP.NET Core API (`many_faces_backend`), React SPAs, Redis-backed jobs, Python gRPC AI (`many_faces_ai`), optional Go gRPC Elasticsearch worker (`many_faces_elastic`), PostgreSQL, and **Expo** mobile (`many_faces_mobile`).

**FCM sending** requires **Google service account credentials** (Firebase Admin) and careful **quota, retry, and error semantics** (unregistered tokens, throttling). Isolating that in a **small Go process**:

1. **Reduces blast radius** — compromise of the main API process does not automatically expose Firebase credentials.
2. **Matches operational reality** — same deploy model as **`many_faces_elastic`**: internal address, TLS/mTLS optional phases, health checks, structured logs.
3. **Keeps backend thin** — .NET decides **who** gets **what** and **when**; Go worker’s job is **reliable dispatch** to FCM with observability.

**Expo note:** Client apps obtain **push tokens** via **`expo-notifications`** (and EAS/project configuration). The **mobile app registers the token with `many_faces_backend` over HTTPS** (existing auth session or device-specific flow). The mobile app does **not** open gRPC to the push worker.

### §1.1 Token transport (required clarity)

Expo often exposes an **`ExponentPushToken[...]`** intended for **Expo’s Push Notification service** (separate HTTP API and credentials), which is **not** the same as a raw **FCM registration token** consumed by **Firebase Admin SDK → FCM HTTP v1** from this prompt’s Go worker. **Pick one v1 path and document it in `many_faces_push/README.md` and `docs/guides/push-notifications-local-dev.md` before implementation:** (A) **Direct FCM** — mobile obtains a token Firebase Admin can send to (per current Expo SDK docs for your EAS profile), worker uses Firebase Admin only; or (B) **Expo Push API** — backend or a different component calls Expo’s HTTP API instead, and this prompt’s **Go + Firebase Admin** worker is **not** the right transport (revise architecture). Do **not** mix A and B without an explicit compatibility layer.

---

## 2. Naming and repository boundary

### 2.1 Submodule name (required decision)

Pick **one** public name and use it consistently in **`.gitmodules`**, paths, Docker service names, env vars, and docs. Suggested default:

```text
many_faces_push/
```

Alternatives (`many_faces_fcm`, `many_faces_notifications`) are acceptable if you rename **everywhere** in the same PR series.

### 2.2 Worker binary / container name (required)

Choose a stable Docker Compose **service name** (e.g. **`push-worker`**) and gRPC **internal port** that **does not collide** with:

- **`many_faces_ai`** gRPC (commonly `50051` in docs/examples)
- **`many_faces_elastic`** search worker (e.g. `50052` in examples)

Document the chosen **internal port** and **host-mapped debug port** in submodule `README.md` and monorepo `docker-compose.dev.yml` / guides.

---

## 3. New submodule repository — `many_faces_push` (illustrative)

### 3.1 Submodule mount path (required)

Add a **separate GitHub repository** and link it as a **git submodule** at:

```text
many_faces_push/
```

Follow [`docs/guides/git-submodules.md`](../guides/git-submodules.md) conventions used by sibling infra repos.

### 3.2 Minimum repository layout (required)

| Path | Purpose |
| ---- | ------- |
| `README.md` | Architecture: backend ↔ gRPC ↔ worker ↔ FCM; **non-goals**; ports; how credentials are injected; security model (section 6); link to monorepo guide once added (`docs/guides/push-notifications-local-dev.md` or agreed name). State explicitly: **no browser/mobile traffic** to this service. |
| `docker-compose.yml` | **`push-worker`** service (Go) for local dev; optional **Firebase Emulator** only if you explicitly scope emulator support in v1 — default v1 may target **real FCM** in dev with a test Firebase project (document risks and guardrails). |
| `Dockerfile` | Multi-stage **Go** build, non-root user where practical, minimal runtime image. |
| `proto/` | **Canonical** `.proto` definitions for **`PushService`** (or agreed package name), versioned (`v1`). Document how **`many_faces_backend`** consumes generated C# (same pattern as search protos: copy, `buf`, or submodule path — **one** approach, enforced in CI). |
| `cmd/push-worker/` (or `cmd/fcm-worker/`) | `main`: config load, gRPC server, signal handling, graceful shutdown, structured JSON logs. |
| `internal/...` | gRPC service implementation, FCM client adapter, retries, redaction helpers — **no** business rules that belong in the backend (face ACL, “should user X see Y”). |
| `go.mod` / `go.sum` | Minimal dependencies; prefer official **Firebase Admin SDK for Go** for FCM where appropriate. |
| `.env.example` | **`GRPC_LISTEN`**, paths or env for **service account JSON** (or workload-identity placeholders), log level, optional **shared secret / mTLS** placeholders — **no** real secrets. |
| `.gitignore` | Ignore `.env`, `*.json` key dumps, `bin/`, IDE files. |
| `.github/workflows/` (recommended) | `go test ./...`, `go vet`, optional **golangci-lint** / **staticcheck**, Docker build for the worker image. |

### 3.3 Go gRPC server — responsibilities (required)

1. **gRPC server** — register **`grpc.health.v1`** for orchestration; optional **gRPC reflection** only for dev (disabled or loopback-bound in prod — document).
2. **FCM send path** — implement RPCs that map to **FCM HTTP v1** semantics via Firebase Admin (batching strategy documented — single send vs multi-send vs future batch API).
3. **Idempotency / deduplication policy** — document behavior when the backend retries the same logical notification (e.g. optional `client_request_id` in RPC; worker may log dedup at **best effort** unless backend persists idempotency keys).
4. **Structured logging** — JSON logs; **never** log full FCM registration tokens; at most **short hash prefix** + internal correlation ID.
5. **Metrics hooks (optional v1)** — e.g. Prometheus `/metrics` **bound to loopback** or disabled in prod; if added, document cardinality and labels (no raw tokens in labels).

### 3.4 gRPC API design — required minimum surface

Design **stable, narrow** RPCs. Illustrative v1 (names adjustable, but keep concepts):

| RPC | Purpose |
| --- | ------- |
| `SendPush` | Send to **explicit token list** provided by backend (backend already resolved user → devices from PostgreSQL). **User-visible copy:** use **FCM/OS localization keys + arguments** (see **§3.4.1**); do **not** rely on the worker or backend to ship final translated `title`/`body` strings for display. Include **data** map for app routing, Android channel ID, collapse key, TTL, priority. |
| `SendPushToUser` (optional) | Only if worker has **read access** to a device registry — **default for v1: avoid**; prefer backend passes tokens to keep worker stateless regarding domain DB. |
| `ValidateTokens` (optional) | Dry-run or “lint” tokens format before send — only if it adds real value; otherwise fold into `SendPush` error reporting. |

#### 3.4.1 Localization — **locked: app bundle (required)**

**Product decision (Many Faces):** notification **translations live in the mobile app bundle** (`many_faces_mobile`): iOS **`.strings` / `.stringsdict`**, Android **`strings.xml`**, or the **Expo / RN i18n** pipeline that compiles into those native resources. The **backend** chooses which message to send (business event) and passes **opaque localization identifiers + format args only** through gRPC to the worker. The **Go worker** maps those fields onto FCM **notification localization** properties (e.g. Android `title_loc_key` / `body_loc_key` + `*_loc_args`; iOS `title-loc-key` / `title-loc-args` per FCM/APNs payload rules) and must **not** host a translation catalog or user locale tables.

**Contract maintenance (required):** maintain a single **catalog document** (in `many_faces_mobile` README, `docs/guides/push-notifications-local-dev.md`, or a small `docs/` table) listing every **`title_loc_key` / `body_loc_key`** (and arg arity) that the backend may emit; mobile PRs that add keys must stay in sync with backend enums/constants. Breaking changes require coordinated bumps across backend, worker proto (if fields change), and mobile bundles.

**Optional fallback:** if a key is missing on an old app build, document behavior (e.g. omit notification text vs generic key in bundle); prefer **version gating** or **minimum app version** if product requires.

**Error model:** Use **rich gRPC status details** (or agreed error proto) so backend can interpret:

- **Permanent invalid token** → backend deletes token row.
- **Transient** throttling / unavailable → backend may retry with backoff.

Document mapping from **FCM / Admin SDK errors** to gRPC codes **explicitly** in README.

### 3.5 Firebase / Google credentials (required)

- Support **service account JSON** via file path **or** JSON content in env (prefer **file mount** in Docker for local dev).
- Document **least privilege** IAM roles required for FCM send in the target GCP project.
- Document rotation: how to roll credentials without dual-write confusion (brief ops subsection).

---

## 4. Monorepo integration (`many_faces_main`)

### 4.1 Root documentation (required)

- **`.gitmodules`** — register submodule with same URL style as other infra repos.
- **`README.md` (monorepo root)** — Architecture table: add **Push / FCM** row with link to `many_faces_push/README.md`.
- **`docs/README.md`** — After a guide exists, add a row under guides (see section 4.4).

### 4.2 `docker-compose.dev.yml` (required)

- Attach **`push-worker`** to **`many_faces_main_dev-network`** using the **same pattern** as `search-worker` / Redis attachment (document service DNS name and internal gRPC URL).
- Add **`many_faces_backend`** environment placeholders, e.g.:

  - `Push__Enabled` (bool) — maps to configuration key **`Push:Enabled`** (same **`Section__Key`** convention as `Search__*` → `Search:*`).
  - `Push__WorkerGrpcUrl` (e.g. `http://push-worker:50053` for cleartext dev **or** `https://…` when TLS is enabled — **pick one documented convention** aligned with `many_faces_elastic` learnings)
  - Optional: `Push__AuthToken` (or agreed name) or mTLS file paths if you implement auth from day one

- **Do not** expose push worker gRPC on a public host interface without TLS and auth.

### 4.3 Scripts (required)

Extend **`scripts/start-all-dev.sh`** / **`stop-all-dev.sh`** (or introduce a dedicated flag such as **`ENABLE_PUSH_WORKER=1`**) so developers can bring the worker up **optionally** (push may be off by default if Firebase project is not configured).

### 4.4 New guide in `docs/guides/` (required)

Add **`docs/guides/push-notifications-local-dev.md`** (or agreed filename) covering:

- Firebase console steps at a high level (project, app, iOS APNs key upload to Firebase, Android package name).
- **Expo / EAS** pointers (links to official docs — do not duplicate Expo’s moving targets verbatim; instead list **what Many Faces must configure**).
- **Localization catalog** pointer — link to the canonical list of notification **loc keys** (**§3.4.1**) and note that mobile bundles are the source of translated strings.
- Local compose wiring, env vars, **grpcurl** smoke example for `SendPush` with a **test token** (document how to obtain safely).
- **Security warning:** never commit service account JSON; use Docker secret mounts or local gitignored paths.

### 4.5 CI (required)

- **`docker compose … config`** validation for the submodule compose (same class of job as `many_faces_elastic`).
- **Go** CI for the submodule: tests + vet (+ optional lint).
- If C# stubs are generated from `many_faces_push/proto/`, add a **drift check** (regenerated output must match committed files) or **`buf breaking`** policy — mirror whatever the monorepo already standardized for search protos.

---

## 5. Backend (`many_faces_backend`) — orchestration layer

### 5.1 Responsibilities (required)

1. **Persist push tokens** — new or extended tables: associate **user**, **device id** / installation id, **platform** (`ios` / `android`), **token string**, **created/updated**, **last_seen**, optional **`expo_project_id`** / **`app_version`**. Migrations via EF Core.
2. **Authenticated HTTP endpoint(s)** for **`many_faces_mobile`** — e.g. `POST /api/me/push-token` (exact routing must match existing API style and auth). Validate token format at a basic level; rate-limit if easy.
3. **Internal send pipeline** — when domain logic decides to notify (e.g. new chat message, moderation outcome — **pick one pilot event** for v1), backend:

   - loads candidate FCM tokens for target user(s) **from PostgreSQL**,
   - calls **`Grpc.Net.Client`** to **`SendPush`**,
   - interprets errors and **deletes** or **marks invalid** tokens returned as permanent failures.

   **Pilot default (recommended):** first shipping path should be an **admin- or operator-only** test send or a **single** product event with explicit product sign-off (see **§10 Phase B**); avoid a generic “send push to any user” API in early merges.

4. **Configuration** — `IOptions<PushOptions>` pattern mirroring `SearchOptions` / similar; clear **Enabled** flag so local dev without Firebase does not crash the API. Use **`Push:`** keys in `appsettings` and **`Push__*`** environment variables in Docker (**same mapping rule** as **`Search:`** / **`Search__`**).

### 5.2 gRPC client (required)

- Implement a **narrow interface** (e.g. `IPushWorkerClient`) used by application services — **not** directly from controllers for bulk sends.
- Channel lifecycle: document whether the channel is **singleton** or **factory**; align with existing `SearchWorkerGrpcProbe` / `AiGrpcService` patterns for **keep-alive** and **HTTP/2 cleartext** dev settings where applicable.
- **Cleartext gRPC (http://) in local Docker:** when `Push:WorkerGrpcUrl` uses **`http://`**, mirror the **`many_faces_backend`** pattern for the search worker: enable **`AppContext.SetSwitch("System.Net.Http.SocketsHttpHandler.Http2UnencryptedSupport", true)`** only when that URL scheme is **http** (do **not** enable globally for **https://**). For **https://**, use TLS client options consistent with [`docs/guides/elasticsearch-grpc-tls-mtls.md`](../guides/elasticsearch-grpc-tls-mtls.md) (custom CA, mTLS, server name) as for `Search:`.
- **Timeouts and retries** — policy at the **backend** boundary (retry only for idempotent or deduped notifications; document product implications).

### 5.3 Authorization and privacy (required)

- Backend must **never** forward notifications to users who fail capability / face checks — worker is **not** the authorization layer.
- **Localization:** per **§3.4.1**, backend sends **localization keys + args** for the notification surface; **do not** assemble locale-specific human-readable title/body in .NET for display strings. Dynamic **format args** must be non-sensitive or already redacted (names, counts — product rules); **never** put secrets into loc-args that could appear on the lock screen.
- Payload **`data`** keys should be **minimal** (IDs, type, deep link route key) — avoid embedding sensitive free text if notification could appear on lock screen (product decision documented).

---

## 6. Security model — worker exposure

**Hardening tasklist (mandatory tokens, TLS, reflection off, hardened compose):** [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) **§11** (**PUSH-1…PUSH-6**) — tick there in security engagements; do not duplicate checklists in this file.

**Product-specific (document in submodule `README.md`):**

- Push worker listens on **internal Docker network only** in dev/prod patterns used by Many Faces.
- **Token theft** — treat FCM tokens like secrets-in-transit; TLS for mobile ↔ backend; TLS for backend ↔ worker.
- **Spoofed sends** — worker does not authorize per-user domains; backend must not forward arbitrary registration tokens (see **§5.3**).
- TLS/mTLS vocabulary: [`docs/guides/push-grpc-tls-mtls.md`](../guides/push-grpc-tls-mtls.md), [`docs/guides/elasticsearch-grpc-tls-mtls.md`](../guides/elasticsearch-grpc-tls-mtls.md).

---

## 7. Mobile (`many_faces_mobile`) — client responsibilities

### 7.1 Client implementation (required)

- Request permissions, configure notification handler, obtain a **push token** per **§1.1** and current Expo SDK guidance (direct FCM path vs Expo Push API path — must match what the backend persists and what the worker accepts).
- On login / token refresh, **register token with backend** authenticated API.
- On logout, **unregister** or send “invalidate this installation” if supported.
- Handle **notification tap** → navigate using **`data`** payload keys agreed with backend (deep link contract documented in one place).
- **Localized notification strings:** implement and maintain **native/localized resources** for every **`title_loc_key` / `body_loc_key`** (and pluralization rules) that the backend may send, per **§3.4.1** and the shared catalog. Verify at least **one non-default locale** in manual QA when adding keys.

### 7.2 Build configuration (required)

- Document **EAS credentials**, `google-services.json` / `GoogleService-Info.plist` ownership, and **which Firebase project** maps to **dev vs prod**.

---

## 8. Testing strategy (required)

| Layer | Minimum expectation |
| ----- | ------------------- |
| **Go worker** | Unit tests for payload mapping, redaction, error classification (table-driven). Integration tests may use **Firebase Emulator** only if you commit to emulator wiring; otherwise mock the FCM client interface. |
| **Backend** | Unit tests for token persistence service; **fake** `IPushWorkerClient` for controllers / domain handlers; verify invalid token cleanup path. |
| **Mobile** | Lightweight test or manual checklist doc for permission flows (defer heavy E2E unless already standard). When using **loc keys**, manual check that **at least two locales** resolve expected copy on a device. |

Document **manual smoke** steps end-to-end: register token → trigger pilot event → device receives notification.

---

## 9. Observability and operations

- **Correlation:** propagate **`X-Request-Id`** or trace IDs from backend into gRPC metadata to worker logs.
- **Dashboards (optional):** rate of successes, invalid tokens, throttles.
- **Runbook snippet** in guide: “FCM suddenly all fails” — verify credential expiry, quota, incorrect Firebase project, APNs misconfiguration for iOS.

---

## 10. Delivery phases (recommended sequencing)

1. **Phase A — Submodule skeleton** — Go gRPC server, health check, compose, docs, no real FCM yet (or behind feature flag).
2. **Phase B — FCM send** — `SendPush` works with a manually supplied token; backend stub call from a **maintenance/admin-only** endpoint or test harness (avoid shipping arbitrary send to members).
3. **Phase C — Persistence + mobile registration** — EF migration + mobile register API + pilot user flow.
4. **Phase D — Production hardening** — see [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) **§11** (**PUSH-***); plus metrics, invalid token GC, rate limits in this prompt’s **§9**.

The agent may **compress** phases if product demands, but **document risks** when skipping auth/TLS (use **`TRACK-SHV2-*`** in v2 report if waived).

---

## 11. Final checklist — tasks for the implementing agent

Copy this section into PRs or issues and tick items there per [`docs/prompts/README.md`](./README.md) conventions (**leave `[ ]` unchanged in the canonical prompt file** in the monorepo unless recording a fully completed one-off engagement).

### Submodule `many_faces_push` (Go + gRPC + FCM)

- [ ] Create submodule repo layout per **section 3.2** (`README.md`, `Dockerfile`, `docker-compose.yml`, `go.mod`, `cmd/…`, `internal/…`, `.env.example`, `.gitignore`).
- [ ] Add **`proto/`** with versioned **`v1`** service; document package naming and regeneration instructions; **`SendPushRequest`** must carry **notification localization key + args** fields (names per FCM mapping) per **§3.4.1**, not ad-hoc translated strings.
- [ ] Implement **gRPC server** with **health** service and graceful shutdown.
- [ ] Integrate **Firebase Admin SDK for Go** (or documented alternative) for **FCM send**; document required IAM roles.
- [ ] Implement **`SendPush`** (and optional RPCs) per **section 3.4**; map **localization key + args** fields to FCM notification localization properties per **§3.4.1**; map **FCM / Admin SDK errors** to **gRPC status codes** per the **Error model** in **§3.4** (document the mapping table in submodule `README.md`).
- [ ] Ensure logs **redact** full device tokens; add correlation ID support via metadata.
- [ ] Add **Go unit tests** per **section 8**; CI workflow per **section 3.2** / **4.5**.
- [ ] Pin **Go** and Docker base image versions; document upgrade policy in submodule `README.md`.

### Monorepo wiring (`many_faces_main`)

- [ ] Register **git submodule** in **`.gitmodules`** at `many_faces_push/`; document clone/init in root `README.md`.
- [ ] Update **root `README.md`** architecture table with **Push / FCM** entry and correct relative links.
- [ ] Extend **`docker-compose.dev.yml`** so **`push-worker`** joins **`many_faces_main_dev-network`** with non-colliding ports; add backend env placeholders per **section 4.2**.
- [ ] Extend **`scripts/start-all-dev.sh`** / **`scripts/stop-all-dev.sh`** (or equivalent) with optional push worker flag per **section 4.3**.
- [ ] Add **`docs/guides/push-notifications-local-dev.md`** per **section 4.4** (include **loc-key catalog** link or embedded table per **§3.4.1**); link it from **`docs/README.md`** guides table.
- [ ] Add CI compose validation + proto drift checks per **section 4.5**.

### Backend (`many_faces_backend`)

- [ ] Add EF Core **migrations** for push token storage per **section 5.1** (indices for user + platform; uniqueness strategy documented).
- [ ] Add **authenticated API** for mobile to register/unregister tokens; validate input; align with existing auth patterns.
- [ ] Add **`IPushWorkerClient`** (or equivalent) using **`Grpc.Net.Client`**; bind **`IOptions<PushOptions>`** to section **`Push:`** (`Enabled`, `WorkerGrpcUrl`, …) with **`Push__*`** env vars in compose (same **`Search:`** / **`Search__`** convention as **§4.2**).
- [ ] Wire **one pilot domain event** to call the worker (choose smallest safe feature — e.g. test notification endpoint for admins only, or a single real product event with product sign-off); emit **loc keys + args** only, per **§3.4.1** / **§5.3**.
- [ ] Implement **invalid token cleanup** when worker/backend classifies permanent FCM failures.
- [ ] Add **unit tests** with fake gRPC client; verify options disabled path does not throw.

### Mobile (`many_faces_mobile`)

- [ ] Add **`expo-notifications`** (and any required Expo config plugins) per current Expo SDK; document in mobile README.
- [ ] Implement permission prompts, token retrieval, and **backend registration** on login/token change per **section 7.1**.
- [ ] Document **EAS / Firebase** file placement and **dev vs prod** projects per **section 7.2**.
- [ ] Handle notification **tap routing** using **`data`** contract shared with backend.
- [ ] Add/update **bundle strings** (all supported locales) for every notification **loc key** the backend can send; keep the **§3.4.1** catalog in sync.

### Security, privacy, and ops

- [ ] **gRPC auth + TLS + hardened compose:** complete **PUSH-1…PUSH-3**, **PUSH-5** in [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) **§11** (not duplicated here).
- [ ] Review **loc-key catalog**, **format args**, and **`data`** payload for **lock-screen privacy** per **section 5.3** and **§3.4.1**.
- [ ] Add short **operator runbook** bullets (credential rotation, common failures) to the new guide per **section 9**.

### Acceptance — definition of done

- [ ] **End-to-end manual smoke** documented: mobile obtains token → backend persists → pilot event → notification arrives → tap opens correct screen (or logs intent).
- [ ] **Local dev** works with **`ENABLE_PUSH_WORKER=1`** (or chosen flag) and a **test Firebase project** without committing secrets.
- [ ] **No secrets** in git history for service accounts; `.gitignore` / docs warn against `google-services` misuse in wrong repo if applicable.

---

**End of prompt.**
