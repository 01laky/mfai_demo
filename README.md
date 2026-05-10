# Many Faces AI (MFAI) - monorepo

MFAI Demo is a full-stack social platform demo built around the concept of **faces**: configurable community spaces with their own pages, roles, content, chats, stories, profiles, listings, albums, blogs, reels, and AI-assisted features.

The project shows how a modern social product can be assembled from reusable building blocks: dynamic page grids, role-aware user flows, media-rich content, real-time communication, profile directories, public and private spaces, admin-managed structure, and backend-enforced data separation between faces.

The monorepo includes the customer-facing frontend, the admin portal, the backend API, AI services, PostgreSQL and Redis infrastructure, Docker-based local orchestration, development scripts, documentation, and reusable AI-agent prompts that help continue implementation work consistently.

It is designed both as a runnable local demo and as an engineering playground for experimenting with configurable social experiences, face-specific content, access rules, media workflows, real-time features, and AI-powered interactions. Each app is its own **git submodule**.

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
