# Monorepo dependency audit and upgrade (agent prompt)

**Purpose:** Single inventory of **all declared dependencies** per app/subrepo in `_mfai_demo`, with **observed “latest stable”** from registries or tooling at a fixed snapshot, plus **feasibility / risk** notes for upgrades. Use this as a **copy-paste agent brief** to refresh numbers, open a branch, bump packages, and run tests/CI.

**Snapshot (human investigation):** 2026-04-11. Re-run the commands in section 0 before executing upgrades — registry “latest” changes daily.

---

## 0. Reproduce the audit (commands)

Run from monorepo root unless noted.

```bash
# .NET — outdated top-level packages (NuGet.org)
cd be_demo && dotnet list package --outdated

# Node — declared bumps suggested by npm-check-updates (does not modify files)
cd ../fe_demo && npx --yes npm-check-updates
cd ../admin_demo && npx --yes npm-check-updates

# Node — optional: exact latest on registry for one package
npm view <name> version

# Python — latest on PyPI (experimental API; may change)
python3 -m pip index versions grpcio | head -2
python3 -m pip index versions torch | head -2
python3 -m pip index versions transformers | head -2
python3 -m pip index versions ruff | head -2
python3 -m pip index versions pytest | head -2
python3 -m pip index versions protobuf | head -2

# Yarn CLI version (both SPAs)
grep packageManager fe_demo/package.json admin_demo/package.json
```

