# Many Faces — Elasticsearch search infra — Agent prompt

**Language:** All **new** prose you add to repositories (README, guides, comments in new code) must be **English**.

**Mission:** Introduce **Elasticsearch** as an **optional search and analytics index** for the Many Faces stack, delivered primarily through a **new standalone git submodule** named **`many_faces_elastic`** (or `many_faces_elasticsearch` if you rename the repo — keep naming consistent in `.gitmodules`, paths, and docs). **PostgreSQL remains the system of record** for transactional data (Identity, OAuth, social graph, moderation state, `gridSchema`). Elasticsearch is a **read-optimized projection** for text search, faceted exploration, and (later) similarity; it must **not** replace EF Core migrations or primary OLTP.

**Canonical pattern:** mirror **`many_faces_database`**, **`many_faces_redis`**, and **`many_faces_logger`**: own repo, `docker-compose.yml`, `README.md`, helper scripts, and a **compose sanity** job in `many_faces_main/.github/workflows/ci.yml`.

**Integration boundary (required):** **Browsers and mobile apps** must **never** call the search worker or Elasticsearch directly. **All product HTTP** for search stays on **`many_faces_backend`**: a **dedicated MVC controller** (e.g. `SearchController` under `api/search/...`) for **REST/OpenAPI** only, plus a **separate application service** in the backend that implements **business rules** and calls the search tier **only via gRPC client** (see section 2.4). **`many_faces_elastic`** hosts **Elasticsearch (Docker)** and a colocated **Go search worker** that is the **only** component allowed to use **Elasticsearch’s HTTP API** from application code. **`many_faces_ai`** (and any future internal service) must talk to the same search tier **via gRPC to that Go worker**, not by opening HTTP to Elasticsearch. **Version every RPC** with **`.proto`** files and regenerate stubs in CI for **Go (worker)**, **C# (backend client)**, and **Python (AI client)** when AI integration ships.

---

## 1. Context — Why Elasticsearch here

Many Faces is a **face-scoped social platform** (`many_faces_main` monorepo): ASP.NET Core API (`many_faces_backend`), React SPAs (`many_faces_portal`, `many_faces_admin`), Redis-backed jobs, Python gRPC AI (`many_faces_ai`), PostgreSQL (`many_faces_database`). User-generated **albums, blogs, reels, stories**, **wall tickets**, **profiles**, and **moderation / audit** events accumulate **text-heavy** payloads.

PostgreSQL + EF Core are sufficient for **CRUD, authorization, and structured reporting** already shipped (e.g. operator stats, moderation queues with SQL filters). Elasticsearch earns its place when the product needs:

1. **Cross-module full-text search** for members (portal) — one search bar over multiple entity types with ranking, highlighting, and language-aware tokenization.
2. **Operator-scale moderation search** (admin) — fast text + facet queries over pending items and audit metadata without heavy `LIKE` / multi-join patterns on large tables.
3. **Autocomplete / suggest** — completion-style queries as the user types (search box, tags, future `@mentions`).
4. **Audit / activity read model** (optional phase) — searchable timeline of moderation transitions (who / what / when / free-text reason) as a **secondary index**, not the legal source of truth (that stays in PostgreSQL).
5. **Future: vector / “more like this”** (explicitly **phase 3+**) — dense vectors for duplicate spam detection or recommendations; only after embeddings and privacy review.

**Do not** propose Elasticsearch as the primary store for OAuth tokens, refresh rotation, or capability evaluation.

---

## 2. New submodule repository — `many_faces_elastic`

### 2.1 Repository layout (required)

Create (or complete) a **separate GitHub repository** and add it to `many_faces_main` as a **git submodule** at:

```text
many_faces_elastic/
```

Minimum contents:

