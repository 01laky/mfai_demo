# Documentation hub (`docs/`)

Central documentation for the **`_mfai_demo`** monorepo lives here. **Per-submodule README** files remain under `be_demo/`, `fe_demo/`, … — see [`readmes/README.md`](./readmes/README.md) for an index.

**Why these folders:** [STRUCTURE.md](./STRUCTURE.md) (short rationale for `guides/` vs `components/` vs `prompts/` vs `readmes/`).

### Diagram: how to use this hub

```mermaid
flowchart LR
  U[Reader]
  H[docs README hub]
  G[guides deep reference]
  C[components module index]
  P[prompts for AI tasks]
  R[readmes submodule stories]
  U --> H
  H --> G
  H --> C
  H --> P
  H --> R
```

---

## [`guides/`](./guides/) — reference guides

| Document                                                                              | Contents                                                                                                                                         |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| [development.md](./guides/development.md)                                             | CI, Node/Python, Husky/commitlint, `scripts/` orchestration (`scripts/ci-local.sh`, …), API errors in the browser, tests, face home grid, links. |
| [authentication-and-sessions.md](./guides/authentication-and-sessions.md)             | OAuth2, JWT, `rememberMe`, configuration, FE/admin, tests.                                                                                       |
| [demo-users-and-passwords.md](./guides/demo-users-and-passwords.md)                   | Local seed: super admin / admin / demo users and passwords (tables).                                                                               |
| [acl-and-capabilities.md](./guides/acl-and-capabilities.md)                           | Permission keys, `GET …/api/me/capabilities`, gates, file map, integration users, test index.                                                    |
| [api-oauth-stories-curl.md](./guides/api-oauth-stories-curl.md)                       | OAuth2 + Stories via **curl**.                                                                                                                   |
| [wall-tickets.md](./guides/wall-tickets.md)                                           | Wall tickets API, moderation, Redis worker.                                                                                                      |
| [chat-rooms-testing-and-operations.md](./guides/chat-rooms-testing-and-operations.md) | Face chat rooms — tests and operations.                                                                                                          |
| [security-crypto-sockets.md](./guides/security-crypto-sockets.md)                     | TLS, JWT keys, WebSockets backlog.                                                                                                               |
| [dev-https.md](./guides/dev-https.md)                                                 | Local HTTPS certs (`dev/`), ports, Docker.                                                                                                       |
| [git-submodules.md](./guides/git-submodules.md)                                       | Submodule setup and workflow.                                                                                                                    |
| [husky-setup.md](./guides/husky-setup.md)                                             | Husky / hooks (historical note).                                                                                                                 |
| [boilerplate-checklist.md](./guides/boilerplate-checklist.md)                         | Template checklist.                                                                                                                              |
| [proposal-mfai-demo-state.md](./guides/proposal-mfai-demo-state.md)                   | Snapshot / proposal (archive).                                                                                                                   |

---

## [`components/`](./components/) — implemented building blocks

Short **what it is** and **where in the repo**; deep detail stays in `guides/`.

| Document                                                              | Contents                                            |
| --------------------------------------------------------------------- | --------------------------------------------------- |
| [acl-capabilities-module.md](./components/acl-capabilities-module.md) | ACL catalog, capabilities API, FE/admin `src/acl/`. |

_(Add more files as you ship coherent modules.)_

---

## [`prompts/`](./prompts/) — AI prompts

| Document                                                                                                   | Contents                                                                        |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [super-admin-api.md](./prompts/super-admin-api.md)                                                         | SUPER_ADMIN-only global role API — analysis + copy-paste implementation prompt. |
| [mermaid-documentation-diagrams-agent-prompt.md](./prompts/mermaid-documentation-diagrams-agent-prompt.md) | Agent prompt to insert all Mermaid diagrams across `docs/` (exhaustive specs).  |

---

## [`readmes/`](./readmes/) — README index + extended overviews

| Document                                                   | Contents                                      |
| ---------------------------------------------------------- | --------------------------------------------- |
| [README.md](./readmes/README.md)                           | Links to each submodule README + this folder. |
| [fe-demo-overview.md](./readmes/fe-demo-overview.md)       | `fe_demo` architecture and features.          |
| [admin-demo-overview.md](./readmes/admin-demo-overview.md) | `admin_demo` architecture and features.       |
| [redis-subrepo.md](./readmes/redis-subrepo.md)             | `redis_demo` submodule for the job queue.     |

---

## External / repo root

| Path                                                     | Contents                              |
| -------------------------------------------------------- | ------------------------------------- |
| [`../README.md`](../README.md)                           | Short monorepo entry and quick start. |
| [`../be_demo/STORIES_API.md`](../be_demo/STORIES_API.md) | Stories API reference.                |

**New docs:** prefer `guides/` (reference), `components/` (catalog), `prompts/` (AI), or `readmes/` (overviews / index). Update this hub and [`guides/development.md`](./guides/development.md) when you add paths.
