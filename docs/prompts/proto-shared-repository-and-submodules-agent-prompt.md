# Many Faces — Shared protobuf contracts repository (`many_faces_proto`) — Agent prompt

**Language:** All **new** prose you add to repositories (README, guides, comments in new code) must be **English**.

**Mission:** Introduce a **dedicated git repository** that holds **all `.proto` definitions** shared across Many Faces services (e.g. **`many_faces_backend`**, **`many_faces_push`**, **`many_faces_mailer`**, **`many_faces_elastic`**, **`many_faces_ai`**). Consumer repositories must consume those protos via a **git submodule** (or an equivalent pinned checkout) so there is **one canonical wire contract** per API version. Remove or avoid long-term **duplicate proto trees** inside individual service repos.

**Canonical precedent:** Today several submodules carry their own `proto/` (or generated stubs with documented copy paths). This prompt standardizes on **`many_faces_proto`** as the **single source of truth**, aligned with internal gRPC patterns documented in **[`push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md`](./push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md)**, **[`elasticsearch-search-infra-agent-prompt.md`](./elasticsearch-search-infra-agent-prompt.md)**, and **[`smtp-mailer-java-grpc-worker-agent-prompt.md`](./smtp-mailer-java-grpc-worker-agent-prompt.md)** — same **`manyfaces.*.v1`** package style, **`csharp_namespace`**, TLS/mTLS metadata auth where applicable, and **CI compose smoke** parity where protos drive worker images.

**Agent discipline:** Prefer **one submodule pointer revision** consumed consistently across services that call each other in the same release train. When ambiguous, choose **monorepo-first linking** (see **§4**) so `git clone --recursive` on **`many_faces_main`** yields a working dev tree. Document **every** `git submodule update` requirement in root **`README.md`** and **[`docs/guides/git-submodules.md`](../guides/git-submodules.md)**.

---

## 1. Problem statement

### 1.1 Today

- **Protobuf sources** may live beside **`many_faces_push`**, **`many_faces_mailer`**, **`many_faces_elastic`**, or be referenced from **`many_faces_backend`** with language-specific codegen.
- **Snapshot (re-verify with `rg '\.proto$'` before migration):** worker contracts today live under **`many_faces_elastic/proto/manyfaces/search/v1/`**, **`many_faces_push/proto/manyfaces/push/v1/`**, **`many_faces_mailer/proto/manyfaces/mailer/v1/`**. **`many_faces_backend`** pulls those three into **`BeDemo.Api.csproj`** via **`Include="..\..\many_faces_*\proto\..."`** (paths relative to **`many_faces_backend/BeDemo.Api/`**, i.e. **two** `..` segments to the monorepo root) plus a local **`Protos/health.proto`**. **`many_faces_ai`** ships **`proto/health.proto`** (and CI runs `grpc_tools.protoc` there). **`ai_demo/proto/health.proto`** may duplicate the health demo — include in inventory if it must stay wire-identical.
- **Risk:** two services ship **different** revisions of the same `package` / RPC names → **runtime failures** or silent **wire incompatibility**.
- **Risk:** copy/paste of `.proto` files between repos → **divergence** and unreviewed drift.

### 1.2 Target

- **`many_faces_proto`** (name adjustable if product standardizes differently) contains **only** contracts and **optionally** small shared messages — not service business logic.
- Each consumer repo has **`proto` → submodule** (or monorepo path) pointing at a **pinned commit** of **`many_faces_proto`**.
- **CI** proves that **linted / agreed** protos compile for **every consumer** on the same pinned SHA (or documents intentional skew with guardrails — discouraged).

---

## 2. Repository naming and scope

### 2.1 Default repository name

Use consistently in **`.gitmodules`**, docs, and CI:

```text
many_faces_proto/
```

Alternatives (`many_faces_api_contracts`, `many_faces_grpc_schemas`) are acceptable only if renamed **everywhere** in one change set (GitHub remote, docs, submodule paths).