| Path | Purpose |
| ---- | -------- |
| `README.md` | Product context, how ES + worker fit Many Faces, **non-goals**, ports (Elasticsearch HTTP, **gRPC worker**), memory, dev vs prod, auth model (section 7), link to monorepo guides. **State explicitly:** no **browser-facing** API in this repo; the **Go worker** exposes **gRPC only** to trusted internal callers (`many_faces_backend`, `many_faces_ai`). |
| `docker-compose.yml` | Services: **Elasticsearch** (pinned tag) + **`search-worker`** (or agreed service name) on a **shared Docker network** so the worker resolves Elasticsearch by **DNS** (e.g. `http://elasticsearch:9200` inside the compose project). Pin worker image by digest or tag once built. |
| `Dockerfile` (worker) | Multi-stage build for the **Go** gRPC server (small final image, non-root user where practical). |
| `proto/` | **Canonical source of truth** for **search** `.proto` files (RPCs for index + query + health). Document how **`many_faces_backend`** and **`many_faces_ai`** consume the same definitions (copy step, `buf`, or git submodule — pick one approach for v1 and document it in `README.md` + `docs/guides/elasticsearch-local-dev.md`). |
| `cmd/search-worker/` (or `searchworker/`) | **Go** `main` package: start gRPC server, register services, configure Elasticsearch Go client, graceful shutdown, structured logging. |
| `internal/...` | Go packages: gRPC service implementations, Elasticsearch adapter, config parsing — **no** business rules that belong in `many_faces_backend` (e.g. face ACL); worker trusts **caller identity metadata** only as far as designed (see section 7). |
| `go.mod` / `go.sum` | Go module for the worker; keep dependencies minimal and audited. |
| `scripts/*.sh` | Start/stop Elasticsearch **and** optionally the worker (or rely on `docker compose up` for both); match style of `many_faces_database` / `many_faces_redis`. |
| `.env.example` | Cluster name, heap sizes, **gRPC listen address**, Elasticsearch URL **for worker only**, worker auth secrets placeholders — **no** real secrets. |
| `.gitignore` | Ignore local volumes, `.env`, data dirs, `bin/`, IDE files. |
| `.github/workflows/` (optional but recommended) | In **`many_faces_elastic`**: `go test`, `go vet` / **staticcheck** or **golangci-lint**, and **Docker build** for the worker image on PRs. |

### 2.2 Search worker — **Go** gRPC server (required)

**Language (locked for this prompt):** implement the colocated search process in **Go**.

**Responsibilities:**

1. **gRPC server** — listen on a **dedicated port** (choose a default that does not collide with **`many_faces_ai`** gRPC, e.g. **`50052`** inside the network; map a distinct host port in dev, e.g. **`59202`**). Implement **gRPC health** (`grpc.health.v1`) for orchestration.
2. **Elasticsearch access** — use the official **Go Elasticsearch client** compatible with the chosen cluster major version; talk to Elasticsearch **only over HTTP(S)** on the Docker service name (not `localhost` from inside the worker unless documented for single-container dev).
3. **RPC surface** — keep RPCs **narrow and stable**: e.g. `IndexDocument`, `DeleteDocument`, `Search`, `Bulk` (split or version as needed). Payloads should carry **tenant / face identifiers** and opaque document bodies or structured fields **already validated** by the backend where security-critical; do not re-implement full ACL in the worker unless explicitly scoped later.
4. **No REST product API** — do not add public HTTP routes for portal/admin. Optional: **metrics** (`/metrics` for Prometheus) or **pprof** behind **bind to loopback only** or disabled in production — document clearly.
5. **Observability** — structured logs (JSON), request IDs propagated from gRPC metadata, redact secrets.

**Process layout:** one **long-lived** worker container next to Elasticsearch in **`many_faces_elastic/docker-compose.yml`**. The **`many_faces_backend`** container must reach the worker at **`search-worker:<grpc-port>`** (or the chosen service name) on **`many_faces_main_dev-network`** after `docker network connect` (same pattern as Redis) or by extending compose so both stacks share a network (document the chosen approach).

### 2.3 Docker and resource expectations (required)

- Elasticsearch **runs in its own container(s)** — not inside the API container.
- The **Go worker** runs in its **own** container — not inside the Elasticsearch JVM and not inside `many_faces_backend`.
- Document **JVM heap** (`ES_JAVA_OPTS`) and host RAM; single-node dev typically needs **≥ 512 MiB–1 GiB heap** guidance (tune for Apple Silicon / CI runners). Document **Go** memory (GC, connection pools) at a high level.
- Expose Elasticsearch HTTP on a **non-colliding** host port vs Postgres (`54320`) and Redis (e.g. **`59200`** as today). Expose worker gRPC on a **separate** host port (e.g. **`59202`**) for host-side debugging tools; internal compose DNS remains the primary contract for backend ↔ worker.

