# Development — monorepo, CI, Node, Python, errors

This document covers **how we build and test** `_mfai_demo` (root repo with submodules / nested apps) and **contracts** shared by FE, admin, BE, and tooling.

## Layout

| Area | Path | Stack |
|------|------|--------|
| Backend API | `be_demo/` | .NET, EF Core, PostgreSQL |
| Main frontend | `fe_demo/` | Vite, React, Yarn 4 |
| Admin UI | `admin_demo/` | Vite, React, Yarn 4 |
| AI gRPC service | `ai_demo/` | Python 3.11+, gRPC, Ruff |
| PostgreSQL dev stack | `db_demo/` | Docker Compose |
| Redis dev stack | `redis_demo/` | Docker Compose |
| Logger UI (Dozzle) | `logger_demo/` | Docker Compose |

The **root** repository runs aggregated CI (see below). Each submodule that ships code also has its own `.github/workflows/ci.yml` for standalone pushes to that repo.

## Node.js (fe_demo, admin_demo)

- **Version**: `22.14.0` (`.nvmrc` in repo root, `fe_demo`, and `admin_demo`).
- **Package manager**: Yarn 4 via Corepack (`packageManager` in each `package.json`).
- **`engines.node`**: `>=22.14.0` in `fe_demo` and `admin_demo`.

Use `nvm use` (or your version manager) before `yarn install`. Older Node versions cause Vite warnings or failures.

## Python (ai_demo)

- **CI / recommended**: **Python 3.11** (matches `pyproject.toml` target and GitHub Actions).
- Generated gRPC files (`proto/*_pb2*.py`) are **gitignored**; CI and local dev generate them with:

  ```bash
  cd ai_demo
  ./generate_proto.sh
  ```

  or `python -m grpc_tools.protoc -I proto --python_out=proto --grpc_python_out=proto proto/health.proto`.

- **Lint**: `./lint.sh` (Ruff). **Tests**: after generating protos, `PYTHONPATH=. pytest test_server.py` (no PyTorch required for health-check tests).

## Git hooks (Husky + commitlint)

- Husky **9**: hooks **do not** source `husky.sh`. Use a shebang and direct commands, e.g. `npx --no -- commitlint --edit "$1"`.
- **fe_demo** and **admin_demo**: Yarn `prepare` → Husky; `commitlint.config.js` (ESM).
- **be_demo**: run **`yarn install`** in `be_demo/` (Yarn 4 / PnP as in `package.json`) so Husky and commitlint are available; **`commitlint.config.cjs`** + `.husky/commit-msg` runs `yarn exec commitlint` (same rules as FE/admin). **`node_modules/`** is gitignored for edge cases; this repo uses Plug’n’Play (`.pnp.cjs`).

### Commit message rules (all repos with commitlint)

Conventional Commits: **`type(scope): subject`**