### 2.2 What belongs in `many_faces_proto`

| Include | Exclude |
| ------- | ------- |
| **gRPC `service` definitions** and request/response messages used across processes | ORM / EF models, SQL, internal-only DTOs |
| **Shared enums / well-scoped `message` types** reused by multiple services (use sparingly) | Large domain aggregates owned by a single service |
| **`option csharp_namespace`**, `java_package`, `go_package` aligned with existing codegen | Secrets, endpoints, environment-specific tuning |
| Optional **`google.api`** / **`google.rpc`** patterns if product adopts them | Business authorization rules |

### 2.3 Layout (required minimum)

```text
many_faces_proto/
  README.md                 # consumers, versioning, how to bump submodule
  LICENSE                   # or pointer to org policy
  buf.yaml                  # recommended: buf lint + breaking
  buf.lock                  # if using buf deps
  proto/
    manyfaces/
      push/v1/...
      mailer/v1/...
      search/v1/...        # or elastic naming — match existing packages
      common/v1/...        # optional; avoid becoming a junk drawer
  .github/workflows/        # proto CI (lint, breaking vs main)
```

**Rule:** `proto/` is the **only** tree imported by consumers’ codegen; no alternate shadow `proto2/`.

---

## 3. Versioning and API evolution

### 3.1 Package naming

- Keep **version suffix** in package path: `manyfaces.<domain>.v1`.
- **Breaking change policy:** prefer **new package** `…v2` (or new service name under a new major) over silently editing `v1` fields used in production.

### 3.2 Compatibility checks (required direction)

- Add **`buf breaking`** (or equivalent) against **`main`** on PRs touching `proto/**/*.proto`.
- Document in **`many_faces_proto/README.md`** what counts as **breaking** (field number reuse, `required` changes, RPC rename) vs **safe** (comments, `reserved`, doc-only if tooling agrees).

### 3.3 Changelog

- Maintain **`CHANGELOG.md`** or GitHub Releases for **`many_faces_proto`** with **consumer impact** (which services must bump submodule first).

---

## 4. Submodule linking strategies (pick one primary)

Document the **chosen** strategy in **`many_faces_proto/README.md`** and monorepo **`README.md`**.

### 4.1 Strategy A — Monorepo hosts the submodule (recommended phase 1)

- Path: **`many_faces_main/many_faces_proto/`** as a **git submodule** pointing at `many_faces_proto` remote.
- Consumer submodules (`many_faces_backend`, …) **reference** protos from the monorepo layout:
  - **.NET (`BeDemo.Api.csproj`):** keep the **existing pattern**: paths relative to the **`.csproj` directory** (under **`many_faces_backend/BeDemo.Api/`**), typically **`..\..\many_faces_proto\proto\manyfaces\...\*.proto`**, with **`Link="Protos\..."`** so the Solution Explorer tree stays stable — mirror today’s **`..\..\many_faces_push\proto\...`** style, not a single `../` from the wrong working directory.
  - **Go / Gradle / Python in sibling submodules:** prefer **`../../many_faces_proto/proto`** from the consumer repo root (one `..` to monorepo root when the consumer is a direct child of the monorepo), or document **`${MONOREPO_ROOT}`** in compose/codegen scripts.
- **CI on `many_faces_main`:** checkout with **`submodules: recursive`**; one job validates all consumers against the **same** `many_faces_proto` commit.

**Pros:** single `git clone --recursive` for developers. **Cons:** standalone clone of **`many_faces_backend`** without monorepo must submodule **`many_faces_proto`** separately (document clearly).

### 4.2 Strategy B — Nested submodule per consumer

- Each of **`many_faces_backend`**, **`many_faces_push`**, … contains **`proto/`** as submodule → **`many_faces_proto`**.
- **`many_faces_main`** uses **recursive submodules** and pins **nested** SHAs.

