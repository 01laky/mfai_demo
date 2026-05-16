# Many Faces — Transactional email — Java gRPC mailer worker (SMTP, i18n HTML) — Agent prompt

**Language:** All **new** prose you add to repositories (README, guides, comments in new code) must be **English**.

**Mission:** Add a **standalone git submodule** that runs a **small Java process** (no Spring Framework) exposing **gRPC** to trusted callers. The worker **renders localized HTML (and plain-text) email templates**, merges **parameters** supplied by **`many_faces_backend`**, and **sends** messages via **SMTP** (transactional provider relay or local dev sink such as Mailpit). **`many_faces_backend`** becomes the **orchestrator only**: it decides **who** gets **which** template and with **what data**; it must **not** embed HTML bodies or translation catalogs for mail content. **Public clients** must **never** reach the mailer over gRPC.

**Canonical precedent:** Mirror the **internal gRPC worker** pattern used by **`many_faces_push`** ([`push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md`](./push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md)) and **`many_faces_elastic`**: submodule repo, `docker-compose.yml`, `README.md`, monorepo **`docker-compose.dev.yml`** on **`many_faces_main_dev-network`**, **`Grpc.Net.Client`** + **`IOptions<…>`** + **`GrpcWorkerChannelFactory`** alignment in **`many_faces_backend`**, optional **gRPC TLS/mTLS** (worker cert + optional client CA, backend `Mail:WorkerTls*` mirroring **`Push:`** / **`Search:`**), optional **`docker-compose.tls-smoke.yml`** + root **`.github/workflows/ci.yml`** jobs mirroring **`infra_many_faces_push`** / **`smoke_push_worker_grpc_tls`** (compose `config` with a dummy `*_TLS_SMOKE_CERT_DIR` + scripted smoke when you add them), and **destructive dev cleanup**: extend **`scripts/clear-all-dev.sh`** (compose `down`, force-remove known container names, volume/network prefix grep) so **`mailer-worker`** and TLS smoke projects do not survive a “clear all”.

**Agent discipline:** When implementation details are ambiguous, **default to parity** with **`many_faces_push`** (compose shape, CI jobs in **`.github/workflows/ci.yml`**, gRPC metadata auth, disabled-worker ergonomics, TLS env naming and docs layout) unless this prompt explicitly requires a different choice. For TLS specifically, treat **[`docs/guides/push-grpc-tls-mtls.md`](../guides/push-grpc-tls-mtls.md)** as the **primary** step-by-step template and **[`docs/guides/elasticsearch-grpc-tls-mtls.md`](../guides/elasticsearch-grpc-tls-mtls.md)** as the older sibling reference.

**Explicit non-goals for v1 (unless product reopens scope):**

- **No** Spring Boot / Spring Framework — use a **minimal** Java stack (see **§3.3**).
- **No** public REST API on the mailer — **gRPC only** from **`many_faces_backend`** (other internal workers later if needed).
- **No** marketing campaign manager, subscriber lists, or A/B testing — **transactional** sends only.
- **No** requirement that the worker host business authorization — backend remains the **policy** layer (who may receive which template class).
- **No** inbound **webhooks** (bounces, complaints, provider events) in v1 — document as backlog if product needs them later.
- **No** **attachments** / **inline CID images** in v1 unless explicitly reopened (keeps MIME and size limits simple).

---

## 1. Context — Current backend and target architecture

**Today (`many_faces_backend`, ASP.NET Core):** There is **no** dedicated production mail pipeline in tree (no `IEmailSender`, `MailKit`, or `SmtpClient` usage was found at the time this prompt was authored). **Re-verify** with `rg` / IDE search before implementation — if any direct SMTP or third-party mail SDK appears later, **§5.4** still requires routing transactional mail through **`IMailerWorkerClient`**. **ASP.NET Core Identity** is configured with **`AddDefaultTokenProviders()`** in `Program.cs`, which **anticipates** an email-backed user flow (confirmation, reset) once an **`IEmailSender`** implementation exists. **Target:** introduce **one** supported path for all outbound transactional email: **backend → gRPC → Java mailer → SMTP relay**.

**Why a separate Java worker:**

1. **Isolation of SMTP credentials** — API process compromise does not automatically expose relay passwords.
2. **Stable rendering + i18n boundary** — templates and locale bundles live with the component that sends mail; backend passes **opaque template keys + structured params**.
3. **Operational parity** — same class of deployable as **`many_faces_push`**: internal DNS name, health checks, structured logs, optional mTLS.

---

## 2. Naming and repository boundary

### 2.1 Submodule path (required default)

Use consistently in **`.gitmodules`**, Docker service names, env vars, and docs:

```text
many_faces_mailer/
```

Alternatives (`many_faces_smtp`, `many_faces_email`) are acceptable only if renamed **everywhere** in the same change set.

### 2.2 Compose service name and ports (required)

