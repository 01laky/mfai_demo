# Many Faces — Elasticsearch search infra — Agent prompt

**Language:** All **new** prose you add to repositories (README, guides, comments in new code) must be **English**.

**Mission:** Introduce **Elasticsearch** as an **optional search and analytics index** for the Many Faces stack, delivered primarily through a **new standalone git submodule** named **`many_faces_elastic`** (or `many_faces_elasticsearch` if you rename the repo — keep naming consistent in `.gitmodules`, paths, and docs). **PostgreSQL remains the system of record** for transactional data (Identity, OAuth, social graph, moderation state, `gridSchema`). Elasticsearch is a **read-optimized projection** for text search, faceted exploration, and (later) similarity; it must **not** replace EF Core migrations or primary OLTP.

**Canonical pattern:** mirror **`many_faces_database`**, **`many_faces_redis`**, and **`many_faces_logger`**: own repo, `docker-compose.yml`, `README.md`, helper scripts, and a **compose sanity** job in `many_faces_main/.github/workflows/ci.yml`.

**Integration boundary (required):** The **`many_faces_elastic`** submodule must **not** ship or expose its **own product HTTP/gRPC API** for portal, admin, or mobile clients. **All outward contracts** for search and index operations are owned by **`many_faces_backend`**: a **dedicated MVC controller** (e.g. `SearchController` or a clearly named successor) for **REST/OpenAPI** only, and a **separate application service** (e.g. `ISearchIndexService` / `ISearchQueryService`) that encapsulates every Elasticsearch read/write. Cross-process orchestration (e.g. API host ↔ indexer worker, or API host ↔ sidecar that talks to Elasticsearch) must use **gRPC** with **versioned `.proto`** definitions (follow the same repo conventions as `many_faces_ai` protos: live under `BeDemo.Api/Protos/` or a shared proto package, regenerate stubs in CI). **Elasticsearch’s native HTTP API** may be used **only inside** that dedicated service boundary (or inside the gRPC server implementation), not from arbitrary controllers.

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
| `README.md` | Product context, how ES fits Many Faces, **non-goals**, ports, memory, dev vs prod notes, link to monorepo `docs/guides/…` once written. **State explicitly:** this repo is **infra-only** (compose + scripts); it does **not** host a customer-facing search API (see Integration boundary in section 1). |
| `docker-compose.yml` | Single-node (dev) or documented multi-node (out of scope for v1 unless justified). Pin **image tags** (no `:latest` in committed defaults). |
| `scripts/*.sh` | `start-elasticsearch.sh`, `stop-elasticsearch.sh` (executable; match style of `many_faces_database` / `many_faces_redis`). |
| `.env.example` | Cluster name, heap sizes, **no** real secrets. |
| `.gitignore` | Ignore local volumes, `.env`, data dirs. |

### 2.2 Docker and resource expectations (required)

- Elasticsearch **runs in its own container(s)** — not inside the API container.
- Document **JVM heap** (`ES_JAVA_OPTS`) and host RAM; single-node dev typically needs **≥ 512 MiB–1 GiB heap** guidance (tune for Apple Silicon / CI runners).
- Expose HTTP API (e.g. **9200**) on a **non-colliding** port vs Postgres (`54320`) and Redis (`6379` host mapping). Document in `README.md` and monorepo `docker-compose.dev.yml` if wired there.

### 2.3 Licensing / image choice (required decision in README)

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

- Add a **`depends_on` / network** wiring path so `many_faces_backend` (or a future sidecar indexer) can reach Elasticsearch by **service DNS name** on the Docker network.
- Add environment variable placeholders on the API service, e.g. `Search__ElasticsearchUri` (exact naming must match `many_faces_backend` configuration — align with section 4).

### 3.3 Scripts (required)

Extend **`scripts/start-all-dev.sh`** / **`stop-all-dev.sh`** (and any related helpers) to optionally start/stop Elasticsearch **in the same order** as DB/Redis (document flags or env `ENABLE_ELASTICSEARCH=1` if you want it off by default for low-RAM machines).

### 3.4 CI (required)

- Add an **`infra_many_faces_elastic`** (or similarly named) job in **`many_faces_main/.github/workflows/ci.yml`** that runs `docker compose -f many_faces_elastic/docker-compose.yml config` (same pattern as `infra_many_faces_database` / `infra_many_faces_redis`).
- If the submodule is optional in sparse checkouts, the job must **skip gracefully** when the path is missing (match existing patterns if any).

---

## 4. Backend (`many_faces_backend`) — indexing and query surface

### 4.0 Service and API split (required)

- **REST/OpenAPI:** exactly **one dedicated controller area** for member/admin search HTTP (e.g. `SearchController` under `api/search/...`). Do not scatter Elasticsearch concerns across unrelated controllers.
- **Application layer:** a **separate service interface + implementation** (not nested inside the controller) owns index templates, bulk indexing, query DSL, and error mapping. Controllers stay thin: auth, validation, mapping to DTOs.
- **gRPC:** use **gRPC** for any **out-of-process** search pipeline component (indexer worker, query sidecar, or future split host) talking to the main API or to the service that wraps Elasticsearch. Version **`.proto`** files; keep **public** search for browsers/mobile on **HTTPS REST via `many_faces_backend`** only.
- **Elasticsearch HTTP:** confined to the implementation of the dedicated search service (or gRPC server); never called directly from portal/admin SPAs.

### 4.1 Configuration (required)

- Add **options-bound** configuration (`Search:` or `Elasticsearch:`) for: base URI, default index prefix, request timeout, and **optional** API key / basic auth for hosted clusters.
- **Default off:** when unset, the API must **not** fail startup; search endpoints return **501 Not Implemented** or **404** with a clear JSON message — pick one convention and document it.