**Pros:** each service repo is self-contained in CI. **Cons:** easy to pin **different** `many_faces_proto` commits → **wire skew**; higher operational burden.

### 4.3 Strategy C — Hybrid

- **Phase 1:** Strategy **A**.
- **Phase 2:** add **B** only where a standalone repo **must** build without monorepo (document release process to **bump SHA in lockstep**).

The implementing agent must **state the chosen strategy** in the PR description and align **`.github/workflows/ci.yml`** checkout accordingly.

---

## 5. Consumer integration (required checklists)

### 5.1 `many_faces_backend` (.NET)

- [ ] Replace the three **`Protobuf Include="..\..\many_faces_elastic|push|mailer\proto\..."`** entries with **`..\..\many_faces_proto\proto\manyfaces\...\*.proto`**, preserving **`Link="Protos\manyfaces\..."`** so generated C# namespaces and on-disk layout stay predictable.
- [ ] Decide whether **`Protos/health.proto`** stays backend-local or moves into **`many_faces_proto`** (only if **multiple** processes must share the exact same health wire contract).
- [ ] **Do not blindly bump `Grpc.Tools`** when changing proto paths — **`many_faces_backend`** pins **`Grpc.Tools`** with a **Docker / linux_arm64** rationale in `BeDemo.Api.csproj`; re-validate **`dotnet build`** in CI images after any tools bump.
- [ ] Ensure **`GrpcServices="Client"`** (or project policy) still matches generated code layout.
- [ ] **`dotnet build`** / **`dotnet test`** in CI use submodule checkout.
- [ ] Document **path + bump process** in **`many_faces_backend/README.md`** or backend `docs/`.

### 5.2 `many_faces_push` (Go)

- [ ] `go generate` / **`buf generate`** / `protoc` invocation reads from **`many_faces_proto/proto`**.
- [ ] **`go.mod`** `replace` directive **must not** point to ephemeral machine paths in committed code — use **relative submodule path** within monorepo or a **vendored** copy generated in CI (pick one; document).
- [ ] Regenerate **`gen/`** (or chosen output dir) and ensure **imports** use stable `go_package`.

### 5.3 `many_faces_mailer` (Java / Gradle)

- [ ] `protobuf` / `protoc` `srcDir` points to **`many_faces_proto/proto`** (or symlink strategy — avoid OS-specific hacks without documentation).
- [ ] **`./gradlew build`** succeeds in Docker and host; document **Alpine vs glibc** codegen constraints (see mailer Dockerfile lessons).

### 5.4 `many_faces_elastic` (Go search-worker)

- [ ] Same as push: proto inputs unified; regenerate stubs.
- [ ] TLS smoke scripts unchanged except paths if they reference local proto dirs.

### 5.5 `many_faces_ai` (Python)

- [ ] `grpcio-tools` / `buf` generation documented; **relative import** layout stable for packaging (today **`proto/health.proto`** + `grpc_tools.protoc` in CI — align **`generate_proto.sh`** / **`-I`** with **`many_faces_proto/proto`**).
- [ ] If AI runs only from monorepo compose, prefer **Strategy A** paths.
- [ ] If **`ai_demo`** (or other non-submodule trees) embed **`health.proto`**, either treat as **non-canonical copy** with a comment, or generate from **`many_faces_proto`** to avoid drift.

---

## 6. Monorepo (`many_faces_main`) wiring

### 6.1 `.gitmodules`

- [ ] Register **`many_faces_proto`** with stable URL and path under monorepo root.
- [ ] Update **[`docs/guides/git-submodules.md`](../guides/git-submodules.md)** with **clone / update / bump** instructions.

### 6.2 Root `README.md`

- [ ] Add **`many_faces_proto`** to architecture table and **“first clone”** commands (`--recursive`).

### 6.3 CI (`.github/workflows/ci.yml`)

