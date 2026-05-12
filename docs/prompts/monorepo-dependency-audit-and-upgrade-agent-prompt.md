# Monorepo dependency audit and upgrade (agent prompt)

**Purpose:** Single inventory of **all declared dependencies** per app/subrepo in `many_faces_main`, with **observed “latest stable”** from registries or tooling at a fixed snapshot, plus **feasibility / risk** notes for upgrades. Use this as a **copy-paste agent brief** to refresh numbers, open a branch, bump packages, and run tests/CI.

**Checklists:** Trailing `[ ]` sections are **PR / audit evidence templates**—tick them in the PR or issue, not by default in this canonical file (see [docs/prompts/README.md](./README.md)).

**Snapshot (human + tooling):** 2026-04-10 (`many_faces_portal` / `many_faces_admin` §2.3 union table + NCU re-run; `many_faces_backend` NuGet unchanged vs prior note — re-run §0 before upgrades — registry “latest” changes daily). Completion log: [docs/guides/monorepo-dependency-audit-completion.md](../guides/monorepo-dependency-audit-completion.md).

### Monorepo layout (`git` submodules)

`many_faces_portal`, `many_faces_admin`, `many_faces_backend`, `many_faces_ai`, `many_faces_database`, `many_faces_redis`, and `many_faces_logger` are **git submodules** (see root `.gitmodules`). **Commits that bump dependencies** usually belong in the **submodule’s remote**; the parent `many_faces_main` repo may only update the **submodule pointer** after those merges. Open or link PRs per submodule so CI runs where the manifest and lockfile live.

---

## 0. Reproduce the audit (commands)

Run from **monorepo root** (`many_faces_main`) unless noted. Paths below assume that CWD.

```bash
# .NET — outdated top-level packages (NuGet.org)
cd many_faces_backend && dotnet list package --outdated
# Optional: include prerelease lines when evaluating betas (not default for “stable” audit)
# dotnet list package --outdated --include-prerelease

# Node — declared bumps suggested by npm-check-updates (does not modify files)
cd ../many_faces_portal && npx --yes npm-check-updates
cd ../many_faces_admin && npx --yes npm-check-updates
cd ../many_faces_backend && npx --yes npm-check-updates

# Node — optional: exact latest on registry for one package
npm view <name> version

# Python — latest on PyPI (experimental API; may change)
for p in grpcio grpcio-tools protobuf transformers torch accelerate ruff pytest grpcio-testing; do
  echo "=== $p ===" && python3 -m pip index versions "$p" 2>&1 | head -3
done

# Yarn CLI version (both SPAs)
grep packageManager many_faces_portal/package.json many_faces_admin/package.json
```

**Security / transitive (add-on to version audit):** this prompt focuses on **direct** dependencies in manifests. Transitives live in `yarn.lock` / NuGet lock. After bumps, run e.g.:

```bash
cd many_faces_portal && yarn npm audit
cd ../many_faces_admin && yarn npm audit
cd ../many_faces_backend && dotnet list package --vulnerable 2>/dev/null || true
```

Interpret audit output with judgment (dev-only vs runtime, accepted risk, upstream fixes).

