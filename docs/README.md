# Documentation index (`docs/`)

All long-form documentation for the **`_mfai_demo` monorepo** lives under **`docs/`** (formerly split between `docs/` and root `doc/`; those files are merged here).

## English — development & features

| Document | Contents |
|----------|----------|
| [**DEVELOPMENT.md**](./DEVELOPMENT.md) | Monorepo layout, Node/Python versions, Husky/commitlint, CI matrix, **root scripts** (`ci-local.sh`, `lint-all.sh`, `build-all.sh`, `test-all.sh`), API error handling in the browser, testing quick reference, **auth / JWT / remember-me** (summary + links), face **grid** & demo seeding (summary). |
| [**authentication-and-sessions.md**](./authentication-and-sessions.md) | **EN:** OAuth2 password grant, `rememberMe`, JWT config keys, FE/admin storage & expiry checks, tests, security notes. |
| [**ACL / roles design (repo root)**](../ACL_ROLES_DESIGN.md) | Full checklist + as-built inventory (Parts A–F); implementers / agents. |
| [**acl-and-capabilities.md**](./acl-and-capabilities.md) | **Operational detail:** permission keys, `GET …/api/me/capabilities`, PageTypes / `my-role` gates, FE+admin file map, integration users, **test index**. |
| [**wall-tickets.md**](./wall-tickets.md) | Wall tickets API, moderation, Redis worker, manual checks. |
| [**CHAT_ROOMS_TESTING_AND_OPERATIONS.md**](./CHAT_ROOMS_TESTING_AND_OPERATIONS.md) | Face chat rooms: testing and operations. |

## Slovak — popisy a návody

| Document | Contents |
|----------|----------|
| [**fe-popis-sk.md**](./fe-popis-sk.md) | Prehľad `fe_demo` (architektúra, routing, wall, stories, …). |
| [**admin-popis-sk.md**](./admin-popis-sk.md) | Prehľad `admin_demo`. |
| [**redis-subrepo-dev-sk.md**](./redis-subrepo-dev-sk.md) | Submodule `redis_demo`, pripojenie z BE kontajnera, vývoj. |
| [**autentifikacia-a-relacie-sk.md**](./autentifikacia-a-relacie-sk.md) | **SK:** rovnaká téma ako *authentication-and-sessions* — JWT, `rememberMe`, konfigurácia, FE/admin, testy, bezpečnosť (podrobne). |
| [**super-admin-api-design.md**](./super-admin-api-design.md) | **SK:** analýza SUPER_ADMIN vs ADMIN, návrh super-only API (MVP), audit, test plán, **copy-paste prompt pre AI** na implementáciu. |

## API & curl

| Document | Contents |
|----------|----------|
| [**api-oauth-stories-curl.md**](./api-oauth-stories-curl.md) | OAuth2 register/token, face role, Stories API — krok za krokom cez **curl**. |

## Related (repository root)

| Path | Contents |
|------|----------|
| [`../README.md`](../README.md) | Monorepo entry, submodules, quick start. |
| [`../be_demo/README.md`](../be_demo/README.md) | Backend API overview. |
| [`../be_demo/STORIES_API.md`](../be_demo/STORIES_API.md) | Stories API reference (odkazuje sem na curl walkthrough). |
| [`../GIT_SUBMODULES_SETUP.md`](../GIT_SUBMODULES_SETUP.md) | Git submoduly. |

When adding new markdown guides, **place them under `docs/`** and link them from this index and from [DEVELOPMENT.md](./DEVELOPMENT.md) where appropriate.