- [ ] Ensure **checkout** uses **`submodules: recursive`** (or explicit `submodule update`) for jobs that build consumers.
- [ ] Add **`proto`** job on **`many_faces_proto`** OR monorepo job that runs **`buf lint`** / **`buf breaking`** when `many_faces_proto` changes.
- [ ] Fail PR if consumer builds do not agree on **same** `many_faces_proto` ref when using Strategy **A** (e.g. single submodule path — verify no second shadow copy).

### 6.4 Developer scripts

- [ ] Optional: **`scripts/bump-proto-submodule.sh`** — bumps `many_faces_proto` to remote `main` / tag and opens reminder to rebuild all consumers.

---

## 7. `buf` (recommended)

### 7.1 Minimum

- [ ] `buf.yaml` with **`lint.use`** set to a team-agreed preset (**`DEFAULT`** or **`STANDARD`** — exact allowed values depend on **Buf CLI major version**; confirm against `buf --version` and the matching Buf documentation when authoring the file).
- [ ] `breaking` against **`main`** (via **`buf breaking`** against a pinned ref; use the **`breaking`** block / module layout required for that Buf version).

### 7.2 Optional

- [ ] `buf format -w` in CI for consistent style.
- [ ] BSR (Buf Schema Registry) — **out of scope** unless product explicitly wants hosted modules.

---

## 8. Migration plan (phased)

### Phase 0 — Inventory

- [ ] List **all** `.proto` files and consumers (`rg '\.proto$'`, language-specific `gen/` trees).
- [ ] Map **package** → **owning team** / **release coupling**.
- [ ] Record **how each consumer references protos today** (e.g. **MSBuild `Protobuf Include=`** vs **Gradle `protobuf` srcDir** vs **`grpc_tools.protoc -I`**) so path updates do not assume a single “repo root” anchor.

### Phase 1 — Create `many_faces_proto`

- [ ] New repo with layout from **§2.3**, default branch **`main`**, branch protection, CODEOWNERS for `proto/`.
- [ ] Move **one** low-risk API first (e.g. smallest surface) to prove pipeline — or move **all** in one PR if team accepts blast radius.

### Phase 2 — Wire consumers

- [ ] Apply **§5** per language; delete in-repo duplicate protos **after** CI green.
- [ ] Update **TLS smoke** / **grpcurl** docs only if paths change.

### Phase 3 — Lock in process

- [ ] **CHANGELOG** discipline; **release tags** on `many_faces_proto` optional (`v2026.05.0`).
- [ ] Training note for contributors: **never** hand-edit generated files without codegen.

---

## 9. Security and operational notes

- **Protos are not secrets** — do not embed credentials; gRPC **metadata auth** stays documented per worker prompts.
- **Supply chain:** submodule URL must be **HTTPS** or SSH consistent with org policy; pin **commit SHA** for reproducible builds.
- **Legal:** `LICENSE` in **`many_faces_proto`** must be compatible with all consumers.

---

## 10. Documentation deliverables

| Document | Content |
| -------- | ------- |
| **`many_faces_proto/README.md`** | Layout, versioning, `buf` commands, how consumers submodule, bump checklist |
| **`docs/guides/git-submodules.md`** | New section for **`many_faces_proto`** + recursive clone pitfalls |
| **Root `README.md`** | Submodule row + one-liner purpose |
| **`docs/guides/testing-and-ci-matrix.md`** | New row: proto lint / breaking job commands |
| **Consumer READMEs** | Where protos come from and how to regenerate |

---

## 11. Anti-patterns (reject)

- Duplicating the same **`manyfaces.*.v1`** `package` in two directories with **different** message definitions.
- **`replace`** in committed **`go.mod`** pointing to `/Users/...` absolute paths.
- Bumping **`many_faces_proto`** in one consumer only for a **shared RPC** without coordinated release notes.
- Checking in **generated** sources **without** CI drift check when policy says “generate in CI only” (pick one policy; do not mix silently).