### 4.2 Client library (required)

- Use the official **Elasticsearch .NET client** compatible with the chosen server major version (or OpenSearch .NET client if that path is chosen — **one** client family only). Register it **only** in the **dedicated search service** (section 4.0), not globally on unrelated types.
- Register `IElasticsearchClient` / `ISearchReadService` (names illustrative) in DI with **HttpClientFactory**-friendly lifetime and cancellation tokens. If a **gRPC server** hosts the ES client, register the client in that host’s DI container and expose narrow RPCs to `many_faces_backend` instead of exposing Elasticsearch URLs to the rest of the app.

### 4.3 Indexing pipeline — choose **one** strategy for v1 (required)

Implement **one** of the following (document trade-offs in `many_faces_elastic/README.md` and a monorepo guide):

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

- **Unit tests** with mocked Elasticsearch HTTP (no real cluster in default `dotnet test`). Mock at the **dedicated search service** boundary (or gRPC client stub), not only at the controller.
- **Optional** integration test job behind env flag or separate test project that spins ES in CI — only if maintainers agree; otherwise document manual smoke.

---

## 5. Frontends (`many_faces_portal`, `many_faces_admin`)

### 5.1 Portal (required when Phase 1 ships user-facing search)

- Search UI entry point (header or dedicated page) with **debounced** queries, **loading / empty / error** states, and i18n keys (`en` + parity for `sk`/`cz` where the portal already ships locales).
- Typed OpenAPI client: extend backend OpenAPI, then run **`yarn generate:api`** per [`docs/guides/openapi-client-generation.md`](../guides/openapi-client-generation.md).

### 5.2 Admin (required when moderation search ships)

- Extend moderation views with **optional** “Search index” mode or unified search bar — gated by capability (`SUPER_ADMIN` / moderation roles as today).
- Do not duplicate business rules; backend remains the gatekeeper.

---

## 6. Observability and operations

- **Not** a replacement for **Seq** application logging unless product explicitly merges observability stacks.
- Document **index lifecycle**: create index template, reindex command, delete dev indices.
- Document **backup / restore** expectations (dev: ephemeral OK; prod: out of scope here but list follow-ups).

---

## 7. Security and privacy

- **PII**: only index fields that are **already exposed** by equivalent REST responses for the same user role.
- **Secrets**: Elasticsearch API keys in **user secrets** / env — never in git.
- **Transport:** TLS for non-local deployments; dev may allow HTTP with explicit warning in README.
- **Prompt injection / malicious content:** indexed text is still **untrusted**; do not feed raw index hits into LLM prompts without the same defenses as [`moderation-content-prompt-injection-defense-agent-prompt.md`](./moderation-content-prompt-injection-defense-agent-prompt.md) where applicable.

---

## 8. Explicit non-goals (do not implement in v1)

- Replacing PostgreSQL or EF migrations with Elasticsearch.
- Moving **operator KPI stats** already implemented via SQL (`StatsController`, `PlatformStatsQueryService`) into ES **without** a separate product decision.
- Real-time **sub-millisecond** sync — document acceptable lag.
- A standalone **search microservice** HTTP API shipped inside **`many_faces_elastic`** or exposed publicly beside `many_faces_backend` (all traffic goes through **`many_faces_backend`** REST + dedicated controller).
- Calling **Elasticsearch HTTP** directly from **`many_faces_portal`**, **`many_faces_admin`**, or **`many_faces_mobile`**.
- Multi-region Elasticsearch production cluster automation — document as future work only.

---

## 9. Documentation deliverables

- [ ] New submodule **`many_faces_elastic/`** with `README.md`, `docker-compose.yml`, scripts, `.env.example`.
- [ ] **`docs/guides/elasticsearch-local-dev.md`** in `many_faces_main` — ports, env vars, start order, troubleshooting, link to submodule.
- [ ] Update **`docs/guides/docker-and-compose.md`** and **`docs/guides/redis-workers-and-queues.md`** only if wiring overlaps (keep deltas minimal).
- [ ] Update **`docs/readmes/README.md`** if you add a short “infra overview” cross-link pattern for the new submodule.

---

## 10. Verification checklist (unchecked — tick in PRs)

- [ ] `docker compose … config` passes in CI for the new submodule path.
- [ ] `many_faces_backend` builds with search feature **disabled** by default (no ES container required for `dotnet test` in default configuration).
- [ ] `scripts/lint-all.sh` / `ci-local.sh` remain green (update scripts if new folders are linted).
- [ ] Submodule pointer bump merged in `many_faces_main` with coherent commit message.
- [ ] No secrets committed; `.gitignore` covers ES data dirs and env files.

---

## 11. Suggested implementation order

1. Submodule + compose + CI compose validation + monorepo README table.
2. Backend **Search** configuration + **dedicated search service + dedicated controller** (REST outward; **gRPC** for any split indexer/sidecar per section 4.0) + disabled-by-default behaviour + tests.
3. Minimal indexer + single index + one read API + portal UI **or** admin UI (pick one vertical slice).
4. Expand indexed entities + faceting + i18n.
5. Hardening: rate limits, index retention, reindex playbook.

---

## 12. Related documentation (read before coding)

- [`docs/guides/git-submodules.md`](../guides/git-submodules.md)
- [`docs/guides/docker-and-compose.md`](../guides/docker-and-compose.md)
- [`docs/guides/openapi-client-generation.md`](../guides/openapi-client-generation.md)
- [`docs/guides/ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md) — visibility and moderation rules must inform what gets indexed.

---

**End of prompt.** Copy this file into an agent task and tick the section 10 checklist in your PR description as work completes.