**Docker images** (not in registries above): compare `image:` tags in `many_faces_database/docker-compose.yml`, `many_faces_redis/docker-compose.yml`, `docker-compose.dev.yml`, `many_faces_logger/docker-compose.dev.yml` with [Docker Hub](https://hub.docker.com/) / upstream release notes. For **base images** (`node:22-slim`, `python:3.11-slim`, `mcr.microsoft.com/dotnet/sdk:10.0`), compare digests/tags on Docker Hub / MCR.

**Concrete Docker checks (optional):**

```bash
# Resolved compose images (tags after extends/env; good sanity check)
docker compose -f docker-compose.dev.yml config 2>/dev/null | grep -E 'image:|build:' || true
# Inspect local digest after pull (repeat for each service you care about)
# docker pull nginx:1.27-alpine && docker image inspect nginx:1.27-alpine --format '{{.RepoDigests}}'
```

### 0.1 Regenerate the **full npm** inventory table (section 2.3)

**Must run from monorepo root** — the script uses `pathlib.Path("many_faces_portal/package.json")` relative to CWD.

Runs `npm view <pkg> version` for the **union** of `dependencies` and `devDependencies` in `many_faces_portal/package.json` and `many_faces_admin/package.json`, then prints a Markdown table. **Paste the output into this document** under **§2.3** (replace the existing pipe table body; keep the heading and legend).

```bash
python3 <<'PY'
import json, pathlib, subprocess

def load(path):
    d = json.loads(pathlib.Path(path).read_text())
    decl = {**d.get("dependencies", {}), **d.get("devDependencies", {})}
    return decl

root = pathlib.Path(".")
fe_d = load(root / "many_faces_portal/package.json")
ad_d = load(root / "many_faces_admin/package.json")
all_names = sorted(set(fe_d) | set(ad_d))

def ver(pkg):
    try:
        return subprocess.check_output(
            ["npm", "view", pkg, "version"], text=True, timeout=90
        ).strip()
    except Exception as e:
        return f"(error: {e})"

print("| Package | `many_faces_portal` | `many_faces_admin` | Latest (npm) | Note |")
print("| ------- | --------- | ------------ | ------------ | ---- |")
for name in all_names:
    fv = fe_d.get(name, "—")
    av = ad_d.get(name, "—")
    lv = ver(name)
    note = ""
    if fv != "—" and av != "—" and fv != av:
        note = "Declared ranges differ between SPAs"
    elif name == "@microsoft/signalr" and fv != av:
        note = "Align fe to ^10 with admin + BE SignalR"
    elif name == "@microsoft/signalr" and fv == av and fv != "—":
        note = "Both SPAs aligned with BE SignalR"
    print(f"| `{name}` | {fv} | {av} | **{lv}** | {note} |")
PY
```

**Performance:** the script invokes `npm view` once per package (~90 calls). For faster refresh, batch or parallelize with a small concurrency limit if your environment allows.

---

## 1. `many_faces_backend` — NuGet (`BeDemo.Api`, `BeDemo.Api.Tests`)

**Target framework:** `net10.0`  
**Base SDK image (Dockerfile.dev):** `mcr.microsoft.com/dotnet/sdk:10.0` (floating; consider pinning digest for reproducibility).

### 1.1 `BeDemo.Api/BeDemo.Api.csproj`

**Repo baseline (2026-04-10):** ASP.NET / EF / Npgsql / Swashbuckle / JWT / Serilog / Redis are on the **bumped** lines below; `dotnet list package --outdated` then only flags the **gRPC triplet** (intentional hold until arm64/Docker `protoc` validated).

| Package                                           | Current (repo) | Latest (NuGet, `dotnet list package --outdated`) | Notes                                                                                                                                                                                                                                                                                                |
| ------------------------------------------------- | -------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Microsoft.AspNetCore.Authentication.JwtBearer     | **10.0.5**     | —                                                | At resolved line.                                                                                                                                                                                                                                                                                    |
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | **10.0.5**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Microsoft.AspNetCore.OpenApi                      | **10.0.5**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Microsoft.EntityFrameworkCore                     | **10.0.5**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Microsoft.EntityFrameworkCore.InMemory            | **10.0.5**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Microsoft.EntityFrameworkCore.Tools               | **10.0.5**     | —                                                | PrivateAssets.                                                                                                                                                                                                                                                                                       |
| Npgsql.EntityFrameworkCore.PostgreSQL             | **10.0.1**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Swashbuckle.AspNetCore                            | **10.1.7**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| System.IdentityModel.Tokens.Jwt                   | **8.17.0**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Serilog.AspNetCore                                | **10.0.0**     | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Serilog.Sinks.Console                             | **6.1.1**      | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Serilog.Sinks.Seq                                 | **9.0.0**      | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| StackExchange.Redis                               | **2.12.14**    | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Serilog.Enrichers.Environment                     | **3.0.1**      | —                                                | No newer in default audit at refresh.                                                                                                                                                                                                                                                                |
| Serilog.Enrichers.Thread                          | **4.0.0**      | —                                                | Same.                                                                                                                                                                                                                                                                                                |
| Google.Protobuf                                   | **3.29.3**     | **3.34.1**                                       | **Hold on Docker arm64** — `Grpc.Tools` **2.80** ships `protoc` that **exits 139** (segfault) under **`linux_arm64`** in `mcr.microsoft.com/dotnet/sdk:10.0` when building inside **be-demo-dev**; keep **3.29.3 / 2.63.0** until upstream fix or proto codegen **outside** the arm64 SDK container. |
| Grpc.Net.Client                                   | **2.63.0**     | **2.76.0**                                       | Bump **with** `Grpc.Tools` + `Google.Protobuf` in one change after the tooling issue is resolved.                                                                                                                                                                                                    |
| Grpc.Tools                                        | **2.63.0**     | **2.80.0**                                       | Same.                                                                                                                                                                                                                                                                                                |

### 1.2 `BeDemo.Api.Tests/BeDemo.Api.Tests.csproj`

**Repo baseline (2026-04-11):** `dotnet list package --outdated` reports **no** updates for this project at refresh.

| Package                                | Current (repo) | Latest (same command) | Notes                             |
| -------------------------------------- | -------------- | --------------------- | --------------------------------- |
| coverlet.collector                     | **8.0.1**      | —                     | Bumped; verify coverage in CI.    |
| FluentAssertions                       | **8.9.0**      | —                     |                                   |
| Microsoft.AspNetCore.Mvc.Testing       | **10.0.5**     | —                     | Aligned with Api.                 |
| Microsoft.AspNetCore.SignalR.Client    | **10.0.5**     | —                     |                                   |
| Microsoft.EntityFrameworkCore.InMemory | **10.0.5**     | —                     |                                   |
| Npgsql.EntityFrameworkCore.PostgreSQL  | **10.0.1**     | —                     |                                   |
| Microsoft.NET.Test.Sdk                 | **18.4.0**     | —                     |                                   |
| Moq                                    | **4.20.72**    | —                     | No newer stable in default audit. |
| xunit                                  | **2.9.3**      | —                     |                                   |
| xunit.runner.visualstudio              | **3.1.5**      | —                     |                                   |

### 1.3 `BeDemo.Api/Dockerfile.dev`

| Dependency              | Current                           | Notes                                                                 |
| ----------------------- | --------------------------------- | --------------------------------------------------------------------- |
| `dotnet-ef` global tool | **10.0.5** (pinned in Dockerfile) | Keep aligned with `Microsoft.EntityFrameworkCore.*` package versions. |

### 1.4 `many_faces_backend/package.json` (Node — Husky / Commitlint only)

**`packageManager`:** `yarn@4.12.0` (pinned hash in repo).

| Package                         | Declared    | `npm-check-updates` (re-run §0) | Latest `npm view` | Notes              |
| ------------------------------- | ----------- | ------------------------------- | ----------------- | ------------------ |
| @commitlint/cli                 | **^20.5.0** | _(at line)_                     | **20.5.0**        | Aligned with SPAs. |
| @commitlint/config-conventional | **^20.5.0** | _(at line)_                     | **20.5.0**        | Same.              |
| husky                           | **^9.1.7**  | _(at line)_                     | **9.1.7**         |                    |

---

## 2. `many_faces_portal` and `many_faces_admin` — Yarn 4 / npm (`package.json`)

**`packageManager`:** `yarn@4.12.0` (both SPAs).  
**Engines:** Node `>=22.14.0` (both).

**How to read this section:** **§2.3** is the **authoritative per-package** list (declared ranges vs `npm view` “latest”). **§2.1–2.2** are **short NCU deltas** for a quick “what would widen first” — optional if you only refresh §2.3. After editing `package.json`, run `yarn install` and commit **`yarn.lock`** in the same submodule PR.

**Yarn-native bumps (optional):** instead of only NCU, you can use `yarn up <package>` / `yarn up -R <package>` (Yarn 4) for interactive or recursive upgrades; still verify with `yarn validate` / tests.

### 2.1 `npm-check-updates` — `many_faces_portal` (snapshot **2026-04-10**)

`npx npm-check-updates` (no `-u`): **All dependencies match the latest package versions** — NCU proposes no manifest edits. Use **§2.3** for per-package `npm view` vs declared ranges.

### 2.2 `npm-check-updates` — `many_faces_admin` (snapshot **2026-04-10**)

Same as `many_faces_portal`: **no bumps proposed** by NCU at this snapshot.

**Admin-only runtime packages:** `@tanstack/react-table` **^8.21.3** (NCU / `npm view` — no newer line at snapshot). `@microsoft/signalr` **^10.0.0** on both SPAs (aligned with BE SignalR).

### 2.3 Complete npm registry snapshot — union of both `package.json` files

**Legend:** **Latest (npm)** = `npm view <pkg> version` at snapshot (the default **dist-tag**, usually `latest`).

- **`^x.y.z`** (caret): allows compatible **minor** and **patch** updates within the same **major** (npm semver for `^1.2.3` → `<2.0.0`). A resolved install can sit below **Latest (npm)** until you widen the range or run a bump tool.
- **`~x.y.z`** (tilde): allows **patch-only** bumps on the same **minor** (e.g. `~5.9.3` → `<5.10.0`). Stricter than `^` — **Latest** may be a newer **minor** you will not get until you change the range (e.g. TypeScript `~5.9.3` vs npm latest `6.x`).

`—` = not declared in that app. This table does **not** list transitive packages from `yarn.lock`.

| Package                           | `many_faces_portal`                     | `many_faces_admin`                  | Latest (npm) | Note |
| -------------------------------- | ---------------------------- | ---------------------------- | ------------ | ---------------------------------------------------------------------------------------------------- |
| `@commitlint/cli`                  | ^20.5.0                        | ^20.5.0                        | **20.5.0** |  |
| `@commitlint/config-conventional`  | ^20.5.0                        | ^20.5.0                        | **20.5.0** |  |
| `@eslint/js`                       | ^10.0.1                        | ^10.0.1                        | **10.0.1** | Matches ESLint 10 in both SPAs |
| `@hookform/resolvers`              | ^5.2.2                         | ^5.2.2                         | **5.2.2** |  |
| `@microsoft/signalr`               | ^10.0.0                        | ^10.0.0                        | **10.0.0** | Both SPAs aligned with BE SignalR |
| `@popperjs/core`                   | ^2.11.8                        | ^2.11.8                        | **2.11.8** |  |
| `@radix-ui/react-accordion`        | ^1.2.12                        | ^1.2.12                        | **1.2.12** |  |
| `@radix-ui/react-alert-dialog`     | ^1.1.15                        | ^1.1.15                        | **1.1.15** |  |
| `@radix-ui/react-aspect-ratio`     | ^1.1.8                         | ^1.1.8                         | **1.1.8** |  |
| `@radix-ui/react-avatar`           | ^1.1.11                        | ^1.1.11                        | **1.1.11** |  |
| `@radix-ui/react-checkbox`         | ^1.3.3                         | ^1.3.3                         | **1.3.3** |  |
| `@radix-ui/react-collapsible`      | ^1.1.12                        | ^1.1.12                        | **1.1.12** |  |
| `@radix-ui/react-context-menu`     | ^2.2.16                        | ^2.2.16                        | **2.2.16** |  |
| `@radix-ui/react-dialog`           | ^1.1.15                        | ^1.1.15                        | **1.1.15** |  |
| `@radix-ui/react-dropdown-menu`    | ^2.1.16                        | ^2.1.16                        | **2.1.16** |  |
| `@radix-ui/react-hover-card`       | ^1.1.15                        | ^1.1.15                        | **1.1.15** |  |
| `@radix-ui/react-label`            | ^2.1.8                         | ^2.1.8                         | **2.1.8** |  |
| `@radix-ui/react-menubar`          | ^1.1.16                        | ^1.1.16                        | **1.1.16** |  |
| `@radix-ui/react-navigation-menu`  | ^1.2.14                        | ^1.2.14                        | **1.2.14** |  |
| `@radix-ui/react-popover`          | ^1.1.15                        | ^1.1.15                        | **1.1.15** |  |
| `@radix-ui/react-progress`         | ^1.1.8                         | ^1.1.8                         | **1.1.8** |  |
| `@radix-ui/react-radio-group`      | ^1.3.8                         | ^1.3.8                         | **1.3.8** |  |
| `@radix-ui/react-scroll-area`      | ^1.2.10                        | ^1.2.10                        | **1.2.10** |  |
| `@radix-ui/react-select`           | ^2.2.6                         | ^2.2.6                         | **2.2.6** |  |
| `@radix-ui/react-separator`        | ^1.1.8                         | ^1.1.8                         | **1.1.8** |  |
| `@radix-ui/react-slider`           | ^1.3.6                         | ^1.3.6                         | **1.3.6** |  |
| `@radix-ui/react-slot`             | ^1.2.4                         | ^1.2.4                         | **1.2.4** |  |
| `@radix-ui/react-switch`           | ^1.2.6                         | ^1.2.6                         | **1.2.6** |  |
| `@radix-ui/react-tabs`             | ^1.1.13                        | ^1.1.13                        | **1.1.13** |  |
| `@radix-ui/react-toast`            | ^1.2.15                        | ^1.2.15                        | **1.2.15** |  |
| `@radix-ui/react-toggle`           | ^1.1.10                        | ^1.1.10                        | **1.1.10** |  |
| `@radix-ui/react-toggle-group`     | ^1.1.11                        | ^1.1.11                        | **1.1.11** |  |
| `@radix-ui/react-tooltip`          | ^1.2.8                         | ^1.2.8                         | **1.2.8** |  |
| `@tanstack/react-query`            | ^5.97.0                        | ^5.97.0                        | **5.97.0** |  |
| `@tanstack/react-table`            | —                              | ^8.21.3                        | **8.21.3** |  |
| `@testing-library/dom`             | ^10.4.1                        | ^10.4.1                        | **10.4.1** |  |
| `@testing-library/jest-dom`        | ^6.9.1                         | ^6.9.1                         | **6.9.1** |  |
| `@testing-library/react`           | ^16.3.2                        | ^16.3.2                        | **16.3.2** |  |
| `@testing-library/user-event`      | ^14.6.1                        | ^14.6.1                        | **14.6.1** |  |
| `@types/jsdom`                     | ^28                            | ^28                            | **28.0.1** |  |
| `@types/node`                      | ^25.6.0                        | ^25.6.0                        | **25.6.0** |  |
| `@types/react`                     | ^19.2.14                       | ^19.2.14                       | **19.2.14** |  |
| `@types/react-dom`                 | ^19.2.3                        | ^19.2.3                        | **19.2.3** |  |
| `@vitejs/plugin-basic-ssl`         | ^2.3.0                         | ^2.3.0                         | **2.3.0** |  |
| `@vitejs/plugin-react`             | ^6.0.1                         | ^6.0.1                         | **6.0.1** |  |
| `@vitest/ui`                       | ^4.1.4                         | ^4.1.4                         | **4.1.4** |  |
| `@yarnpkg/pnpify`                  | ^4.1.6                         | ^4.1.6                         | **4.1.6** |  |
| `axios`                            | ^1.15.0                        | ^1.15.0                        | **1.15.0** |  |
| `bootstrap`                        | ^5.3.8                         | ^5.3.8                         | **5.3.8** |  |
| `cypress`                          | ^15.13.1                       | —                              | **15.13.1** | fe only |
| `eslint`                           | ^10.2.0                        | ^10.2.0                        | **10.2.0** |  |
| `eslint-config-prettier`           | ^10.1.8                        | ^10.1.8                        | **10.1.8** |  |
| `eslint-plugin-react-hooks`        | 7.1.0-canary-705268dc-20260409 | 7.1.0-canary-705268dc-20260409 | **7.0.1** | **Exact canary** (A2) until `@latest` peers include ESLint 10; see each SPA `docs/eslint-plugin-react-hooks-peer.md` |
| `eslint-plugin-react-refresh`      | ^0.5.2                         | ^0.5.2                         | **0.5.2** |  |
| `framer-motion`                    | —                              | ^12.38.0                       | **12.38.0** | admin only |
| `globals`                          | ^17.4.0                        | ^17.4.0                        | **17.4.0** |  |
| `husky`                            | ^9.1.7                         | ^9.1.7                         | **9.1.7** |  |
| `i18next`                          | ^26.0.4                        | ^26.0.4                        | **26.0.4** |  |
| `i18next-browser-languagedetector` | ^8.2.1                         | ^8.2.1                         | **8.2.1** |  |
| `jsdom`                            | ^29.0.2                        | ^29.0.2                        | **29.0.2** |  |
| `lint-staged`                      | ^16.4.0                        | ^16.4.0                        | **16.4.0** |  |
| `lucide-react`                     | ^1.8.0                         | —                              | **1.8.0** | fe only |
| `openapi-typescript-codegen`       | ^0.30.0                        | ^0.30.0                        | **0.30.0** |  |
| `prettier`                         | ^3.8.2                         | ^3.8.2                         | **3.8.2** |  |
| `quill-delta`                      | ^5.1.0                         | —                              | **5.1.0** | fe only |
| `react`                            | ^19.2.5                        | ^19.2.5                        | **19.2.5** |  |
| `react-bootstrap`                  | ^2.10.10                       | ^2.10.10                       | **2.10.10** |  |
| `react-dom`                        | ^19.2.5                        | ^19.2.5                        | **19.2.5** |  |
| `react-grid-layout`                | ^2.2.3                         | ^2.2.3                         | **2.2.3** |  |
| `react-hook-form`                  | ^7.72.1                        | ^7.72.1                        | **7.72.1** |  |
| `react-i18next`                    | ^17.0.2                        | ^17.0.2                        | **17.0.2** |  |
| `react-quill-new`                  | ^3.8.3                         | —                              | **3.8.3** | fe only |
| `react-router-dom`                 | ^7.14.0                        | ^7.14.0                        | **7.14.0** |  |
| `react-toastify`                   | ^11.0.5                        | ^11.0.5                        | **11.0.5** |  |
| `sass`                             | ^1.99.0                        | ^1.99.0                        | **1.99.0** |  |
| `typescript`                       | ~6.0.2                         | ~6.0.2                         | **6.0.2** |  |
| `typescript-eslint`                | ^8.58.1                        | ^8.58.1                        | **8.58.1** |  |
| `vite`                             | ^8.0.8                         | ^8.0.8                         | **8.0.8** |  |
| `vitest`                           | ^4.1.4                         | ^4.1.4                         | **4.1.4** |  |
| `yup`                              | ^1.7.1                         | ^1.7.1                         | **1.7.1** |  |

### 2.4 High-risk upgrade themes (FE / admin)

At snapshot **2026-04-10**, the big SPA toolchain moves (ESLint **10**, Vite **8**, TypeScript **6**, i18next **26**, `lucide-react` **1.x**, `@vitejs/plugin-react` **6**) are already on declared ranges that match **Latest (npm)** in **§2.3**. Treat **`eslint-plugin-react-hooks`** (exact **canary** for ESLint 10 peers; see each SPA `docs/eslint-plugin-react-hooks-peer.md`), **Cypress** (fe only), and split app deps (`react-quill-new`, `framer-motion`, …) as the usual **high-attention** bump targets. After any change: `yarn validate`, unit tests, and Cypress smoke where CI runs them.

---

## 3. `many_faces_ai` — Python (`requirements.txt`)

| Package        | Pinned / constrained in repo | Latest on PyPI (`pip index versions`, first line, snapshot) | Notes                                                                                                                               |
| -------------- | ---------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| grpcio         | ==1.60.1                     | **1.80.0**                                                  | Large jump — regenerate stubs, run gRPC tests, watch protobuf compatibility.                                                        |
| grpcio-tools   | ==1.60.1                     | **1.80.0**                                                  | Align with grpcio.                                                                                                                  |
| protobuf       | ==4.25.1                     | **7.34.1**                                                  | **Do not** jump blindly — must match grpcio/grpc generated code; often **grpcio** release notes specify supported `protobuf` range. |
| transformers   | >=4.36.0                     | **5.5.3**                                                   | Major — evaluate model API + disk; pin upper bound if staying on 4.x.                                                               |
| torch          | >=2.0.0                      | **2.11.0**                                                  | Major — CUDA/CPU wheels, image size, `Dockerfile.dev` base image.                                                                   |
| accelerate     | >=0.25.0                     | **1.13.0**                                                  | Bump with transformers/torch as a set.                                                                                              |
| ruff           | >=0.8.0                      | **0.15.10**                                                 | Dev lint — safe to bump frequently.                                                                                                 |
| pytest         | ==8.3.4                      | **9.0.3**                                                   | Major — check plugins / `grpcio-testing` compatibility.                                                                             |
| grpcio-testing | ==1.60.1                     | **1.80.0**                                                  | Bump in lockstep with grpcio.                                                                                                       |

**Process:** Prefer a **locked** `requirements.lock` or `uv.lock` for reproducible AI images after upgrades.

**Alternatives to experimental `pip index versions`:** use **`uv lock`** / **`uv pip compile`** or **`pip-tools`** (`pip-compile`) to resolve the same constraints to concrete versions and diff against the lock output. That is often **more stable** in CI than relying on `pip index` long-term.

---

## 4. Infra subrepos — Docker image pins

When upgrading tags: (1) check **release notes** on Docker Hub / vendor docs; (2) prefer **immutable references** (`image: repo:tag@sha256:…`) in a follow-up if your team policy allows; (3) re-run compose healthchecks locally. Submodule PRs for `many_faces_database`, `many_faces_redis`, `many_faces_logger` apply the same submodule commit rules as app repos.

### 4.1 `many_faces_database/docker-compose.yml`

| Image          | Current tag   | Latest stable context (snapshot)                                     | Notes                                                                                                                                                    |
| -------------- | ------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| postgres       | **16-alpine** | PostgreSQL **16.x** (and **17.x**, **18.x** lines exist on Hub)      | Moving **16 → 17/18** is a **major** DB upgrade — follow PostgreSQL upgrade docs + backup. Minor **16.x** updates: refresh `16-alpine` digest regularly. |
| dpage/pgadmin4 | **latest**    | Unpinned — prefer **specific tag** (e.g. `9.x`) for reproducibility. |

### 4.2 `many_faces_redis/docker-compose.yml`

| Image | Current tag  | Latest stable context               | Notes                                                                                                                                                      |
| ----- | ------------ | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| redis | **7-alpine** | Official **8.x** line on Docker Hub | **Redis 8+** uses **RSALv2 / SSPL / AGPL** tri-license — **legal review** before upgrading from 7.x (BSD-licensed 7.2 line). See Docker Hub overview text. |

### 4.3 Root `docker-compose.dev.yml`

| Image / build                        | Current                               | Notes                                                                                  |
| ------------------------------------ | ------------------------------------- | -------------------------------------------------------------------------------------- |
| nginx (fe-demo-proxy)                | **nginx:1.27-alpine**                 | Compare with current stable **1.28.x** / `alpine` on Docker Hub; patch bumps low risk. |
| datalust/seq                         | **latest**                            | Pin to explicit Seq version for reproducible dev/ops.                                  |
| `many_faces_portal` / `many_faces_admin` Dockerfiles | **node:22-slim** + `yarn@4.12.0`      | Refresh when Node 22 LTS security updates ship.                                        |
| `many_faces_ai` Dockerfile                 | **python:3.11-slim**                  | Consider 3.12+ only with explicit test pass for torch/transformers wheels.             |
| `many_faces_backend` Dockerfile                 | **mcr.microsoft.com/dotnet/sdk:10.0** | Pin digest for reproducibility in CI.                                                  |

### 4.4 `many_faces_logger/docker-compose.dev.yml`

| Image         | Current tag | Notes                                |
| ------------- | ----------- | ------------------------------------ |
| amir20/dozzle | **latest**  | Pin version tag for reproducibility. |

---

## 5. Cross-cutting recommendations (for the agent)

1. **.NET:** Bump **all Microsoft.AspNetCore.\*** / **EFCore** / **Npgsql** to the **same patch** (e.g. 10.0.5) in one PR; then run `dotnet test` + integration tests.
2. **Serilog:** Treat **Serilog.AspNetCore 10** + **Seq sink 9** as one migration task (read release notes).
3. **gRPC / Protobuf:** Upgrade **Google.Protobuf + Grpc.Net.Client + Grpc.Tools** together; regenerate proto if tooling requires. On **Docker arm64** (`linux_arm64`), **`Grpc.Tools` 2.80** has been observed to crash **`protoc` (exit 139)** inside **`mcr.microsoft.com/dotnet/sdk:10.0`** — validate in **be-demo-dev** before merging; see §1.1.
4. **FE/admin:** Use section **2.3** as the authoritative per-package row set; section **2.1–2.2** highlights what NCU would widen.
5. **Align SignalR client:** `many_faces_portal` **^8** vs `many_faces_admin` **^10** — plan unification with backend SignalR version.
6. **Align @types/node:** `many_faces_admin` **^24.10.9** vs `many_faces_portal` **^25.0.9** — pick one major line for both SPAs.
7. **Python AI:** Pin compatible **grpcio / protobuf / grpcio-tools** triple from upstream docs; avoid mixing unpinned `torch`/`transformers` in production images.
8. **Docker:** Replace **`latest`** tags for Seq, pgAdmin, Dozzle with explicit versions in a dedicated infra PR.
9. **many_faces_backend Node:** Bump **@commitlint/\*** to **20.x** in line with `many_faces_portal` / `many_faces_admin`.
10. **Submodules:** merge dependency PRs in **submodule** repos first; then update **parent** `many_faces_main` submodule pointers if required by your release process.
11. **Security:** run **§0** audit commands plus `yarn npm audit` / `dotnet list package --vulnerable` where available; triage before and after bumps.
12. **Lockfiles:** any `package.json` / `requirements.txt` change should include updated **`yarn.lock`** or a **pinned lock** for Python where the team adopted one.

---

## 6. Deliverables when an agent completes a pass

- [ ] Updated tables (or this file replaced) with **new snapshot date** and command outputs (or links to CI logs).
- [ ] PR(s) per ecosystem (.NET / fe / admin / ai / docker) with green tests.
- [ ] Short **CHANGELOG** or release note listing major bumps and any intentional skips (with reason).
- [ ] Submodule repos and parent pointer (if applicable) aligned; lockfiles committed.

---

## 7. Detailed upgrade checklist (what to touch)

Use this as a **tick list** for a full dependency pass. Skip groups intentionally (document why in the PR). Order is suggested, not mandatory.

### 7.1 Pre-flight

- [ ] `git submodule update --init --recursive` (clean tree for audit).
- [ ] Re-run **§0** commands; refresh **§2.3** table via **§0.1** script if npm rows changed.
- [ ] Decide **PR strategy** (one mega-PR vs .NET / fe / admin / ai / infra split).

### 7.2 `many_faces_backend` — .NET (`BeDemo.Api`, `BeDemo.Api.Tests`)

- [ ] **ASP.NET + EF Core + Npgsql** — align `Microsoft.AspNetCore.*`, `Microsoft.EntityFrameworkCore.*`, `Npgsql.EntityFrameworkCore.PostgreSQL` to the **same patch** (see §1.1 / §1.2).
- [ ] **OpenAPI** — `Microsoft.AspNetCore.OpenApi`.
- [ ] **Swashbuckle** — `Swashbuckle.AspNetCore`.
- [ ] **JWT** — `System.IdentityModel.Tokens.Jwt`.
- [ ] **gRPC stack** — `Google.Protobuf`, `Grpc.Net.Client`, `Grpc.Tools` **together**; regenerate proto if tooling requires.
- [ ] **Serilog** — `Serilog.AspNetCore`, `Serilog.Sinks.Console`, `Serilog.Sinks.Seq` (major coordination).
- [ ] **Redis** — `StackExchange.Redis`.
- [ ] **Enrichers** — `Serilog.Enrichers.Environment`, `Serilog.Enrichers.Thread` (re-check after other bumps).
- [ ] **Tests** — `coverlet.collector`, `FluentAssertions`, `Microsoft.AspNetCore.Mvc.Testing`, `Microsoft.AspNetCore.SignalR.Client`, `Microsoft.EntityFrameworkCore.InMemory`, `Microsoft.NET.Test.Sdk`, `Moq`, `xunit`, `xunit.runner.visualstudio`.
- [ ] Run `dotnet test` (and integration tests) in **many_faces_backend** submodule.

### 7.3 `many_faces_backend` — Docker + Node tooling

- [ ] **`BeDemo.Api/Dockerfile.dev`** — `dotnet-ef` tool version vs EF Core packages.
- [ ] **`many_faces_backend/package.json`** — `@commitlint/cli`, `@commitlint/config-conventional`, `husky`; run `yarn install` if lockfile exists in submodule.
- [ ] Optional: **MCR** `mcr.microsoft.com/dotnet/sdk:10.0` digest pin.

### 7.4 `many_faces_portal` — `package.json` + lockfile

- [ ] **Commitlint / Husky** — `@commitlint/*`, `husky`, `lint-staged`.
- [ ] **Toolchain (high-risk bundle)** — `typescript`, `typescript-eslint`, `eslint`, `@eslint/js`, `eslint-config-prettier`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`, `globals`, `vite`, `@vitejs/plugin-react`, `@vitejs/plugin-basic-ssl`, `vitest`, `@vitest/ui`, `jsdom`, `@types/jsdom`, `cypress`.
- [ ] **React app** — `react`, `react-dom`, `react-router-dom`, `react-hook-form`, `@hookform/resolvers`, `yup`, `axios`, `react-bootstrap`, `bootstrap`, `@popperjs/core`, `sass`, `react-toastify`, `react-grid-layout`, `react-quill-new`, `quill-delta`, `lucide-react`, `i18next`, `i18next-browser-languagedetector`, `react-i18next`, `@tanstack/react-query`, `@microsoft/signalr` (**align to v10** with admin + BE).
- [ ] **Radix UI** — all `@radix-ui/react-*` entries (accordion through tooltip).
- [ ] **API client gen** — `openapi-typescript-codegen`.
- [ ] **Testing libs** — `@testing-library/*`, `@types/react`, `@types/react-dom`, `@types/node`.
- [ ] **Yarn** — `@yarnpkg/pnpify`.
- [ ] **`yarn.lock`** — committed after any `package.json` change.
- [ ] Run `yarn validate`, `yarn test`, and **Cypress** smoke where applicable.

### 7.5 `many_faces_admin` — `package.json` + lockfile

- [ ] Same **toolchain** group as `many_faces_portal` where shared (§7.4).
- [ ] **Admin-only / diffs** — `@tanstack/react-table`, `framer-motion`; **`@types/node`** — align major line with `many_faces_portal`.
- [ ] **`@microsoft/signalr`** — already on ^10; keep in sync with BE after fe bump.
- [ ] **Radix + React stack** — mirror `many_faces_portal` where packages overlap.
- [ ] **`yarn.lock`** — committed.
- [ ] Run `yarn validate` and `yarn test`.

### 7.6 `many_faces_portal` / `many_faces_admin` — Docker

- [ ] **`Dockerfile.dev`** — `node:22-slim`, `corepack prepare yarn@4.12.0` vs root `packageManager` field.

### 7.7 `many_faces_ai` — Python

- [ ] **gRPC** — `grpcio`, `grpcio-tools`, `grpcio-testing` in **one** bump.
- [ ] **.NET gRPC in Docker (arm64)** — after bumping `Grpc.Tools`, run **`docker compose … up -d --build be-demo-dev`** and confirm **`dotnet watch` / `protoc`** does not exit **139** on **`linux_arm64`**.
- [ ] **protobuf** — only in a combination supported by grpc release notes / regenerated stubs.
- [ ] **ML stack** — `torch`, `transformers`, `accelerate` (evaluate majors together).
- [ ] **Dev** — `ruff`, `pytest`.
- [ ] Regenerate **proto** Python if proto or grpcio-tools changed; run Python tests.
- [ ] **`Dockerfile.dev`** — `python:3.11-slim` (or agreed bump); rebuild image.

### 7.8 Infra compose (submodule repos)

- [ ] **`many_faces_database/docker-compose.yml`** — `postgres:16-alpine`, `dpage/pgadmin4` (replace `latest` with pin when ready).
- [ ] **`many_faces_redis/docker-compose.yml`** — `redis:7-alpine` (legal review before **8.x**).
- [ ] **Root `docker-compose.dev.yml`** — `nginx`, `datalust/seq`, service build contexts.
- [ ] **`many_faces_logger/docker-compose.dev.yml`** — `amir20/dozzle` (pin tag).
- [ ] Smoke **compose up** paths affected by image changes.

### 7.9 Security and docs

- [ ] `yarn npm audit` in **many_faces_portal** and **many_faces_admin**; address or record accepted risks.
- [ ] `dotnet list package --vulnerable` in **many_faces_backend** if supported.
- [ ] Update **this prompt** (§1–§4 tables) or attach CI logs + new snapshot date.
- [ ] **Parent `many_faces_main`:** bump submodule SHAs + short release note / CHANGELOG as per §6.

### 7.10 Explicit “do not forget” cross-cuts

- [ ] **SignalR** — `many_faces_portal` client major aligned with `many_faces_admin` and **BeDemo.Api** SignalR.
- [ ] **Serilog majors** — Seq + console + AspNetCore tested together.
- [ ] **Redis 8+** — legal sign-off before image upgrade.
- [ ] **PostgreSQL 17/18** — major DB migration plan, not a silent tag bump.