---

## 12. Definition of done (expanded)

- [ ] **`many_faces_proto`** exists, public layout matches **§2.3**, default branch protected.
- [ ] **All** cross-service `.proto` files live only in **`many_faces_proto`** (no stale duplicates in consumers).
- [ ] **Every** listed consumer in **§5** builds and tests in CI against the **documented** submodule SHA.
- [ ] **Monorepo** clone with **`--recursive`** yields working **local dev** for at least one representative flow per consumer.
- [ ] **`buf lint`** (or documented alternative) passes on **`many_faces_proto`** `main`.
- [ ] **Breaking change** policy documented; at least one **`buf breaking`** (or equivalent) run documented for contributors.
- [ ] **Docs** from **§10** merged.

---

## 13. Final task checklist (copy to PR / issue; leave `[ ]` in canonical file)

### Repository `many_faces_proto`

- [ ] Create git repository with **`proto/manyfaces/...`** tree and root **`README.md`**, **`LICENSE`**.
- [ ] Add **`buf.yaml`** (+ optional **`buf.lock`**) and CI workflow for **`buf lint`** / **`buf breaking`**.
- [ ] Add **`CHANGELOG.md`** or release process for contract changes.
- [ ] Add **CODEOWNERS** (or org equivalent) for `proto/**`.

### Monorepo `many_faces_main`

- [ ] Add **`many_faces_proto`** submodule entry to **`.gitmodules`** at agreed path.
- [ ] Update root **`README.md`** + **[`docs/guides/git-submodules.md`](../guides/git-submodules.md)**.
- [ ] Update **[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)** checkout + any new **`proto`** / **`buf`** jobs.
- [ ] Update **[`docs/guides/testing-and-ci-matrix.md`](../guides/testing-and-ci-matrix.md)** with commands for contributors.

### Consumer: `many_faces_backend`

- [ ] Point **`Protobuf Include=`** entries at **`..\..\many_faces_proto\proto\...`** (same **`..\..`** depth as today’s sibling-submodule paths); keep **`Link=`** entries; remove obsolete includes into **`many_faces_push` / `many_faces_mailer` / `many_faces_elastic`** proto paths once workers read from **`many_faces_proto`** only.
- [ ] Verify **`dotnet build`** + tests in CI with submodules; do not bump **`Grpc.Tools`** without validating **Docker / arm64** builds per `BeDemo.Api.csproj` comments.
- [ ] Document regeneration in backend **`README.md`** or `docs/`.

### Consumer: `many_faces_push`

- [ ] Point **`protoc` / buf** input path to **`many_faces_proto`**; regenerate **`gen/`** (or project convention).
- [ ] Remove duplicate **`proto/`** if fully superseded; fix **imports** and **Dockerfile** `COPY` paths if needed.
- [ ] Verify **Go tests** + **TLS smoke** script paths.

### Consumer: `many_faces_mailer`

- [ ] Point Gradle **`proto`** `srcDir` to **`many_faces_proto`**; remove in-repo duplicate protos if any.
- [ ] Verify **`./gradlew test`** + **Docker** build (glibc vs musl lessons) in CI.

### Consumer: `many_faces_elastic`

- [ ] Same as push for **search-worker** protos; regenerate stubs.
- [ ] Verify **search** TLS smoke + compose still pass.

### Consumer: `many_faces_ai`

- [ ] Align Python gRPC codegen with **`many_faces_proto`** paths.
- [ ] Document venv / tooling versions for regeneration.

### Governance

- [ ] PR template bullet: “If this PR changes **wire contracts**, bump **`many_faces_proto`** and list **consumers** rebuilt.”
- [ ] Agree **Strategy A / B / C** from **§4** and document in **`many_faces_proto/README.md`**.
- [ ] Run one **end-to-end** manual check: backend ↔ at least **one** worker using **new** proto path (cleartext dev is enough).

---

**End of prompt.**