### 2.4 Licensing / image choice (required decision in README)

Document explicitly:

- **Elastic** official images and **Elastic License** constraints vs OSS-era expectations.
- Alternative: **OpenSearch** fork if the org requires ALv2-style licensing — if you choose OpenSearch, **rename the submodule and prompt** consistently (do not mix “Elasticsearch” product name with OpenSearch images without a clear disclaimer).

Pick **one** stack for v1; do not leave the README ambiguous.

---

## 3. Monorepo integration (`many_faces_main`)

### 3.1 `.gitmodules` and root docs (required)

- Register the submodule in **`.gitmodules`** with the same URL style as sibling infra repos (`https://github.com/…/many_faces_elastic.git` or SSH).
- Update **`README.md`** (Architecture table): add **Search / index** row pointing to `many_faces_elastic/` with a **file link** that works on GitHub (e.g. `many_faces_elastic/README.md` — follow the same pattern used for other submodules after the blob/tree fix).
- Update **`docs/README.md`** — add a guides row or cross-link under an appropriate section once a guide exists (e.g. `docs/guides/elasticsearch-local-dev.md`).

### 3.2 `docker-compose.dev.yml` (required for dev ergonomics)

- Ensure **`many_faces_backend`** can resolve the **Go search worker** by **Docker DNS** on **`many_faces_main_dev-network`** (e.g. service name **`search-worker`**, internal gRPC port **`50052`** — exact names must match `many_faces_elastic/docker-compose.yml` and docs).
- **Do not** require the backend container to reach Elasticsearch HTTP for the main search path; the backend should use **gRPC to the worker** only (Elasticsearch HTTP stays between worker ↔ Elasticsearch).
- Add environment variable placeholders on the API service aligned with section 4, e.g. `Search__WorkerGrpcUrl=https://search-worker:50052` (or `http://` in dev if TLS is not yet enabled — document the convention) and **`Search__Enabled`** (or equivalent) so local dev can disable search without a worker.
- Optional: retain a **diagnostic** direct Elasticsearch URL **only** for non-shipping health tooling if ever needed; if present, default it **empty** and document that production paths must not use it.

### 3.3 Scripts (required)

Extend **`scripts/start-all-dev.sh`** / **`stop-all-dev.sh`** (and any related helpers) so that when **`ENABLE_ELASTICSEARCH=1`** (or a renamed flag that covers the **stack**), the stack brings up **Elasticsearch + Go `search-worker`**, attaches both to **`many_faces_main_dev-network`** in a defined order, and documents host ports (Elasticsearch HTTP, worker gRPC) for debugging.

### 3.4 CI (required)

- Keep **`infra_many_faces_elastic`** **`docker compose … config`** validation for the submodule `docker-compose.yml` (paths, services, networks).
- Add (in **`many_faces_elastic`** or **`many_faces_main`**, as maintainers prefer) a **Go** CI job: **`go test ./...`**, **`go vet`**, and optionally **golangci-lint** / **staticcheck** on the worker module; fail PRs on regressions in generated gRPC code if stubs are committed.
- If **`many_faces_main`** generates C# from **`many_faces_elastic/proto/`**, add a **check** that regenerated C# matches committed output (or that `buf breaking` passes) so backend and worker never drift.

---

## 4. Backend (`many_faces_backend`) — indexing and query surface

### 4.0 Service and API split (required)

- **REST/OpenAPI:** exactly **one dedicated controller area** for member/admin search HTTP (e.g. `SearchController` under `api/search/...`). Do not scatter search concerns across unrelated controllers.
- **Application layer:** a **separate service interface + implementation** (not nested inside the controller) is the **only** place that calls **`Grpc.Net.Client`** to the **Go search worker** (narrow interface: `ISearchWorkerClient` / `ISearchQueryGateway` — names illustrative). Controllers stay thin: auth, validation, mapping to DTOs, translation of gRPC errors to HTTP status codes.
- **No Elasticsearch .NET client in the backend** for the shipping search path: the backend **must not** open HTTP to Elasticsearch in production flows; it talks **gRPC → Go worker** only. (Unit tests may use in-memory fakes or **TestServer** for the worker later; do not require a real cluster in default `dotnet test`.)
- **Elasticsearch HTTP** exists **only** inside the **Go worker** in `many_faces_elastic` (section 2.2). Never call Elasticsearch from **`many_faces_portal`**, **`many_faces_admin`**, or **`many_faces_mobile`**.

