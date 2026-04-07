# Development — monorepo, CI, Node, errors

This document covers **how we build and test** `_mfai_demo` (root repo with submodules / nested apps) and **contracts** shared by FE, admin, and BE.

## Layout

| Area | Path | Stack |
|------|------|--------|
| Backend API | `be_demo/` | .NET, EF Core, PostgreSQL |
| Main frontend | `fe_demo/` | Vite, React, Yarn 4 |
| Admin UI | `admin_demo/` | Vite, React, Yarn 4 |

The repository root may aggregate CI; each app also has its own `.github/workflows/ci.yml` when developed standalone.

## Node.js

- **Version**: `22.14.0` (see `.nvmrc` in `fe_demo`, `admin_demo`, and repo root where present).
- **Package manager**: Yarn 4 via Corepack (`packageManager` in each `package.json`).
- **`engines.node`**: `>=22.14.0` in `fe_demo` and `admin_demo` to align local and CI.

Use `nvm use` (or your version manager) before `yarn install`.

## Git hooks (Husky + commitlint)

- Husky **9** does not use `husky.sh`; hooks call tools directly (e.g. `commit-msg` runs `npx --no -- commitlint --edit "$1"`).
- Conventional commits are enforced where `commitlint` is configured.

## Continuous integration

Workflows (when present):

- **`be_demo`**: `dotnet restore`, `dotnet format --verify-no-changes`, build, `dotnet test`.
- **`fe_demo` / `admin_demo`**: Node from `.nvmrc`, `corepack enable`, `yarn install --immutable`, `yarn validate`, `yarn test`, `yarn build`.

Root-level CI should check out submodules **recursively** if jobs run inside nested folders.

## API error messages in the browser

User-facing fetch wrappers use **`getApiErrorMessage`** (`fe_demo` / `admin_demo`: `src/utils/apiErrorMessage.ts`):

- Parses JSON bodies: `{ "error": "..." }`, ASP.NET **ProblemDetails** (`detail`, then `title`), and flat **`errors`** maps (validation).
- Non-JSON bodies shorter than ~280 characters are shown as plain text; longer bodies fall back to a generic message.

**Backend**: many endpoints return `new { error = "..." }` or ProblemDetails; both are covered.

## Testing

| Suite | Command | Notes |
|--------|---------|--------|
| BE | `dotnet test` in `be_demo` | Integration tests use `Testing` environment / in-memory DB where configured. |
| FE | `yarn test` in `fe_demo` | Vitest; includes `apiErrorMessage` unit tests. |
| Admin | `yarn test` in `admin_demo` | Same pattern as FE. |

Wall ticket API behaviour is documented in [wall-tickets.md](./wall-tickets.md), including automated coverage in `FaceWallTicketsControllerTests.cs`.

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