| Rule | Detail |
|------|--------|
| **type** | One of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` |
| **scope** | Recommended, not empty (warning if missing): short area, e.g. `wall`, `fe`, `admin`, `api`, `ci` |
| **subject** | **lower-case** or **sentence-case**; no trailing period; max **100** chars |
| **Avoid** | Random **ALL CAPS** acronyms in the subject (e.g. write “ci workflow” not “CI Workflow”) — `subject-case` will fail |

**Examples (valid)**

```text
feat(wall): add host viewer detection for create button
fix(admin): show api error text in moderation toasts
test(api): cover wall list when face is missing
chore: bump fe_demo submodule pointer
docs: expand development and ci notes
```

**Examples (invalid)**

```text
feat: no scope (warning)
feat(WALL): WRONG CASE SUBJECT
fix(api): Ends with period.
```

## Continuous integration

### Root `mfai_demo` — workflow `.github/workflows/ci.yml`

On push/PR to `main` / `master`, with **submodules recursive**:

| Job | What runs |
|-----|-----------|
| **be_demo** | `dotnet restore`, `dotnet format --verify-no-changes`, Release build, `dotnet test` |
| **fe_demo** | Node from `fe_demo/.nvmrc`, `yarn install --immutable`, `yarn validate`, `yarn test`, `yarn build` |
| **admin_demo** | Same pattern with `admin_demo/.nvmrc` |
| **ai_demo** | Python **3.11**, pip install **grpcio 1.68.x** + ruff + pytest (no torch), **generate protos**, `ruff` + `pytest test_server.py` |
| **infra_db_demo** | `docker compose -f db_demo/docker-compose.yml config` |
| **infra_redis_demo** | `docker compose -f redis_demo/docker-compose.yml config` |
| **infra_logger_demo** | `docker compose -f logger_demo/docker-compose.dev.yml config` |
| **monorepo_scripts** | Runs **`./ci-local.sh`**: `lint-all.sh` → `build-all.sh` → `test-all.sh` (with `SKIP_CYPRESS=1`) |

The **monorepo_scripts** job is the parity check that root orchestration scripts match what individual jobs already cover; it fails if e.g. `lint-all.sh` or `verify-ci.sh` drifts from CI.

Commits that **only** bump submodule SHAs and/or `docs/` still trigger this pipeline so every merge is validated against the checked-in submodule tree.

## Root shell scripts (monorepo)

Run from repository root (submodules checked out). Make executable if needed: `chmod +x *.sh **/lint.sh ai_demo/verify-ci.sh`.

| Script | Purpose |
|--------|---------|
| **`ci-local.sh`** | One entrypoint: **lint-all** → **build-all** → **test-all**. Sets `SKIP_CYPRESS=1` unless you override. |
| **`lint-all.sh`** | Calls `fe_demo`, `be_demo`, `admin_demo`, `ai_demo` each `./lint.sh` (FE/admin: `yarn validate`; BE: `dotnet format`; AI: Ruff). |
| **`build-all.sh`** | `be_demo`: `dotnet build -c Release`; `fe_demo` / `admin_demo`: `yarn build`; `ai_demo`: `./verify-ci.sh`. |
| **`test-all.sh`** | `dotnet test` (BE), `yarn test` (FE/admin), **`ai_demo/verify-ci.sh`**, optional Cypress e2e unless `SKIP_CYPRESS=1`. |
| **`status-all.sh`** | Docker / HTTP status of dev containers (does not run builds). |

**`ai_demo/verify-ci.sh`**: local venv `.venv-ci-verify/`, gRPC stub generation, ruff, pytest — aligned with the **ai_demo** GitHub Actions job (no PyTorch).

### Submodule-only repos

Each of `be_demo`, `fe_demo`, `admin_demo`, `ai_demo`, `db_demo`, `redis_demo`, `logger_demo` includes its own **CI** workflow for development outside the monorepo.

## API error messages in the browser

User-facing fetch wrappers use **`getApiErrorMessage`** (`fe_demo` / `admin_demo`: `src/utils/apiErrorMessage.ts`):

- Parses JSON bodies: `{ "error": "..." }`, ASP.NET **ProblemDetails** (`detail`, then `title`), and flat **`errors`** maps (validation).
- Non-JSON bodies shorter than ~280 characters are shown as plain text; longer bodies fall back to a generic message.

**Backend**: many endpoints return `new { error = "..." }` or ProblemDetails; both are covered.

## Testing (quick reference)

| Suite | Command | Notes |
|--------|---------|--------|
| BE | `dotnet test` in `be_demo` | Integration tests; `Testing` environment where configured. |
| FE | `yarn test` in `fe_demo` | Vitest. |
| Admin | `yarn test` in `admin_demo` | Vitest. |
| AI | `pytest test_server.py` in `ai_demo` | After proto generation; `PYTHONPATH=.` |

Wall ticket API behaviour: [wall-tickets.md](./wall-tickets.md).

## Functionality gaps (intentional / backlog)

Not implemented in this baseline (see also **Future** in [wall-tickets.md](./wall-tickets.md)):

- **Security / ops hardening**: rate limiting, strict CORS policy tuning (deferred).
- **Face-level moderators** (only global Admin/SuperAdmin for wall moderation today).
- **Notifications** for ticket state changes, **reports**, rich moderation filters.
- **Cancelling** delayed deny deletion jobs if workflow changes; configurable retention vs fixed 2 days.

i18n: wall and settings strings exist for **en / sk / cz**; other app areas may still be English-only — extend `src/i18n/locales` as needed.

## Related docs

- [wall-tickets.md](./wall-tickets.md) — feature behaviour, API tables, Redis worker, manual checks.
- [CHAT_ROOMS_TESTING_AND_OPERATIONS.md](./CHAT_ROOMS_TESTING_AND_OPERATIONS.md) — chat / rooms operations.
- [GIT_SUBMODULES_SETUP.md](../GIT_SUBMODULES_SETUP.md) — submodule checkout and updates.