### 4.1 Configuration (required)

- Add **options-bound** configuration for the **gRPC client** to the worker, e.g. under `Search:`: **`WorkerGrpcUrl`** (scheme + host + port), **deadlines / timeouts**, optional **TLS** settings (certificate path or trust bundle), and **worker authentication** (shared secret in metadata and/or **mTLS** — align with section 7).
- Add **`Search:Enabled`** (or equivalent): when **false** or when **`WorkerGrpcUrl`** is unset, the API must **not** fail startup; search REST endpoints return **501 Not Implemented** or **404** with a clear JSON body — pick **one** convention and document it.
- **Do not** store Elasticsearch admin credentials in the backend for the main path; if the worker needs Elasticsearch credentials, they live with the **worker** env only.

### 4.2 gRPC client and code generation (required)

- Use **`Grpc.Net.Client`** in **`many_faces_backend`** with **generated C# stubs** from the **same `.proto` files** as the Go worker (**canonical path: `many_faces_elastic/proto/`** unless you adopt **Buf** with a different layout — document the chosen approach).
- Register the gRPC channel + client in DI with **appropriate lifetime** (`Singleton` or `GrpcChannel` per docs for channel reuse), **cancellation tokens**, and **retry policy** where safe (avoid blind retries on non-idempotent RPCs).
- Keep RPC definitions **versioned** (`package` + service names); use **backward-compatible** field additions; document how breaking changes are rolled out (new service suffix / new package).

### 4.3 Indexing pipeline — choose **one** strategy for v1 (required)

Implement **one** of the following (document trade-offs in `many_faces_elastic/README.md` and a monorepo guide). In **all** cases, the process that **mutates** the Elasticsearch index ultimately issues **gRPC calls to the Go worker** (or runs **inside** the worker only if you later colocate background loop there — prefer **backend-owned** scheduling calling worker RPCs for v1 so authorization stays centralized):

| Strategy | Pros | Cons |
| -------- | ---- | ---- |
| **A. Outbox table + background worker** | Reliable, replayable, transactional with PG | More tables + worker code |
| **B. Domain events after successful `SaveChanges`** | Simpler wiring | Harder to guarantee delivery on failures |
| **C. Periodic reindex job** | Easiest PoC | Stale index, heavy scans |

For production-minded v1, **prefer A** unless product explicitly accepts **C** for a demo.

### 4.4 Indexed entities — phase plan (required)

**Phase 1 (PoC) — pick 1–2 entity types only**, e.g.:

- `Blog` titles + descriptions + ids + `faceId` + `approvalStatus`, or
- `ContentModerationEvent` audit text fields (if audit search is the first win).

**Phase 2** — expand to albums, reels, stories, wall tickets (respect **face scope** and **visibility**: do not index `PendingApproval` public text for non-owners unless product allows).

**Phase 3** — autocomplete / suggest APIs + admin UI wiring.

**Phase 4** — vectors / kNN (optional; separate security + retention review).

### 4.5 HTTP API contracts (required for any shipped phase)

- Add **versioned** internal or public search endpoints under the existing **face-prefixed** routing rules, e.g. `GET /api/search?q=&types=&faceId=` — enforce the same **JWT + capability** rules as analogous list endpoints. These routes live on the **dedicated search controller** (section 4.0); do not add parallel public routes on a separate host.
- Never return fields that PostgreSQL would not return to the same principal (index is not an excuse to leak).

### 4.6 Tests (required)

- **Unit tests** in **`many_faces_backend`**: mock **`Grpc.Net.Client`** / generated client at the **dedicated search gateway** boundary (or use **TestServer** with a fake worker). Default **`dotnet test`** must **not** require Elasticsearch or a real Go binary.
- **Go tests** in **`many_faces_elastic`**: table-driven tests for RPC handlers with a **fake** Elasticsearch interface (or httptest against ES test container only in optional CI job).
- **Optional** integration test job (env-gated) that spins **Elasticsearch + worker** and hits one RPC end-to-end — only if maintainers agree; otherwise document manual smoke (`grpcurl`, backend `curl` through REST).