- **Docker Compose service name:** e.g. **`mailer-worker`** (avoid generic `mail` if it collides with image names).
- **gRPC listen:** pick an internal port that **does not collide** with **`many_faces_ai`**, **`many_faces_elastic`**, **`many_faces_push`** — document in submodule `README.md` and root compose.
- **SMTP target:** configured via env (provider host/port); for **local dev**, default to a **sink** such as **[Mailpit](https://github.com/axllent/mailpit)** or MailHog (document one choice).

### 2.3 gRPC port and DNS inventory (required — verify at implementation time)

**Internal container ports** used elsewhere in Many Faces (do **not** reuse for `mailer-worker`):

| Service / submodule | Typical internal gRPC port | Notes |
| ------------------- | -------------------------- | ----- |
| **`many_faces_ai`** | **`50051`** | Python gRPC in root `docker-compose.dev.yml`. |
| **`many_faces_elastic`** (`search-worker`) | **`50052`** | See `many_faces_elastic/docker-compose.yml` (`SEARCH_WORKER_GRPC_LISTEN`). |
| **`many_faces_push`** (`push-worker`) | **`50053`** | See `many_faces_push/docker-compose.yml` (`PUSH_WORKER_GRPC_LISTEN`). |
| **`many_faces_mailer`** (this prompt) | **`50054`** (default) | First free in sequence; if taken, pick **`50055+`** and update **all** docs + compose in **one** PR. |

**DNS names:** On **`many_faces_main_dev-network`**, backend should reach the worker via compose **service name** (e.g. `http://mailer-worker:50054`). Document **host-mapped** debug ports separately (avoid clashing with **`SEARCH_WORKER_GRPC_HOST_PORT`**, **`PUSH_WORKER_GRPC_HOST_PORT`**, etc.).

**Host-mapped ports (illustrative — pick free ports at implementation time and document in submodule `README.md` + `docs/guides/mailer-local-dev.md`):**

| Purpose | Typical host map (example) | Notes |
| ------- | ------------------------- | ----- |
| Elasticsearch HTTP (`many_faces_elastic`) | **`59200`** | Not gRPC; avoid reusing for mailer. |
| Search-worker gRPC | **`59202`** | See `SEARCH_WORKER_GRPC_HOST_PORT`. |
| Push-worker gRPC | **`59203`** | See `PUSH_WORKER_GRPC_HOST_PORT`. |
| **Mailer-worker gRPC** | **`59204`** (suggested default) | First free after push; env e.g. **`MAILER_WORKER_GRPC_HOST_PORT`** — must not collide with search/push TLS smoke ports (**`59211`**, **`59215`**) if developers run smokes concurrently. |
| **Mailpit UI** | **`8025`** (common default) | Web UI + SMTP ingest; document actual compose mapping. |

---

## 3. New submodule — `many_faces_mailer` (Java)

### 3.1 Submodule mount path (required)

Add a **separate Git repository** and link it as a **git submodule** at:

```text
many_faces_mailer/
```

Follow [`docs/guides/git-submodules.md`](../guides/git-submodules.md) conventions used by sibling infra repos.

### 3.2 Minimum repository layout (required)

| Path | Purpose |
| ---- | ------- |
| `README.md` | Architecture: backend ↔ gRPC ↔ worker ↔ SMTP; **non-goals**; ports; env vars; security (§6); how i18n + templates are organized; link to monorepo guide once added. |
| `docker-compose.yml` | **`mailer-worker`** + optional **Mailpit** (or chosen sink) for local capture. |
| `Dockerfile` | Multi-stage **Gradle** build, **non-root** runtime user where practical, **Eclipse Temurin** JRE (pin major version to match **§3.3**). |
| `proto/` | Canonical **`.proto`** under e.g. **`proto/manyfaces/mailer/v1/`** (mirror **`many_faces_push`** / `many_faces_elastic` folder layout), package **`manyfaces.mailer.v1`**, `v1` API. Document **one** regeneration path for **C#** stubs in **`many_faces_backend`** (copy, `buf`, or submodule path — same policy as push/search). |
| `src/main/java/...` | gRPC service implementation, template renderer, i18n loader, SMTP transport adapter, config validation. |
| `src/main/resources/templates/` | HTML (and optional `.txt`) templates per **§3.5**. |
| `src/main/resources/i18n/` | Locale message bundles (UTF-8) per **§3.5**. |
| `src/test/java/...` | **JUnit 5** unit tests: rendering, locale fallback, param validation, SMTP adapter fakes. |
| `gradle/` wrapper | **Gradle Wrapper** committed; pin **Gradle** version. |
| `settings.gradle.kts` | Root project name, **Java** toolchain plugin management if used. |
| `build.gradle.kts` or `build.gradle` | Minimal plugins: **Java toolchain**, **protobuf** / **gRPC**, application packaging (fat JAR or layered JAR). |
| `.env.example` | **`GRPC_LISTEN`**, SMTP **host/port/user/password**, **from** address, TLS mode, optional **`x-mailer-worker-token`**, log level — **no** real secrets. |
| `.gitignore` | Ignore `.env`, local credentials, `build/`, IDE files. |
| `.github/workflows/` (recommended) | **`./gradlew test`**, container build; optional **proto drift** check if C# is generated from this `proto/`. |

### 3.3 Java platform and “no Spring” stack (required)

**JDK:** Target **Java 21 LTS** as the **minimum** language/runtime baseline (records, pattern matching for `switch`, sequenced collections, virtual threads available). The project **may** pin a **newer LTS or current JDK** (e.g. 22+) if maintainers document the upgrade policy — avoid shipping **source/target 8** or other legacy baselines.

**Forbidden in v1:** **Spring Framework**, **Spring Boot**, **Quarkus**, **Micronaut** — those are **out of scope** for this prompt’s “small Java worker” goal.

**Allowed / recommended building blocks (pick and document in submodule `README.md`):**

| Concern | Suggested libraries (illustrative — pin versions in Gradle) |
| ------- | ------------------------------------------------------------- |
| **gRPC server** | **`io.grpc:grpc-netty-shaded`** (or **`grpc-okhttp`** if justified), **`grpc-services`** for **`grpc.health.v1`**, **`grpc-stub`**, **`protobuf-java`**. |
| **Process / shutdown** | Plain **`main`**: **`ServerBuilder`**, **`Runtime.addShutdownHook`**, await termination with timeout. |
| **Logging** | **SLF4J** API + **Logback** (or **JUL** bridge) with **JSON** encoder for stdout parity with other Many Faces containers. |
| **Configuration** | **Environment variables** and/or **`.env`** loaded in dev only; optional **SmallRye Config** or **typesafe-config** if you want typed config without Spring — keep dependencies **minimal**. |
| **SMTP** | **Eclipse Angus Mail** (`org.eclipse.angus:angus-mail`) — **Jakarta Mail 2.1** implementation (modern successor to “JavaMail”); use **STARTTLS** / **SMTPS** as required by the provider. |
| **HTML / text templates** | **Pebble** (`io.pebbletemplates:pebble`) or **JTE** — lightweight, no Spring requirement. **Mustache**-style engines are acceptable if you prefer even smaller surface area. |
| **i18n** | **`java.util.ResourceBundle`** with **UTF-8** control (or **`PropertyResourceBundle`** + explicit encoding), **`java.text.MessageFormat`** for placeholders; optional **ICU4J** only if product needs **plural/gender** rules beyond `MessageFormat`. |
| **Testing** | **JUnit 5**, **AssertJ**, **Mockito**; use **in-memory** or **GreenMail** for SMTP integration tests if you add an integration tier. |

**gRPC reflection:** Optional for **dev only** (disabled or loopback-bound in prod — document).

### 3.4 gRPC API — required minimum surface

Design **narrow**, **idempotent-friendly** RPCs. Illustrative v1:

| RPC | Purpose |
| --- | ------- |
| **`SendTemplatedEmail`** | Send one message: **`to`**, optional **`cc`/`bcc`**, **`template_id`**, **`locale`** (BCP 47, e.g. `sk`, `en-US`), **`params`** (string map or **`google.protobuf.Struct`** — **pick one** and document C# mapping), optional **`reply_to`**, optional **`idempotency_key`** (for logs and future dedup; v1 may be **best-effort** only). |
| **`HealthCheck`** | Use standard **`grpc.health.v1`** — do **not** invent a duplicate health RPC unless required by legacy probes. |

#### 3.4.0 Reference `proto` sketch (illustrative — adjust names before codegen)

The implementing agent **must** commit a **real** `proto/` tree; this block is a **starting point** only (field numbers, options, and `csharp_namespace` must match monorepo conventions and **`buf lint`** if used):

```protobuf
syntax = "proto3";

package manyfaces.mailer.v1;

option csharp_namespace = "ManyFaces.Mailer.V1";

// Internal transactional mailer — called only from many_faces_backend.
service MailerService {
  rpc SendTemplatedEmail(SendTemplatedEmailRequest) returns (SendTemplatedEmailResponse);
}

message SendTemplatedEmailRequest {
  repeated string to = 1;
  repeated string cc = 2;
  repeated string bcc = 3;
  string template_id = 4;
  string locale = 5; // BCP 47
  map<string, string> params = 6;
  optional string reply_to = 7;
  optional string idempotency_key = 8;
}

message SendTemplatedEmailResponse {
  string correlation_id = 1;
  optional string smtp_message_id = 2;
}
```

**Codegen (required):**

- **Java:** `grpc-java` + `protobuf` Gradle plugins; generated sources under `build/generated/…` (document clean rebuild).
- **C#:** Same approach as **`many_faces_push`** — either **committed** generated files under **`many_faces_backend`** or CI generation with **drift check**; document **exact** `dotnet grpc` / `protoc` / **`buf generate`** commands in submodule `README.md` and link from **`docs/guides/mailer-local-dev.md`**.

**Protobuf hygiene:** If the monorepo uses **`buf`**, add `many_faces_mailer/proto` to the same **lint / breaking** policy as other workers; **do not** rename `package` or RPCs without a **version bump** strategy (`v2` or compatibility window).

**Response:** include a **worker-generated correlation id**; optionally surface SMTP **accepted** vs **permanent failure** with **gRPC status codes** (`INVALID_ARGUMENT`, `FAILED_PRECONDITION` for misconfiguration, `UNAVAILABLE` for transient SMTP).

**Validation rules (worker):**

- Reject empty **`to`**, unknown **`template_id`**, malformed **`locale`** (or map to **fallback locale** — document policy).
- Enforce **maximum** message size and **template complexity** limits to reduce abuse if a caller misbehaves.
- Enforce **max recipient count** per request (sum of `to` + `cc` + `bcc` after dedup) — document the limit (e.g. ≤ 50 for transactional).
- Reject or sanitize **control characters** and absurdly long strings in **`params`** values (length cap per key and total serialized size).

**Proto contract decisions (required — pick before coding):**

- Prefer **`map<string, string> params`** for v1 unless product needs nesting; if **`google.protobuf.Struct`** is chosen, document **C#** construction and **JSON** ↔ template mapping in submodule `README.md`.
- Declare **`template_id`** as an **enum in docs** (and optionally as **`string` with enforced allow-list** in worker) — see **§3.5.1**.

**Error model (recommended parity with `many_faces_push`):** Document a **mapping table** in submodule `README.md` from **SMTP / transport failures** (auth, TLS handshake, 5xx vs 4xx semantics) to **gRPC `codes.*`**; optionally attach **`google.rpc.ErrorInfo`** (or rich status details) so the backend can classify **retry vs no-retry** without parsing English error strings.

**Cancellation:** Honor **`Context` cancellation** (deadline from backend **`GrpcDeadlineSeconds`**) by closing the SMTP attempt where the Jakarta Mail API allows it; document behavior when cancellation races completion.

### 3.5 Templates and i18n (required product rules)

1. **Translation catalogs live in the mailer submodule** under `src/main/resources/i18n/` (e.g. `messages_sk.properties`, `messages_en.properties`) — **UTF-8** keys/values; document **fallback chain** (requested locale → default locale, e.g. `en`).
2. **HTML templates** live under `src/main/resources/templates/` and **must** use the chosen engine’s **escape rules** for dynamic params (guard against injection when params contain user-generated text).
3. **Plain-text part:** **recommended** for every template (multipart **alternative**); if missing, document that v1 is **HTML-only** and accept deliverability trade-offs.
4. **Backend contract:** backend sends **only** **`template_id` + `locale` + params`** — **no** pre-rendered HTML from .NET for these flows. **Exception (explicit):** if a future product requirement needs **raw HTML from backend**, add a **separate RPC** with **strict size limits** and **security review** — **not** part of v1 unless reopened.
5. **Encoding:** All rendered parts must use **UTF-8**; MIME **`Content-Type`** with **`charset=UTF-8`** for HTML and plain text; **RFC 2047** encode **`Subject`** when it contains non-ASCII characters (document library or helper used).
6. **Subject line:** Either **fully derived in the worker** from i18n (`subject` key per `template_id` + locale) **or** passed as a **dedicated param** / field agreed in proto — **pick one** approach for v1 and document it so templates and subjects stay in sync.

#### 3.5.1 Template allow-list and catalog (required)

Maintain a **single catalog** (table in `many_faces_mailer/README.md` and mirrored or linked from **`docs/guides/mailer-local-dev.md`**) listing every supported **`template_id`**, **required params keys**, **optional keys**, **supported locales**, and **Identity flow** mapping (if applicable). Breaking changes require coordinated bumps across **proto** (if fields change), **worker**, and **backend** call sites.

#### 3.5.2 ASP.NET Core Identity — integration sharp edge (required reading)

Default **`IEmailSender.SendEmailAsync(string email, string subject, string htmlMessage)`** receives a **subject and HTML body** already composed by higher-level Identity/UI code in many tutorials. **This prompt’s architecture** expects **worker-owned HTML** from **`template_id` + locale + params**.

The implementing agent **must** choose and document **one** of these patterns (do **not** leave it implicit):

| Pattern | Behavior |
| ------- | -------- |
| **A (recommended)** | **Do not** pass Identity’s `htmlMessage` as mail body. Implement **`MailerGrpcEmailSender`** so it **ignores** `htmlMessage` for body composition (or asserts it is empty in dev-only builds) and instead maps the **email type** (confirm vs reset) to a **`template_id`**, passing **only safe params** (e.g. confirmation link URL, user display name, expiry) produced by **`UserManager`** token APIs + `LinkGenerator` / `IUrlHelper` equivalents. **Subject** either comes from worker i18n or from a **fixed param** agreed in the catalog. |
| **B (bridge / transitional)** | Worker accepts an optional **`raw_html_body`** field **only** on a **separate RPC** not used by v1 default path — **discouraged**; if ever used, strict size limits + CSP-style considerations still apply. |

Also document **`UserEmailStore`** / **`IUserTwoFactorStore`** interactions only if relevant; the **pilot** must prove **confirm** or **reset** email end-to-end without shipping **secrets** to logs.

### 3.6 SMTP transport (required)

- Support **submission** to a **transactional provider** (Brevo, SendGrid, SES SMTP interface, etc.) using **auth + TLS** per provider docs.
- **Local dev:** default wiring should send to **Mailpit** (or chosen sink) so developers see messages **without** real internet delivery; document switching env to a real relay for integration tests.
- **Timeouts and connection limits** — document defaults; avoid hanging calls blocking gRPC threads (use **virtual threads** for blocking I/O **or** bounded executor — document choice).
- **Sync vs async delivery:** v1 assumes **synchronous send** over gRPC (backend awaits SMTP acceptance). Document **latency implications**; if product later needs fire-and-forget, add a **queue** (Redis, outbox) in a **separate prompt** — **not** implied by v1.

### 3.7 Authentication from backend to worker (required)

Mirror **`many_faces_push`** patterns: optional **metadata** header (e.g. **`x-mailer-worker-token`**) validated by a **server interceptor**; **TLS + optional mTLS** on the gRPC listener using the **same conceptual split** as push/search (server cert + key; optional client CA PEM). Document worker env vars in submodule `README.md` and add **`docs/guides/mailer-grpc-tls-mtls.md`** **or** extend **`docs/guides/mailer-local-dev.md`** with a dedicated TLS section that cross-links **[`docs/guides/push-grpc-tls-mtls.md`](../guides/push-grpc-tls-mtls.md)** and **[`docs/guides/elasticsearch-grpc-tls-mtls.md`](../guides/elasticsearch-grpc-tls-mtls.md)**. Prefer **consistent env suffixes** across workers (`*_GRPC_TLS_CERT_FILE`, `*_GRPC_TLS_KEY_FILE`, `*_GRPC_MTLS_CLIENT_CA_FILE`) with a **`MAILER_`/`MAIL_WORKER_`** prefix chosen and listed in **one** table. **Do not** ship an open gRPC listener on shared networks without auth.

**Header name consistency:** If the worker validates **`x-mailer-worker-token`**, the **backend** `CallOptions` metadata key must **match byte-for-byte** (document in both READMEs — same lesson as **`x-push-worker-token`** in `PushWorkerGrpcClient.cs`).

### 3.8 JVM and container runtime (required)

- Document **`JAVA_TOOL_OPTIONS`** or equivalent for **container-friendly defaults** (e.g. **`-XX:MaxRAMPercentage=75.0`** on constrained hosts); avoid unbounded heap on small VMs.
- **Image:** Prefer **distroless** or **Temurin JRE** slim images; run as **non-root**; read-only root filesystem **where compatible** with temp file needs of Jakarta Mail.
- **Signals:** JVM must respond to **SIGTERM** for fast Kubernetes / Compose shutdown (grpc-java shutdown hook already planned — verify **SMTP** does not block shutdown indefinitely).

### 3.9 Supply chain, static analysis, and formatting (recommended)

- **Gradle:** Enable **`--warning-mode all`** in CI at least once per upgrade wave; consider **`./gradlew dependencyUpdates`** or Renovate on the submodule repo.
- **Optional:** **OWASP Dependency-Check** or **GitHub Dependabot** on the submodule; **Spotless** / **google-java-format** for consistent Java style (no Spring formatter).
- **Pin** gRPC, Netty shaded, Angus Mail, and template engine **versions** explicitly in `build.gradle.kts`; document **upgrade cadence** (security patches vs feature bumps).

---

## 4. Monorepo integration (`many_faces_main`)

### 4.1 Root documentation (required)

- **`.gitmodules`** — register submodule at `many_faces_mailer/`.
- **Root `README.md`** — Architecture table: add **Mailer / SMTP** row with link to `many_faces_mailer/README.md`.

### 4.2 `docker-compose.dev.yml` (required)

- Attach **`mailer-worker`** (and optional **Mailpit**) to **`many_faces_main_dev-network`** using the same pattern as **`push-worker`** / **`search-worker`**.
- Add **`many_faces_backend`** environment placeholders, e.g.:

  - **`Mail:Enabled`** (bool)
  - **`Mail:WorkerGrpcUrl`** (e.g. `http://mailer-worker:50054` for cleartext dev — **non-colliding** port)
  - Optional: **`Mail:WorkerAuthToken`**, TLS fields mirroring **`Search:`** / **`Push:`** naming (`Mail:WorkerTlsServerCaPath`, …) if using **https://**

- **Do not** expose mailer gRPC on a public host interface without TLS and auth.

### 4.3 Scripts (required)

Extend **`scripts/start-all-dev.sh`** / **`scripts/stop-all-dev.sh`** (or **`ENABLE_MAILER_WORKER=1`**) so the stack can run **without** the mailer when disabled ( **`Mail:Enabled=false`** must not crash the API at startup).

Also extend **`scripts/clear-all-dev.sh`**: **Phase 1** `docker compose down` for **`many_faces_mailer/docker-compose.yml`** and any **`docker-compose.tls-smoke.yml`** (use the **same** `-p` project names as your smoke script, mirroring **`mf-push-tls-smoke`** / **`mf-search-tls-smoke`**); **Phase 2** `docker rm -f` for **`mailer-worker-dev`** and named TLS smoke containers; **Phase 3–5** grep prefixes for **`many_faces_mailer_`**, **`mf-mailer-tls-smoke_`** (or whatever project name you choose — document it in one place). Optionally add a **`many_faces_mailer`** section to **`scripts/rebuild-all-dev.sh`** if other workers are rebuilt there for parity.

When wiring root **`docker-compose.dev.yml`**, follow the **`PUSH_DEV_*`** pattern: e.g. **`MAIL_DEV_*`** (or `MAILER_DEV_*`) env placeholders for **`Mail__*`** so `start-all-dev.sh` can export them consistently.

### 4.4 New guide in `docs/guides/` (required)

Add **`docs/guides/mailer-local-dev.md`** (or agreed filename) covering:

- Mailpit (or chosen sink) URL for reading mail in dev.
- Env vars for **`many_faces_mailer`** and **`many_faces_backend`**.
- **grpcurl** smoke example for **`SendTemplatedEmail`** with a **safe** template id.
- **Security:** never commit SMTP passwords; use gitignored `.env` or Docker secrets.
- **Deliverability (brief):** for real relays, domain **SPF**, **DKIM**, and **DMARC** are required; link to provider docs — the worker cannot fix DNS misconfiguration.

Link the guide from **`docs/README.md`** when it exists.

### 4.5 CI (required)

- **`docker compose … config`** validation including the new services.
- **Gradle** CI in the submodule: **`./gradlew test`** on PRs.
- If C# is generated from `many_faces_mailer/proto/`, add a **drift check** consistent with **`many_faces_push`** / search protos.
- **`buf lint`** / **`buf breaking`** against **`main`** (or agreed baseline) when the monorepo already uses **`buf`** for sibling protos — **same** `buf.yaml` / module roots or a documented exception.

### 4.6 Parent monorepo `.github/workflows/ci.yml` (required)

Mirror existing **`infra_many_faces_push`** / **`infra_many_faces_elastic`** jobs:

1. Add **`infra_many_faces_mailer`** — `actions/checkout` with **`submodules: recursive`**, then `docker compose -f many_faces_mailer/docker-compose.yml config`. If **`docker-compose.tls-smoke.yml`** exists, add a second step mirroring push/elastic: `MAILER_TLS_SMOKE_CERT_DIR=/tmp` (or the exact env var your compose file requires) `docker compose -f many_faces_mailer/docker-compose.tls-smoke.yml config`.
2. Add **`java_many_faces_mailer`** — `actions/setup-java` with **temurin** + **cache** on `gradle/`, run **`./gradlew test`** from `many_faces_mailer/`.
3. If **`docker-compose.tls-smoke.yml`** + a root script exist (mirroring **`many_faces_push/scripts/smoke-grpc-tls.sh`**), add **`smoke_mailer_worker_grpc_tls`** (or fold into an existing matrix) — **grpcurl** + optional **.NET** channel test gated on an env flag, same ergonomics as **`PushWorkerTlsEndToEndSmokeTests`**.
4. If **`docker-compose.dev.yml`** in the root references the mailer, extend any **existing** “validate root compose” or **matrix** script that iterates submodule directories (search `ci.yml` for `many_faces_push`) so **`many_faces_mailer`** is included.
5. Update **`docs/guides/testing-and-ci-matrix.md`** with a **Mailer** row when CI/scripts exist.

---

## 5. Backend (`many_faces_backend`) — complete migration to gRPC mailer

### 5.1 Configuration (required)

Introduce **`MailOptions`** bound to section **`Mail:`** with environment override **`Mail__*`** in Docker (same convention as **`Push:`** / **`Push__*`**).

Minimum keys:

- **`Enabled`**, **`WorkerGrpcUrl`**, **`GrpcDeadlineSeconds`**
- Optional: **`WorkerAuthToken`**, TLS fields mirroring **`SearchOptions`** / **`PushOptions`**
- **`DefaultLocale`** (BCP 47) for callers that omit locale
- Optional: **`DefaultFrom`** / branding — if **not** in backend, document that **`From:`** is **worker-only** config (single sender identity for v1).

**When `Mail:Enabled` is false:** **`IEmailSender`** should **no-op** (log at **Warning** or **Information** with clear text) **without throwing**, so local dev and tests without Mailpit do not crash registration flows; document product UX (“email not configured in this environment”).

**Locale for Identity:** Document how **`many_faces_backend`** resolves **`locale`** for a user (e.g. `UserManager` custom claim, `CultureInfo`, UI preference stored in DB, or **`DefaultLocale`** fallback).

### 5.2 gRPC channel factory extension (required)

Extend **`GrpcWorkerChannelFactory`** with **`FromMail(MailOptions o)`** (or equivalent) so **HTTP/2 cleartext** and **TLS/mTLS** rules stay **identical** to search/push workers. Reuse **`CreateChannel`**, **`ValidateHttpUrlHasNoTlsOptions`**, and existing certificate disposal patterns.

When **`Mail:WorkerGrpcUrl`** uses **`http://`**, mirror the existing **`Program.cs`** pattern: enable **`AppContext.SetSwitch("System.Net.Http.SocketsHttpHandler.Http2UnencryptedSupport", true)`** only for that scheme (do **not** enable globally for **https://**).

### 5.3 gRPC client abstraction (required)

- Add **`IMailerWorkerClient`** (name adjustable) with **`SendTemplatedEmailAsync`** returning a **nullable** or **optional** result when **`Mail:Enabled`** is **false** (same ergonomics as **`IPushWorkerClient`** when disabled).
- Register **singleton** channel + client consistent with **`PushWorkerGrpcClient`** / search worker patterns; implement **`IDisposable`** if the channel owns disposable certificates.

### 5.4 Replace or prevent “direct mailer” in .NET (required)

- **Search** the backend for any **`SmtpClient`**, **MailKit**, **`IEmailSender`**, or ad-hoc HTTP calls to SendGrid/Resend — **centralize** all transactional sends behind **`IMailerWorkerClient`** (or a thin **`IEmailDispatchService`** façade used by domain code).
- **ASP.NET Core Identity — `IEmailSender`:** register an implementation **`MailerGrpcEmailSender`** (name adjustable) that maps Identity’s **`SendEmailAsync`** inputs to **`template_id` + `locale` + `params`** for the **confirm email** / **reset password** flows. **Document** the **`template_id`** values and required **params** (callback URL, user id, token encoding rules) in **`many_faces_mailer/README.md`** and the new **`docs/guides/mailer-local-dev.md`**.

#### 5.4.1 `Program.cs` and DI registration checklist (required)

The implementing agent must verify **explicitly** (tick in PR description):

1. **`services.Configure<MailOptions>(…)`** (or binding from `builder.Configuration.GetSection(MailOptions.SectionName)`).
2. **`services.AddSingleton<IMailerWorkerClient, MailerWorkerGrpcClient>()`** (or factory) **before** any service that consumes it.
3. **`services.AddTransient<IEmailSender, MailerGrpcEmailSender>()`** (or scoped if required by Identity) — **after** `AddIdentity` / `AddDefaultTokenProviders` so **`UserManager`**-based callers resolve.
4. **`AddIdentity`** / **`AddIdentityCore`** options: if **`RequireConfirmedEmail`** is **true**, document that **first login** may fail until mail is sent — **`Mail:Enabled=false`** must still yield a **defined** UX (log + optional dev bypass documented in guide, **not** silent mystery failures).
5. **Link generation:** confirm **`LinkGenerator`** (minimal APIs) or **`IUrlHelper`** is available where **`MailerGrpcEmailSender`** builds confirmation/reset URLs — **HTTPS** scheme in non-dev environments; avoid **localhost** links in staging unless intentional.
6. **`appsettings.Development.json`** — safe defaults: `Mail:Enabled` false unless developer opts in.

#### 5.4.2 Identity flows — parameters and templates (required)

Document in the **template catalog (§3.5.1)** at minimum:

| Flow | Suggested `template_id` (example) | Params the backend must supply (examples) | Notes |
| ---- | -------------------------------- | ------------------------------------------- | ----- |
| **Email confirmation** | `identity_email_confirm` | `confirm_url`, `user_name`, `expiry_hours` | URL must be built in .NET from **`UserManager.GenerateEmailConfirmationTokenAsync`** + **`GenerateEmailConfirmationLink`** (or equivalent) — **token string never logged**. |
| **Password reset** | `identity_password_reset` | `reset_url`, `user_name`, `expiry_minutes` | Same discipline for reset token / link APIs. |

If a flow is **out of scope for v1**, state it explicitly (e.g. **2FA email**, **magic link**) so agents do not half-implement.

### 5.5 Domain call sites (required)

- Pick **one pilot flow** for v1 beyond Identity (optional): e.g. **admin test send** endpoint or **one** product event — must use **`SendTemplatedEmail`** with **no HTML in .NET**.

### 5.6 Observability (required)

- Forward **correlation** metadata (e.g. **`X-Request-Id`** or W3C **`traceparent`**) into gRPC **metadata** (not only HTTP headers on the API edge) so mailer logs join API traces; document exact **metadata key names** (case-insensitive rules per gRPC).

### 5.7 Resilience (recommended)

- Document **retry policy** on the **backend** for **`UNAVAILABLE`** vs **non-retryable** gRPC codes; warn about **duplicate emails** if backend retries blindly — **`idempotency_key`** should eventually be honored (v1 may log only).
- Optional: **circuit breaker** or **health-gated** sends when worker is down (fail fast vs queue — product choice).

### 5.8 OpenTelemetry and metrics (optional v1)

- If other Many Faces services export **OTLP**, add **optional** Java agent or **micrometer + OTLP** bridge **only** if dependency weight is acceptable; otherwise document **future** metrics: send latency histogram, SMTP failure counter by classified reason, template_id cardinality policy (**low** cardinality labels only — no raw email addresses in labels).

---

## 6. Security and privacy

### 6.1 Network exposure (required)

- **Mailer gRPC** listens on **internal Docker / cluster networks only** — same stance as **`many_faces_push`** §6.1.
- **Mailpit / sink SMTP** must **not** be reachable from the public internet in shared dev environments without authentication (Mailpit supports auth — document if exposing beyond localhost).

### 6.2 Data handling and abuse (required)

- **Worker is not an authorization service** — backend must not call mailer for recipients who fail tenancy / capability checks.
- **PII in params** — templates must avoid logging full email bodies with secrets; **redact** tokens in logs (show prefix only); **never** log **`idempotency_key`** if it embeds PII.
- **Rate limiting** — document whether v1 relies on **backend** only or adds **simple** worker-side throttles (per-**caller** IP is irrelevant on internal gRPC — prefer **global** + **per-template** limits if implemented).
- **SSRF / open redirects** — links embedded in templates (`returnUrl`, `continue`) must be **validated or allow-listed** in the **backend** before being passed as params; the worker must **not** “fix” untrusted URLs.
- **Header injection** — reject **`\\r`**, **`\\n`**, and **`\\0`** in param values that can flow into **Subject**, **From**, or **custom headers** if ever added.
- **HTML injection vs escaping** — document which template fields are **trusted** (static markup) vs **untrusted** (user-supplied); never mark untrusted HTML as **safe** unless product explicitly requires rich user HTML in mail (**out of scope v1**).

### 6.3 Threats to document in submodule `README.md` (required)

- **Spoofed gRPC sends** — mandatory token/mTLS + hardened compose: [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) **§12** (**MAIL-1**, **MAIL-2**, **MAIL-7**).
- **Credential theft** — SMTP passwords are **high value**; restrict file mounts and env injection; rotate on compromise.
- **`action_link` / template injection:** **MAIL-3**, **MAIL-4** in the same v2 section (server-built URLs only).

---

## 7. Testing strategy (required)

| Layer | Minimum expectation |
| ----- | ------------------- |
| **Java mailer** | Unit tests: template rendering per locale, fallback locale, unknown template, HTML escaping, param substitution; fake SMTP session or GreenMail integration **optional** but valuable. |
| **Backend** | Unit tests: **`IMailerWorkerClient`** fake; **`MailerGrpcEmailSender`** maps Identity call to expected proto fields; **`Mail:Enabled=false`** does not throw on startup. |
| **Contract** | Golden tests or snapshot tests for **one** rendered HTML per locale (optional in Java) to catch accidental escaping regressions. |
| **Integration** | Optional: **Testcontainers** + Mailpit image or **GreenMail** for one happy-path SMTP send in CI (may be heavy — document skip if too slow). |

Document **manual smoke** in **`docs/guides/mailer-local-dev.md`**: trigger Identity action → Mailpit shows message → link completes flow in browser.

---

## 8. Observability and operations (required)

- **Structured logs (Java):** include **`correlation_id`**, **`template_id`**, **`locale`**, **SMTP host (not password)**, outcome, duration ms; **never** log **`params`** values that contain secrets or full URLs with tokens.
- **Backend:** log gRPC **`StatusCode`** + **`Detail`** on failure (truncate); correlate with **`X-Request-Id`** / trace id.
- **Runbook bullets** in **`docs/guides/mailer-local-dev.md`**: “all mail fails” → check **`Mail:Enabled`**, worker health, SMTP auth, TLS clock skew, provider suppression list; “only one locale wrong” → missing bundle key; “messages stuck” → synchronous SMTP blocking — check deadline / thread pool.

---

## 9. Delivery phases (recommended)

1. **Phase A** — Submodule skeleton: gRPC + health + config + logs + Mailpit compose; **no** real SMTP provider required.
2. **Phase B** — Templates + i18n + **`SendTemplatedEmail`** end-to-end to Mailpit.
3. **Phase C** — **`many_faces_backend`** `MailOptions`, **`GrpcWorkerChannelFactory`**, **`IMailerWorkerClient`**, **`IEmailSender`** for Identity (**§5.4.1–5.4.2**).
4. **Phase D** — Optional real relay env + **mTLS** / token auth: [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) **§12** (**MAIL-*** hardening rows).

The agent may **compress** phases if product demands, but **document risks** when skipping **gRPC auth** or **TLS** (use **`TRACK-SHV2-*`** in v2 report if waived).

---

## 10. Anti-patterns and rejection criteria (required)

Reject (or rewrite) implementations that:

- Forward **`IEmailSender`’s `htmlMessage`** as the primary body while still claiming **worker-owned templates** without documenting **pattern B** (**§3.5.2**).
- Add **Spring** “just for `@Configuration`” — violates **non-goals**.
- Expose **`MailerService`** on **`0.0.0.0`** in production compose without **TLS** and **auth** story.
- Log **full** confirmation/reset URLs or **raw SMTP credentials**.
- Use **`System.out.println`** instead of structured logging for the worker process.
- Retry **`SendTemplatedEmail`** on the backend for **non-idempotent** user-visible flows **without** deduplication strategy (duplicate reset emails).

---

## 11. Definition of done — expanded acceptance (required)

**Status:** Completed in `many_faces_main` / submodules **2026-05-12** (compose validated locally + CI; operator still runs **§ Manual acceptance** in `docs/guides/mailer-local-dev.md` before release).

- [x] **Compose:** `docker compose -f many_faces_mailer/docker-compose.yml config` succeeds; root **`docker-compose.dev.yml`** validates.
- [x] **CI:** Parent **`ci.yml`** includes **`infra_many_faces_mailer`** + **`java_many_faces_mailer`** per **§4.6**; submodule workflow passes **`./gradlew test`**.
- [x] **Proto:** Committed **`proto/`** + documented codegen; **C#** stubs wired in backend project; optional **`buf`** checks — **N/A** (no `buf` workspace in monorepo; codegen via `BeDemo.Api.csproj` `Protobuf` item).
- [x] **Security:** gRPC **metadata token** enforced when env is set; no secrets in repo; **§6** threats documented in submodule `README.md`.
- [x] **Product:** Identity **confirm** + **reset** templates with **≥2 locales** (`en`, `sk`) in worker; backend **`MailerGrpcEmailSender`** covered by unit tests; **browser E2E** — operator checklist (**Manual acceptance**) in **`docs/guides/mailer-local-dev.md`**.
- [x] **Docs:** **`docs/guides/mailer-local-dev.md`** + **`docs/README.md`** link + root **`README.md`** architecture row.
- [x] **Dev ergonomics:** **`scripts/clear-all-dev.sh`** removes mailer + TLS smoke resources per **§4.3**; **`docs/guides/testing-and-ci-matrix.md`** documents mailer commands when CI exists.

---

## 12. Final checklist — tasks for the implementing agent

**Completion record:** All items below are done for the **2026-05-12** delivery. For new work, copy unchecked rows into a PR and tick there (see [`docs/prompts/README.md`](./README.md)).

### Submodule `many_faces_mailer` (Java + gRPC + SMTP)

- [x] Create submodule layout per **§3.2** (`README.md`, `Dockerfile`, `docker-compose.yml`, Gradle wrapper, `proto/`, `src/main/java`, resources for templates + i18n, `.env.example`, `.gitignore`).
- [x] Pin **Java** and **Gradle** versions in `README.md`; use **Java 21+** toolchain per **§3.3**; **no** Spring dependencies in the dependency graph.
- [x] Add **`proto/manyfaces/mailer/v1/*.proto`** with **`SendTemplatedEmail`** RPC and messages per **§3.4**; document regeneration for **C#**.
- [x] Implement **gRPC server** with **`grpc.health.v1`**, graceful shutdown, structured JSON logs.
- [x] Implement **Pebble/JTE/Mustache** rendering + **ResourceBundle** (UTF-8) i18n per **§3.5**; ship **at least one** pilot template (e.g. **password reset** or **email confirm**) with **≥2 locales**.
- [x] Implement **Angus Mail** SMTP sender with TLS modes documented; **Mailpit** path for dev per **§3.6**.
- [x] Add **gRPC auth interceptor** (metadata token) per **§3.7** when **`MAIL_WORKER_AUTH_TOKEN`** (or agreed name) is set.
- [x] Add **JUnit 5** tests per **§7**; GitHub Actions per **§4.5**; optional **Spotless** / format check.
- [x] Document **JVM** / container defaults per **§3.8** in submodule `README.md`.

### Monorepo wiring (`many_faces_main`)

- [x] Register **git submodule** at `many_faces_mailer/`; document clone/init in root `README.md`.
- [x] Update **root `README.md`** architecture table with **Mailer** entry.
- [x] Extend **`docker-compose.dev.yml`** per **§4.2**; **verify port map** per **§2.3** (no collision with ai **50051** / elastic **50052** / push **50053**).
- [x] Extend **`scripts/start-all-dev.sh`** / **`scripts/stop-all-dev.sh`** (or env flag) per **§4.3**.
- [x] Extend **`scripts/clear-all-dev.sh`** (and optionally **`scripts/rebuild-all-dev.sh`**) per **§4.3**.
- [x] Add **`docs/guides/mailer-local-dev.md`** per **§4.4**; link from **`docs/README.md`**.
- [x] Extend **`docs/guides/testing-and-ci-matrix.md`** per **§4.6** when CI exists.
- [x] Extend **`.github/workflows/ci.yml`** per **§4.6** (`infra_many_faces_mailer`, `java_many_faces_mailer`, optional TLS smoke); include submodule in any compose-matrix validation script if present.

### Backend (`many_faces_backend`)

- [x] Add **`MailOptions`** + **`Mail:`** / **`Mail__*`** configuration per **§5.1**.
- [x] Extend **`GrpcWorkerChannelFactory`** with **`FromMail`** per **§5.2**; preserve **h2c** switch behavior for **`http://`** only.
- [x] Add generated **C#** gRPC stubs from submodule `proto/` (same policy as push/search); commit or CI-generate per monorepo standard; optional **`buf`** per **§4.5**.
- [x] Implement **`IMailerWorkerClient`** + registration + **`IDisposable`** per **§5.3**; metadata header name matches worker per **§3.7**.
- [x] Complete **`Program.cs` / DI** checklist **§5.4.1**; document Identity template matrix **§5.4.2** in catalog.
- [x] Implement **`IEmailSender`** for Identity per **§5.4** and **§3.5.2** (explicit pattern **A** or **B**); document **template_id** ↔ Identity flow mapping in the catalog (**§3.5.1**).
- [x] Add **pilot** non-Identity send (optional) per **§5.5**.
- [x] Add **unit tests** with fake client per **§5** / **§7**; verify disabled startup path.

### Security and acceptance

- [x] Document **auth** on gRPC and **no public exposure** per **§3.7** / **§6**.
- [x] Satisfy **expanded definition of done** (**§11**): CI jobs, compose validation, catalog, docs links.
- [x] **Manual smoke** per **§8**: steps in **`docs/guides/mailer-local-dev.md`** (**Manual acceptance**); operator verifies Mailpit + link flow; **§10** anti-patterns avoided in code review.
- [x] **No secrets** committed; `.gitignore` covers `.env` and credential files.

---

**End of prompt.**