**Docker images** (not in registries above): compare `image:` tags in `db_demo/docker-compose.yml`, `redis_demo/docker-compose.yml`, `docker-compose.dev.yml`, `logger_demo/docker-compose.dev.yml` with [Docker Hub](https://hub.docker.com/) / upstream release notes.

---

## 1. `be_demo` — NuGet (`BeDemo.Api`, `BeDemo.Api.Tests`)

**Target framework:** `net10.0`  
**Base SDK image (Dockerfile.dev):** `mcr.microsoft.com/dotnet/sdk:10.0` (floating; consider pinning digest for reproducibility).

### 1.1 `BeDemo.Api/BeDemo.Api.csproj`

| Package | Requested / resolved | Latest (NuGet, 2026-04-11 `dotnet list package --outdated`) | Update feasible? |
| ------- | -------------------- | ----------------------------------------------------------- | ----------------- |
| Microsoft.AspNetCore.Authentication.JwtBearer | 10.0.2 | **10.0.5** | Yes — patch aligned with ASP.NET runtime; run full test suite. |
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | 10.0.2 | **10.0.5** | Yes — same. |
| Microsoft.AspNetCore.OpenApi | 10.0.0 | **10.0.5** | Yes — align all ASP.NET packages to same patch. |
| Microsoft.EntityFrameworkCore | 10.0.2 | **10.0.5** | Yes — with Npgsql provider bump. |
| Microsoft.EntityFrameworkCore.InMemory | 10.0.2 | **10.0.5** | Yes. |
| Microsoft.EntityFrameworkCore.Tools | 10.0.2 | **10.0.5** | Yes (PrivateAssets). |
| Npgsql.EntityFrameworkCore.PostgreSQL | 10.0.0 | **10.0.1** | Yes — minor provider patch. |
| Swashbuckle.AspNetCore | 10.1.0 | **10.1.7** | Yes — patch. |
| System.IdentityModel.Tokens.Jwt | 8.15.0 | **8.17.0** | Yes — JWT lib patch; verify OAuth/JWKS tests. |
| Google.Protobuf | 3.29.3 | **3.34.1** | **Careful** — minor/major line jump; must match **Grpc.Tools** / **Grpc.Net.Client** and generated proto code. |
| Grpc.Net.Client | 2.63.0 | **2.76.0** | Yes — bump with Grpc.Tools + regenerate if needed. |
| Grpc.Tools | 2.63.0 | **2.80.0** | Yes — keep in sync with Grpc.Net.Client. |
| Serilog.AspNetCore | 8.0.3 | **10.0.0** | **Major** — read Serilog 10 migration / breaking changes; test Seq + console sinks. |
| Serilog.Sinks.Console | 6.0.0 | **6.1.1** | Yes — patch. |
| Serilog.Sinks.Seq | 8.0.0 | **9.0.0** | **Major** — check Seq sink compatibility with Serilog.AspNetCore choice. |
| StackExchange.Redis | 2.9.32 | **2.12.14** | Yes — minor line; run job-queue / Redis integration paths. |
| Serilog.Enrichers.Environment | 3.0.1 | *(not listed outdated)* | Likely current — re-run `dotnet list package --outdated` after other bumps. |
| Serilog.Enrichers.Thread | 4.0.0 | *(not listed outdated)* | Likely current. |

### 1.2 `BeDemo.Api.Tests/BeDemo.Api.Tests.csproj`

| Package | Requested | Latest (same command) | Update feasible? |
| ------- | --------- | ---------------------- | ----------------- |
| coverlet.collector | 6.0.4 | **8.0.1** | **Major** — verify test host / coverage in CI. |
| FluentAssertions | 8.8.0 | **8.9.0** | Yes — patch. |
| Microsoft.AspNetCore.Mvc.Testing | 10.0.2 | **10.0.5** | Yes — align with Api. |
| Microsoft.AspNetCore.SignalR.Client | 10.0.2 | **10.0.5** | Yes. |
| Microsoft.EntityFrameworkCore.InMemory | 10.0.2 | **10.0.5** | Yes. |
| Npgsql.EntityFrameworkCore.PostgreSQL | 10.0.0 | **10.0.1** | Yes. |
| Microsoft.NET.Test.Sdk | 17.14.1 | **18.4.0** | **Major** — usually safe; confirm test SDK with `dotnet test`. |
| Moq | 4.20.72 | *(not listed outdated)* | Treat as current at snapshot. |
| xunit | 2.9.3 | *(not listed outdated)* | Treat as current. |
| xunit.runner.visualstudio | 3.1.4 | **3.1.5** | Yes — patch. |

### 1.3 `BeDemo.Api/Dockerfile.dev`

| Dependency | Current | Notes |
| ---------- | ------- | ----- |
| `dotnet-ef` global tool | **10.0.2** (pinned in Dockerfile) | Align with EF Core package version after upgrades. |

---

## 2. `fe_demo` — Yarn 4 / npm (`package.json`)

**`packageManager`:** `yarn@4.12.0`  
**Engines:** Node `>=22.14.0`

### 2.1 Tooling: `npm-check-updates` (2026-04-11)

The following **would** bump if you ran `npx npm-check-updates -u` (review breaking changes before applying):

| Package | Declared (approx.) | NCU suggested target |
| ------- | ------------------ | --------------------- |
| @commitlint/cli | ^20.3.1 | **^20.5.0** |
| @commitlint/config-conventional | ^20.3.1 | **^20.5.0** |
| @eslint/js | ^9.39.1 | **^10.0.1** |
| @microsoft/signalr | ^8.0.7 | **^10.0.0** (align with admin + be SignalR) |
| @tanstack/react-query | ^5.90.18 | **^5.97.0** |
| @testing-library/react | ^16.3.1 | **^16.3.2** |
| @types/jsdom | ^27 | **^28** |
| @types/node | ^25.0.9 | **^25.6.0** |
| @types/react | ^19.2.5 | **^19.2.14** |
| @vitejs/plugin-basic-ssl | ^2.1.0 | **^2.3.0** |
| @vitejs/plugin-react | ^5.1.1 | **^6.0.1** |
| @vitest/ui | ^4.0.17 | **^4.1.4** |
| cypress | ^15.9.0 | **^15.13.1** |
| eslint | ^9.39.1 | **^10.2.0** |
| eslint-plugin-react-refresh | ^0.4.24 | **^0.5.2** |
| globals | ^16.5.0 | **^17.4.0** |
| i18next | ^25.7.4 | **^26.0.4** |
| i18next-browser-languagedetector | ^8.2.0 | **^8.2.1** |
| jsdom | ^27.4.0 | **^29.0.2** |
| lint-staged | ^15.2.10 | **^16.4.0** |
| lucide-react | ^0.575.0 | **^1.8.0** |
| prettier | ^3.8.0 | **^3.8.2** |
| react / react-dom | ^19.2.0 | **^19.2.5** |
| react-grid-layout | ^2.2.2 | **^2.2.3** |
| react-hook-form | ^7.71.1 | **^7.72.1** |
| react-i18next | ^16.5.3 | **^17.0.2** |
| react-router-dom | ^7.12.0 | **^7.14.0** |
| sass | ^1.97.2 | **^1.99.0** |
| typescript | ~5.9.3 | **~6.0.2** |
| typescript-eslint | ^8.46.4 | **^8.58.1** |
| vite | ^7.3.2 | **^8.0.8** |
| vitest | ^4.0.17 | **^4.1.4** |

### 2.2 Full `dependencies` (declared ranges) — NCU did **not** list these at snapshot

**Interpretation:** Under current semver ranges, NCU did not propose a newer **major/minor** bump line, or they already resolve to latest compatible. Still run `yarn up` / `npm view <pkg> version` before a big release.

| Package | Declared in `package.json` |
| ------- | -------------------------- |
| @hookform/resolvers | ^5.2.2 |
| @radix-ui/react-accordion … @radix-ui/react-tooltip | ^1.x / ^2.x per line (full set in repo) |
| @tanstack/react-query | ^5.90.18 |
| axios | ^1.15.0 |
| bootstrap | ^5.3.8 |
| i18next | ^25.7.4 |
| i18next-browser-languagedetector | ^8.2.0 |
| quill-delta | ^5.1.0 |
| react / react-dom | ^19.2.0 |
| react-bootstrap | ^2.10.10 |
| react-grid-layout | ^2.2.2 |
| react-hook-form | ^7.71.1 |
| react-i18next | ^16.5.3 |
| react-quill-new | ^3.8.3 |
| react-router-dom | ^7.12.0 |
| react-toastify | ^11.0.5 |
| sass | ^1.97.2 |
| yup | ^1.7.1 |

**Registry check (sample, `npm view`, 2026-04-11):** `axios` **1.15.0**, `bootstrap` **5.3.8**, `@hookform/resolvers` **5.2.2**, `@radix-ui/react-dialog` **1.1.15**, `react-quill-new` **3.8.3** — match or satisfy current `^` ranges.

### 2.3 Full `devDependencies` not listed in NCU output

| Package | Declared |
| ------- | -------- |
| @popperjs/core | ^2.11.8 |
| @testing-library/dom | ^10.4.1 |
| @testing-library/jest-dom | ^6.9.1 |
| @testing-library/user-event | ^14.6.1 |
| @types/react-dom | ^19.2.3 |
| @yarnpkg/pnpify | ^4.1.6 |
| eslint-config-prettier | ^10.1.8 |
| eslint-plugin-react-hooks | ^7.0.1 |
| husky | ^9.1.7 |
| openapi-typescript-codegen | ^0.30.0 |

**High-risk upgrade themes (fe_demo):** ESLint **10**, Vite **8**, TypeScript **6**, i18next **26**, `lucide-react` **1.x** (large jump from 0.x), `@vitejs/plugin-react` **6** — schedule together with full `yarn validate` + Cypress smoke.

---

## 3. `admin_demo` — Yarn 4 / npm (`package.json`)

**`packageManager`:** `yarn@4.12.0`  
**Engines:** Node `>=22.14.0`

### 3.1 `npm-check-updates` (2026-04-11)

| Package | NCU suggested target |
| ------- | --------------------- |
| @commitlint/cli / config-conventional | **^20.5.0** |
| @eslint/js | **^10.0.1** |
| @tanstack/react-query | **^5.97.0** |
| @testing-library/react | **^16.3.2** |
| @types/jsdom | **^28** |
| @types/node | **^25.6.0** |
| @types/react | **^19.2.14** |
| @vitejs/plugin-basic-ssl | **^2.3.0** |
| @vitejs/plugin-react | **^6.0.1** |
| @vitest/ui | **^4.1.4** |
| eslint | **^10.2.0** |
| eslint-plugin-react-refresh | **^0.5.2** |
| framer-motion | **^12.38.0** |
| globals | **^17.4.0** |
| i18next | **^26.0.4** |
| i18next-browser-languagedetector | **^8.2.1** |
| jsdom | **^29.0.2** |
| lint-staged | **^16.4.0** |
| prettier | **^3.8.2** |
| react / react-dom | **^19.2.5** |
| react-grid-layout | **^2.2.3** |
| react-hook-form | **^7.72.1** |
| react-i18next | **^17.0.2** |
| react-router-dom | **^7.14.0** |
| sass | **^1.99.0** |
| typescript | **~6.0.2** |
| typescript-eslint | **^8.58.1** |
| vite | **^8.0.8** |
| vitest | **^4.1.4** |

### 3.2 Dependencies only in admin (not in fe NCU list)

| Package | Declared |
| ------- | -------- |
| @microsoft/signalr | **^10.0.0** (already aligned with modern stack) |
| @tanstack/react-table | ^8.21.3 |
| framer-motion | ^12.26.2 |

Remaining Radix / axios / bootstrap / react-bootstrap / yup / toastify — same family as `fe_demo`; verify with `npm view` when bumping.

---

## 4. `ai_demo` — Python (`requirements.txt`)

| Package | Pinned / constrained in repo | Latest on PyPI (first line of `pip index versions`, 2026-04-11) | Notes |
| ------- | ------------------------------ | ---------------------------------------------------------------- | ----- |
| grpcio | ==1.60.1 | **1.80.0** | Large jump — regenerate stubs, run gRPC tests, watch protobuf compatibility. |
| grpcio-tools | ==1.60.1 | Align with grpcio | Same. |
| protobuf | ==4.25.1 | **7.34.1** | **Do not** jump blindly — must match grpcio/grpc generated code; often **grpcio** release notes specify supported `protobuf` range. |
| transformers | >=4.36.0 | **5.5.3** | Major — evaluate model API + disk; pin upper bound if staying on 4.x. |
| torch | >=2.0.0 | **2.11.0** | Major — CUDA/CPU wheels, image size, `Dockerfile.dev` base image. |
| accelerate | >=0.25.0 | **1.13.0** | Bump with transformers/torch as a set. |
| ruff | >=0.8.0 | **0.15.10** | Dev lint — safe to bump frequently. |
| pytest | ==8.3.4 | **9.0.3** | Major — check plugins / `grpcio-testing` compatibility. |
| grpcio-testing | ==1.60.1 | Match grpcio | Bump in lockstep with grpcio. |

**Process:** Prefer a **locked** `requirements.lock` or `uv.lock` for reproducible AI images after upgrades.

---

## 5. Infra subrepos — Docker image pins

### 5.1 `db_demo/docker-compose.yml`

| Image | Current tag | Latest stable context (2026-04-11) | Notes |
| ----- | ----------- | ------------------------------------ | ----- |
| postgres | **16-alpine** | PostgreSQL **16.13** (and **17.9**, **18.3** exist) | Moving **16 → 17/18** is a **major** DB upgrade — follow PostgreSQL upgrade docs + backup. Minor **16.x** updates: refresh `16-alpine` digest regularly. |
| dpage/pgadmin4 | **latest** | Unpinned — prefer **specific tag** (e.g. `9.x`) for reproducibility. |

### 5.2 `redis_demo/docker-compose.yml`

| Image | Current tag | Latest stable context | Notes |
| ----- | ----------- | --------------------- | ----- |
| redis | **7-alpine** | Official `redis:latest` / **8.6.2** (Redis **8**) per Docker Hub | **Redis 8+** uses **RSALv2 / SSPL / AGPL** tri-license — **legal review** before upgrading from 7.x (BSD-licensed 7.2 line). See Docker Hub overview text. |

### 5.3 Root `docker-compose.dev.yml`

| Image | Current tag | Notes |
| ----- | ----------- | ----- |
| nginx (fe-demo-proxy) | **nginx:1.27-alpine** | Compare with current stable **1.28.x** / `alpine` on Docker Hub; patch bumps low risk. |
| datalust/seq | **latest** | Pin to explicit Seq version for reproducible dev/ops. |
| `fe_demo` / `admin_demo` / `ai_demo` / `be_demo` | **Dockerfile.dev** builds | Base images `node:22-slim`, `python:3.11-slim`, `mcr.microsoft.com/dotnet/sdk:10.0` — refresh periodically. |

### 5.4 `logger_demo/docker-compose.dev.yml`

| Image | Current tag | Notes |
| ----- | ----------- | ----- |
| amir20/dozzle | **latest** | Pin version tag for reproducibility. |

---

## 6. Cross-cutting recommendations (for the agent)

1. **.NET:** Bump **all Microsoft.AspNetCore.\*** / **EFCore** / **Npgsql** to the **same patch** (e.g. 10.0.5) in one PR; then run `dotnet test` + integration tests.  
2. **Serilog:** Treat **Serilog.AspNetCore 10** + **Seq sink 9** as one migration task (read release notes).  
3. **gRPC / Protobuf:** Upgrade **Google.Protobuf + Grpc.Net.Client + Grpc.Tools** together; regenerate proto if tooling requires.  
4. **FE/admin:** Prefer **two-phase** upgrades: (A) patch/minor without ESLint 10 / Vite 8 / TS 6; (B) toolchain majors with dedicated QA.  
5. **Align SignalR client:** `fe_demo` still on `@microsoft/signalr` **^8** while `admin_demo` on **^10** — plan unification.  
6. **Python AI:** Pin compatible **grpcio / protobuf / grpcio-tools** triple from upstream docs; avoid mixing unpinned `torch`/`transformers` in production images.  
7. **Docker:** Replace **`latest`** tags for Seq, pgAdmin, Dozzle with explicit versions in a dedicated infra PR.

---

## 7. Deliverables when an agent completes a pass

- [ ] Updated tables (or this file replaced) with **new snapshot date** and command outputs (or links to CI logs).  
- [ ] PR(s) per ecosystem (.NET / fe / admin / ai / docker) with green tests.  
- [ ] Short **CHANGELOG** or release note listing major bumps and any intentional skips (with reason).