### 4.7 `many_faces_ai` — gRPC consumer of the same worker (required when AI needs search)

- **`many_faces_ai`** must use **generated Python gRPC stubs** from the **same `many_faces_elastic/proto/`** sources as Go and C# (regenerate in CI or commit generated code per repo convention — stay consistent with how `many_faces_ai` already handles `proto/` today).
- **No** direct Elasticsearch HTTP from Python for shipping paths unless explicitly documented as a **temporary** exception; default is **gRPC → Go worker** only.
- Reuse **worker authentication** (section 7): service identity for AI (metadata, mTLS, or HMAC) must be distinct from end-user JWTs where possible.

---

## 5. Frontends (`many_faces_portal`, `many_faces_admin`)

SPAs and the mobile app call **`many_faces_backend` REST only**; they **never** call the Go **`search-worker`** gRPC port or Elasticsearch HTTP.

### 5.1 Portal (required when Phase 1 ships user-facing search)

- Search UI entry point (header or dedicated page) with **debounced** queries, **loading / empty / error** states, and i18n keys (`en` + parity for `sk`/`cz` where the portal already ships locales).
- Typed OpenAPI client: extend backend OpenAPI, then run **`yarn generate:api`** per [`docs/guides/openapi-client-generation.md`](../guides/openapi-client-generation.md).

### 5.2 Admin (required when moderation search ships)

- Extend moderation views with **optional** “Search index” mode or unified search bar — gated by capability (`SUPER_ADMIN` / moderation roles as today).
- Do not duplicate business rules; backend remains the gatekeeper.

---

## 6. Observability and operations

- **Not** a replacement for **Seq** application logging unless product explicitly merges observability stacks.
- **Go worker:** structured logs (JSON), gRPC access logs (caller identity metadata, **redacted** secrets), and correlation IDs propagated from **`many_faces_backend`** where applicable.
- Document **index lifecycle**: create index template, reindex command, delete dev indices.
- Document **backup / restore** expectations (dev: ephemeral OK; prod: out of scope here but list follow-ups).

---

## 7. Security and privacy

### 7.1 Data and PII

- **PII**: only index fields that are **already exposed** by equivalent REST responses for the same user role.
- **Prompt injection / malicious content:** indexed text is still **untrusted**; do not feed raw index hits into LLM prompts without the same defenses as [`moderation-content-prompt-injection-defense-agent-prompt.md`](./moderation-content-prompt-injection-defense-agent-prompt.md) where applicable.

### 7.2 Elasticsearch credentials

- **Secrets**: Elasticsearch credentials (if any beyond dev open cluster) live in **worker environment** / secret store for the worker container — **never** in git. The **backend** should not need Elasticsearch superuser credentials for the gRPC-only architecture.

### 7.3 Transport

- **Dev:** HTTP to Elasticsearch **inside the Docker network** may be acceptable with explicit README warnings; **gRPC** from backend/AI to worker may start as **plaintext** on `many_faces_main_dev-network` only if **worker is not host-published** and network is trusted — document threat model.
- **Prod:** **TLS for gRPC** (worker presents server cert; clients validate). **TLS for Elasticsearch** when the cluster requires it. Prefer **mTLS** between **backend ↔ worker** and **AI ↔ worker** so arbitrary containers on the network cannot call the worker.

### 7.4 Authenticating callers to the Go worker (required)

Pick **at least one** mechanism before exposing the worker beyond loopback:

- **mTLS:** worker trusts a CA; **`many_faces_backend`** and **`many_faces_ai`** present client certs issued for their service identities.
- **Shared HMAC / bearer token** in **gRPC metadata** on every RPC, rotated via secrets manager (weaker than mTLS but simpler for early dev — document downgrade risks).
- **Network allowlisting** is **not** sufficient alone for production; combine with TLS + auth.

Reject unauthenticated or untrusted peers at the worker **before** touching Elasticsearch.

---

## 8. Explicit non-goals (do not implement in v1)

