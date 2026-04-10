# MFAI Demo — monorepo

Monorepo s **Dockerom**, **ASP.NET Core** API, **React (Vite)** FE/admin, **PostgreSQL**, **Redis**, **Python gRPC** AI službou a nástrojmi na logy. Každá aplikácia je vlastný **git submodule**.

## Dokumentácia (štart tu)

**[`docs/README.md`](./docs/README.md)** — hub: `guides/`, `components/`, `prompts/`, `readmes/`.  
Štruktúra priečinkov: [`docs/STRUCTURE.md`](./docs/STRUCTURE.md).  
Vývoj, CI, skripty: [`docs/guides/development.md`](./docs/guides/development.md).

### Rýchle odkazy

| Téma | Dokument |
|------|-----------|
| Auth / JWT / `rememberMe` (EN) | [`docs/guides/authentication-and-sessions.md`](./docs/guides/authentication-and-sessions.md) |
| Auth (SK) | [`docs/readmes/authentication-and-sessions-sk.md`](./docs/readmes/authentication-and-sessions-sk.md) |
| ACL / capabilities API | [`docs/guides/acl-and-capabilities.md`](./docs/guides/acl-and-capabilities.md) |
| OAuth2 + Stories (curl) | [`docs/guides/api-oauth-stories-curl.md`](./docs/guides/api-oauth-stories-curl.md) |
| Git submoduly | [`docs/guides/git-submodules.md`](./docs/guides/git-submodules.md) |
| Lokálne HTTPS (`dev/`) | [`docs/guides/dev-https.md`](./docs/guides/dev-https.md) |
| TLS / krypto backlog | [`docs/guides/security-crypto-sockets.md`](./docs/guides/security-crypto-sockets.md) |
| Index README submodule | [`docs/readmes/README.md`](./docs/readmes/README.md) |

Backend detail: [`be_demo/README.md`](./be_demo/README.md). Ostatné služby — stĺpec v [`docs/readmes/README.md`](./docs/readmes/README.md).

## Štruktúra (skrátene)

```
be_demo/       # API (OAuth2, JWT, SignalR, EF Core)
fe_demo/       # Používateľská SPA
admin_demo/    # Admin SPA
db_demo/       # PostgreSQL compose
redis_demo/    # Redis (fronta)
ai_demo/       # gRPC health / AI
logger_demo/   # Dozzle
*.sh           # start-all-dev, ci-local, test-all, …
```

## Quick start

**Požiadavky:** Docker, Docker Compose, Bash.

```bash
git submodule update --init --recursive
./start-all-dev.sh
```

**Časté porty:** API HTTP `8000`, HTTPS `8001`, FE `8081`, admin `8082`, Seq `5341`, DB `54320`. Presná mapa je v [`docs/guides/dev-https.md`](./docs/guides/dev-https.md) a v submodule README.

**Testy (všetko):**

```bash
export SKIP_CYPRESS=1   # voliteľné; bez toho FE môže spúšťať e2e
./ci-local.sh           # lint → build → test (ako job monorepo_scripts v CI)
```

## Ďalšie súbory v koreni (archív / referencie)

Niektoré návody boli presunuté do **`docs/guides/`** (git submoduly, husky, boilerplate checklist, návrhy). Vyhľadaj názov súboru v `docs/guides/` alebo použite hub vyššie.

## Licencia / Contributing

Doplň podľa projektu.