- Replacing PostgreSQL or EF migrations with Elasticsearch.
- Moving **operator KPI stats** already implemented via SQL (`StatsController`, `PlatformStatsQueryService`) into ES **without** a separate product decision.
- Real-time **sub-millisecond** sync — document acceptable lag.
- A standalone **search microservice** HTTP API shipped inside **`many_faces_elastic`** or exposed publicly beside `many_faces_backend` (all traffic goes through **`many_faces_backend`** REST + dedicated controller).
- **`many_faces_backend`** opening **HTTP** to Elasticsearch for **shipping** search/index flows (must use **gRPC → Go worker** only; diagnostic-only HTTP, if any, must be off by default and documented).
- Calling **Elasticsearch HTTP** directly from **`many_faces_portal`**, **`many_faces_admin`**, or **`many_faces_mobile`**.
- Multi-region Elasticsearch production cluster automation — document as future work only.

---

## 9. Documentation deliverables

- [x] New submodule **`many_faces_elastic/`** with `README.md`, `docker-compose.yml`, **Go `search-worker`** (`Dockerfile`, `go.mod`, `proto/`, `cmd/` + `internal/`), scripts, `.env.example`, and optional **`.github/workflows`** for Go + Docker build.
- [x] **`docs/guides/elasticsearch-local-dev.md`** in `many_faces_main` — ports (Elasticsearch HTTP, worker gRPC), **`Search__WorkerGrpcUrl`**, `ENABLE_ELASTICSEARCH`, network attach order, **proto sync** between repos, **grpcurl** smoke, troubleshooting, link to submodule.
- [ ] Update **`docs/guides/docker-and-compose.md`** and **`docs/guides/redis-workers-and-queues.md`** only if wiring overlaps (keep deltas minimal).
- [ ] Update **`docs/readmes/README.md`** if you add a short “infra overview” cross-link pattern for the new submodule.

---

## 10. Verification checklist (unchecked — tick in PRs)

- [x] `docker compose … config` passes in CI for the submodule path (Elasticsearch + **`search-worker`** services).
- [x] **`go test ./...`** (and **`go vet`** or lint) passes for the worker module in CI (submodule or monorepo workflow).
- [x] `many_faces_backend` builds with search **disabled** by default (no Elasticsearch container and **no** worker required for default `dotnet test`).
- [ ] **Proto drift check** (if C# is generated from `many_faces_elastic/proto/`) passes in CI.
- [ ] `scripts/lint-all.sh` / `ci-local.sh` remain green (update scripts if new folders are linted).
- [ ] Submodule pointer bump merged in `many_faces_main` with coherent commit message.
- [x] No secrets committed; `.gitignore` covers ES data dirs, env files, and Go build artifacts.

---

## 11. Suggested implementation order

1. [x] **`many_faces_elastic`**: extend `docker-compose.yml` with **`search-worker`**; add **`proto/`** with minimal RPCs + **Go** server skeleton + **Dockerfile**; document ports and auth plan in `README.md`; optional Go CI in submodule.
2. [x] **Proto consumption**: wire **`many_faces_backend`** `Grpc.Tools` (or Buf) to generate **C#** from **`many_faces_elastic/proto/`**; add **`Search:`** options (`WorkerGrpcUrl`, `Enabled`, timeouts, TLS/auth).
3. [x] **`many_faces_backend`**: dedicated **search gateway** (gRPC client) + **`SearchController`** REST; health/readiness that respects **disabled** mode; unit tests with mocked gRPC.
4. [ ] **Indexing strategy** (section 4.3) implemented in backend jobs calling **worker RPCs** (not ES HTTP).
5. [ ] **First vertical slice**: one index + one read REST API + portal **or** admin UI.
6. [ ] **`many_faces_ai`**: generate Python stubs from the same protos; add narrow client + auth metadata when AI needs search.
7. [ ] Hardening: **mTLS** or token auth on worker, rate limits, index retention, reindex playbook.

---

## 12. Related documentation (read before coding)

- [`docs/guides/git-submodules.md`](../guides/git-submodules.md)
- [`docs/guides/docker-and-compose.md`](../guides/docker-and-compose.md)
- [`docs/guides/openapi-client-generation.md`](../guides/openapi-client-generation.md)
- [`docs/guides/ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md) — visibility and moderation rules must inform what gets indexed.
- [gRPC Go quick start](https://grpc.io/docs/languages/go/quickstart/) — worker server patterns.
- [gRPC .NET client](https://learn.microsoft.com/en-us/aspnet/core/grpc/client) — backend client to worker.

---

**End of prompt.** Copy this file into an agent task and tick the section 10 checklist in your PR description as work completes.
