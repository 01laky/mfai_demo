# Enterprise security hardening + full-stack edge-case tests — AI agent prompt

**Language:** English (identifiers and code paths follow the repository).  
**Use:** Copy **section 17** (master instructions) or the **whole document** into a new AI agent session.

**Strict compliance:** In this prompt, **nothing is optional**. Every checklist item in **§14–§16** and **§18** must be **completed and explicitly ticked** in the agent’s final report. If work is blocked by an external system, the agent must still **document the blocker**, **update docs** to reflect reality, and **add failing/skipped tests with justification** only where the test host cannot support the scenario — never silence a requirement without a written trace in the deliverable.

**Related docs (read in full before coding):**

- [../guides/security-crypto-sockets.md](../guides/security-crypto-sockets.md) — backlog items K/J/O/T/S/H/D/M.
- [../guides/acl-and-capabilities.md](../guides/acl-and-capabilities.md) — authorization, capabilities, SignalR notes.
- [../guides/authentication-and-sessions.md](../guides/authentication-and-sessions.md) — sessions and client behavior (verify path exists; if moved, locate and read the replacement).
- [super-admin-api.md](./super-admin-api.md) — **required** whenever global role or `SUPER_ADMIN`-only HTTP surface is added or changed.
- [mermaid-documentation-diagrams-agent-prompt.md](./mermaid-documentation-diagrams-agent-prompt.md) — **required** for Mermaid style, diagram types, and repo conventions.

**Important:** Treat the “current baseline” table inside `security-crypto-sockets.md` as **untrusted until verified** against `be_demo/BeDemo.Api/Program.cs`, `OAuth2Service`, `JwtBearerOptions`, and tests. **You must reconcile** that table with code during **§15**.

---

## 1. Objectives

1. **Analyze** cryptography, transport, authentication, authorization, and operational security across the **entire** `_mfai_demo` monorepo — including surfaces listed in **§2** (API, SignalR, SPAs, **ai_demo**, **db**/connection strings, **logger**, **uploads**, **jobs/Redis** if present, Docker, CI, OpenAPI).
2. **Implement** all security improvements required by this document and **§17.2** for the current codebase state. **Deferral is not allowed** except: stop-the-world external dependency (e.g. corporate HSM not available in dev) — in that case you must **commit a written gap entry**, **open a tracked follow-up identifier** (issue ID or TODO with owner in docs), and still **test everything that can run locally**.
3. **Add and maintain** comprehensive edge-case tests on **BE** (integration/unit), **fe_demo** (Vitest), **admin_demo** (Vitest), and **E2E** where the repo already defines them (**§7, §18**).
4. **Document all touched logic in English** in source: XML/TSDoc and **non-trivial branches inside bodies** (**§14**).
5. **Close with a full documentation audit** (**§15**): fix stale prose, document every new behavior in detail, **canonical Mermaid** per topic (**§15.2**), **validated diagram syntax** (**§15.2** last bullet).

---

## 2. Scope map (mandatory coverage)

| Layer                       | Paths (typical)                                                                                                                                                                                                                  | Focus                                                                                 |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **API host**                | `be_demo/BeDemo.Api/Program.cs`, middlewares, `Services/OAuth2Service.cs`, `Services/ECDSAKeyService.cs`, `Middlewares/OAuth2Middleware.cs`, `Middlewares/RoutingMiddleware.cs`, `Middlewares/FaceScopeEnforcementMiddleware.cs` | JWT, OAuth2, face scope, CORS, headers, Swagger exposure                              |
| **Controllers / hubs**      | `be_demo/BeDemo.Api/Controllers/**/*.cs`, `Hubs/**/*.cs`                                                                                                                                                                         | Authz, `IAccessEvaluator`, `IFaceScopeContext`; **every hub file** listed in **§8.1** |
| **ACL / capabilities**      | `Utils/PlatformAccessRules.cs`, `Services/AccessEvaluator.cs`, `Services/AccessCapabilitiesService.cs`, `Controllers/MeController.cs`, `Security/AclPermissionKeys.cs`                                                           | Platform vs tenant, `SUPER_ADMIN` vs `ADMIN`, parity with FE/admin `acl/`             |
| **FE**                      | `fe_demo/src` — auth, API clients, `acl/**`, SignalR                                                                                                                                                                             | Tokens, refresh, 401, face-prefixed base URL                                          |
| **Admin SPA**               | `admin_demo/src`                                                                                                                                                                                                                 | Same as FE + admin face prefix                                                        |
| **ai_demo**                 | gRPC server/client config, TLS/trust to AI from BE                                                                                                                                                                               | Channel security, timeouts, error handling; document threat model                     |
| **db_demo / database**      | Connection strings, compose, migrations docs                                                                                                                                                                                     | **No secrets in git**; document env vars and rotation                                 |
| **Redis / background jobs** | If present: queue, workers                                                                                                                                                                                                       | Auth to Redis, sensitive payloads, rate-limit storage — document and test             |
| **logger_demo / logging**   | Serilog, Seq, log helpers                                                                                                                                                                                                        | **No passwords/tokens/full JWT** in logs; document redaction rules                    |
| **Uploads / static**        | `wwwroot/uploads`, exempt routes in `Routing`                                                                                                                                                                                    | Size limits, content types, path traversal, abuse — document + tests where applicable |
| **Infra / dev**             | `docker-compose*.yml`, `dev/generate-https-certs.sh`, `.github/**` if present                                                                                                                                                    | TLS, HSTS, WSS; **dependency / secret scanning in CI** if pipeline exists             |
| **Submodules**              | `.gitmodules` → each linked repo README touched by security changes                                                                                                                                                              | Must appear in **§15.1** inventory when relevant                                      |
| **Tests**                   | `BeDemo.Api.Tests`, `fe_demo`/`admin_demo` `*.test.*`, **Cypress/e2e** if in `scripts/test-all.sh`                                                                                                                               | All **§17.3** and **§18**                                                             |

---

## 3. Cryptography and keys (JWT signing vs TLS)

- **JWT signing** = **digital signatures** (e.g. ECDSA **ES512** / P-521). Strength = algorithm, **private key storage**, **JWKS**, **rotation**, **`ValidAlgorithms`** on validation — not “EC encrypting the JWT.”
- **HTTPS / WSS** = **TLS** + server certificate. Strength = **TLS 1.3** (target), cipher policy, HSTS, no mixed content.

**Required:** English architecture note in **code** on signing vs TLS services, and in **docs** during **§15** with **≥1 Mermaid** (flowchart or sequence) for JWT signing path vs TLS termination.

---

## 4. Workstream A — Signing keys and JWKS (K1–K6)

**Required goals:**

- Production-capable **key loading** (vault / mounted PEM / KMS); dev may differ but **must be documented**.
- **JWKS** endpoint; **`kid`** alignment; **dual-key** verification window for rotation.
- **No** private keys in git or plaintext `appsettings.json`.

**Required tests:** wrong `kid`, retired key window, wrong `alg` → **401** with safe logs.

**Required docs:** **One canonical** Mermaid for key rotation / JWKS verify (**§15.2**); cross-link from other sections instead of duplicating.

---

## 5. Workstream B — JWT validation and session binding (J1–J7)

**Required goals:**

- `ValidateLifetime = true`; **clock skew** chosen, documented, and **consistent** in code + docs.
- Issuer, audience, signing key, **`ValidAlgorithms`** enforced.
- **`aud` policy:** either **implement** distinct audiences for distinct surfaces **or** document a **single-audience** decision with threat-model rationale in `docs/guides/` — silence is not allowed.
- Access TTL + refresh **rotation** + reuse detection — extend tests if gaps exist.
- **J6:** On password change, global role change, or equivalent sensitive events — **invalidate refresh** and/or **`token_version`** (or equivalent) **enforced on every API request** so stale access JWT cannot retain privilege.

**Required tests:** expired, future `nbf`, malformed, wrong sig; refresh reuse; concurrent refresh if applicable; **J6** behavior **proven** by tests or by a **documented test gap** with exact reason and tracking id.

**Required docs:** **Canonical** Mermaid for access/refresh + J6 in one place; link from security + auth guides.

---

## 6. Workstream C — OAuth2 hardening (O1–O6)

**Required goals:**

- Client secrets: **hashed** or secret-manager-backed; rotation documented.
- **Rate limits** on `token` and `register`: per IP, per `client_id`, and **per-username** where applicable; **429** + **`Retry-After`** when rate-limited.
- **Lockout** verified on **password grant** path.
- **O4:** Remove or replace broken **server-key body signature**; document final model (mTLS / `private_key_jwt` / TLS+secret only).
- **Register:** production tightening documented (invite, email verify, CAPTCHA, flags) — implement what the repo’s config model allows; otherwise **document exact gap** + tracking id.

**Required tests:** `invalid_client`, `invalid_grant`; rate limit burst → **429**; register abuse; **enumeration policy** — see **§6.1**.

### 6.1 OAuth error policy (required)

**Required:** A short **table in docs** (e.g. `security-crypto-sockets.md` or `authentication-and-sessions.md`) defining **which HTTP/status bodies** are returned for wrong password vs unknown user vs locked account vs rate limit — **consistent** across implementation and tests. Tests must assert this policy.

---

## 7. Workstream D — TLS, HSTS, WSS (T1–T4)

**Required goals:** HTTPS for prod; HSTS policy documented; WSS for SignalR in prod; `ws://` **localhost-only** documented.

**Required:** Documented smoke path or test hook using `dev/generate-https-certs.sh` or equivalent; **canonical** Mermaid dev vs prod path.

---

## 8. Workstream E — SignalR / WebSockets (S1–S6)

### 8.1 Hub inventory (required)

The agent must **enumerate every** `*.cs` under `be_demo/BeDemo.Api/Hubs/` (e.g. `ChatHub`, `MessengerHub`, `ChatRoomHub`, and any other present). For **each** hub file:

- Document JWT/face-scope rules.
- Add or extend **automated tests** **or** a **test matrix table in docs** with **manual verification steps** if automation is impossible — the matrix is **mandatory**, not optional.

**Required goals:** JWT parity with HTTP; face scope; no cross-tenant group leakage; hub method authz; AI/rate limits where applicable.

**Required tests:** no token; wrong face prefix; document mid-connection expiry behavior.

**Required docs:** **Canonical** Mermaid for negotiate URL + `access_token` + face prefix; link from ACL guide.

---

## 9. Workstream F — Security headers and CORS (H1–H4)

**Required:** Middleware (or equivalent) for **nosniff**, frame/CSP policy appropriate to JSON API, **Referrer-Policy** / **Permissions-Policy** as applicable; CORS **never** `AllowAnyOrigin` **with credentials**; production origins **config-driven**.

**Required tests:** assert critical headers on representative routes.

**Required docs:** **Canonical** Mermaid: pipeline position of CORS + security headers.

---

## 10. Workstream G — Authorization (ACL)

**Required:**

- Any **super-admin-only** HTTP surface **must** follow [super-admin-api.md](./super-admin-api.md) (authz rules, validations, audit).
- **Capabilities** aligned with `AclPermissionKeys` and FE/admin `acl/aclPermissionKeys.ts` — **parity tests required**.
- Refactor shared authz **only** when it **removes duplicate identical checks** without changing behavior; prefer **security fixes in-place** first.

**Required tests:** admin JWT on tenant URL → **403** for global mutations; tenant on admin where forbidden → **403**; anonymous vs authenticated matrix for public endpoints.

**Required docs:** **Canonical** Mermaid for platform vs tenant vs `SUPER_ADMIN` — **always** reconciled with code in **§15** (not only “if ACL changed”).

---

## 11. Workstream H — Monitoring, audit, dependencies, OpenAPI exposure

**Required goals:**

- Structured auth-failure logs — **no** passwords, refresh tokens, or full JWTs.
- **Audit templates** for key rotation, client secret change, global role change, sensitive hub ops — **documented**; implement logging hooks where the codebase has patterns.
- **Swagger / OpenAPI UI in production:** **must** be disabled, auth-gated, or restricted by environment — document exact behavior in `docs/` and **verify** in config.
- **Dependency audit:** run **`dotnet list package --vulnerable`** (or project-standard) and **`npm audit`** (or **yarn npm audit**) for `fe_demo` and `admin_demo`; **record results** in `docs/guides/security-crypto-sockets.md` (baseline / deferred) or the agent report (**§15**); **fix** or **document accepted risk + tracking id** for each high/critical finding.

**Required docs:** **Canonical** Mermaid for audit event flow (auth failure → log fields → optional audit store).

---

## 12. Workstream I — Uploads, IDOR posture, CSRF model, contracts, E2E

**Required:**

- **Uploads / static files:** document limits, validation, and abuse notes; add tests if the API exposes upload endpoints affected by this effort.
- **IDOR:** extend ACL/matrix tests for **representative** resource controllers (stories, albums, profiles, etc.) where IDs cross tenants — **document** coverage in `docs/guides/security-crypto-sockets.md` (deferred) or the agent report.
- **CSRF:** document **current** model (Bearer + SPA); if cookies are introduced later, CSRF strategy is **required** in that change — document “not applicable today” with **reference to Bearer model** in `docs/guides/`.
- **OpenAPI contract:** add or extend tests that **sample responses** match documented security-relevant endpoints (OAuth, capabilities) where feasible.
- **E2E:** If `scripts/test-all.sh` runs **Cypress** (or similar), **add or extend** at least **one** scenario: **login → authenticated request → refresh or logout** — or document **exact** blocker and add a **tracked** item plus **manual test script** in docs.

---

## 13. Frontend and admin_demo — UX and tests

**Required goals:**

- Capabilities drive **visible actions** for permission-gated UI.
- **401 / refresh:** no infinite loops on bad refresh.
- **`localStorage` tokens:** **XSS risk documented in English** in `docs/` (required); httpOnly cookie migration remains a **separate approved project** but **risk must be stated**.

**Required Vitest:** `parseMeCapabilities`, permission helpers, auth hooks, face prefix on API base, **wss** guard where testable.

**Required admin_demo:** capabilities + admin prefix + loading/error states.

**Required docs:** **Canonical** Mermaid SPA auth + capabilities warmup (FE **and** admin).

---

## 14. English code documentation (mandatory)

**Language:** **English only** for every **new** or **materially changed** comment in **be_demo**, **fe_demo**, **admin_demo**, and **security-related test code** (`BeDemo.Api.Tests` and Vitest files that assert auth/security).

### 14.1 Backend (C#)

- **Public and internal** security/OAuth/JWT/middleware/hub/ACL members: **XML doc** (`summary`, `param`, `returns`, `remarks`, `exception` as applicable).
- **`private` members** that implement **security-sensitive** logic (crypto, token validation, scope checks): **required** `///` or `//` explaining **invariants** and **why** — not a restatement of the `if`.
- **Bodies:** non-obvious branches **must** have short English comments (**why**).

### 14.2 Frontend (TS/TSX)

- TSDoc on **exports** in auth/ACL/API/SignalR modules; file-level doc where invariants matter.
- **Bodies:** non-trivial flow in English.

### 14.3 Exception (narrow)

- **Cosmetic-only** edits (typo, whitespace) **with zero behavior change** need not add new comments — state in PR if batching such edits.

### 14.4 Checklist (code comments)

- [ ] **BE:** XML on security-related public/internal APIs; **private** security helpers documented; **inline English** in non-obvious branches.
- [ ] **BE tests:** Each **new** security test class/method has **English** summary of scenario and expected outcome.
- [ ] **FE:** TSDoc + inline English per **§14.2**.
- [ ] **admin_demo:** Same as FE.
- [ ] **FE/admin tests:** Security scenarios documented in English.

---

## 15. Final documentation pass + Mermaid (mandatory closure)

**When** code and automated tests for this engagement are **green** (or explicitly documented with tracking ids per **§1**), the agent **must not** finish until **§15** and **§18** are satisfied.

### 15.1 Full audit (required)

1. Inventory **`docs/**`**, **`docs/guides/`**, **`docs/readmes/`**, **`docs/components/`**, **root `README.md`**, **`docs/README.md`**, **`be_demo/README.md`**, **`fe_demo/README.md`**, **`admin_demo/README.md`**, **`ai_demo/README.md`** (if present), paths from **`.gitmodules`**, and any **CI workflow** under `.github/workflows/` that touches build/test/security.
2. Compare each to **current code**; **fix all stale** content (paths, baseline tables, endpoints, env vars).
3. **Add detailed prose** for **every** new config key, endpoint, middleware, operational procedure, and threat note introduced.

### 15.2 Mermaid — canonical diagrams (required)

- Follow **[mermaid-documentation-diagrams-agent-prompt.md](./mermaid-documentation-diagrams-agent-prompt.md)** for style and diagram choice.
- **One canonical diagram per topic** (keys, JWT+refresh+J6, OAuth2, TLS/WSS, SignalR, headers/CORS, ACL, audit, SPA auth, ai_demo trust if applicable). **Other sections link** to the canonical section — **no redundant copies** of the same diagram.
- **Syntax validation (required):** Before completion, **render-check** every new/changed Mermaid block (e.g. `@mermaid-js/mermaid-cli` locally, VS Code preview, or GitHub/GitLab render). **Fix** invalid diagrams — “looks fine” without render check is **not** acceptable.

### 15.3 Checklist (documentation closure)

- [ ] Inventory from **§15.1** completed; submodule paths from **`.gitmodules`** checked where relevant.
- [ ] Every stale doc **fixed**; list of files touched **in final report**.
- [ ] Every new behavior **documented** (config, APIs, ops, threats).
- [ ] **Canonical Mermaid** set complete; **cross-links** added; **render validation** passed (**§15.2**).
- [ ] **`docs/README.md`** and **root `README.md`** links updated if paths changed.
- [ ] **`security-crypto-sockets.md` baseline table** reconciled with code or replaced with accurate table.

---

## 16. Master deliverables checklist (agent must tick every box)

**Implementation**

- [ ] **Gap analysis** delivered **in full** in the agent’s **final report** (mandatory). When this engagement produces repo changes, also update **`docs/guides/security-crypto-sockets.md`**: baseline table if behavior changed, and **Deferred follow-ups** for any remaining `TRACK-*` items (same substance as the report); empty gap analysis is **forbidden**.
- [ ] **All §17.2 requirements** addressed in code **or** documented with **tracking id** + **exact** reason per **§1**.
- [ ] **`scripts/test-all.sh`** (or documented project equivalent) **passes**, **or** failing commands are listed with **cause** and **tracking id**.
- [ ] **No secrets** in git; examples use **placeholders** and **env var names**.
- [ ] **OpenAPI/Swagger** schemes and **production Swagger policy** documented and implemented.
- [ ] **Operations runbook** (key rotation, emergency revocation, dependency audit cadence) in **`be_demo/README.md`** or **`docs/guides/`** — **required**, not conditional on user ask.

**English comments (**§14**)**

- [ ] All **§14.4** items ticked.

**Mermaid**

- [ ] Keys/JWKS/rotation — **canonical** diagram + link.
- [ ] JWT validation, refresh, J6 / `token_version` — **canonical** diagram + link.
- [ ] OAuth2 token + register + rate limits + **error policy** reference — **canonical** diagram + link.
- [ ] TLS / HTTPS / WSS / dev vs prod — **canonical** diagram + link.
- [ ] SignalR + face prefix + auth — **canonical** diagram + link.
- [ ] Security headers + CORS pipeline — **canonical** diagram + link.
- [ ] ACL / platform / tenant / `SUPER_ADMIN` — **canonical** diagram + link (**always** reconciled).
- [ ] Audit / auth-failure logging — **canonical** diagram + link.
- [ ] SPA auth + capabilities (FE **and** admin) — **canonical** diagram + link.
- [ ] **ai_demo** / gRPC trust path — diagram + prose **if** BE talks to AI in this repo.

**Tests (see §17.3 and §18)**

- [ ] All **§17.3** and **§18** items ticked.

**Documentation closure (**§15**)**

- [ ] All **§15.3** items ticked.

---

## 17. COPY-PASTE — Master instructions for the AI agent

You are working in **`_mfai_demo`**. **Every requirement in this file is mandatory.** Your final message **must** include a **checklist copy** with **every item from §16, §17 (all subsections that contain requirements), and §18** marked **done** or **blocked** with **tracking id** and **owner**.

### 17.1 Rules

1. **Verify against code**, not against old docs.
2. **Smallest change that satisfies security** — no unrelated refactors; **§14** comments on all touched code.
3. **JWT signing ≠ TLS** — document both (**§3**).
4. **Server enforcement** is authoritative; UI aligns with capabilities.

### 17.2 Technical requirements (all mandatory)

- **K1–K6, J1–J7, O1–O6, T1–T4, S1–S6, H1–H4, D1–D2, M1–M3** from `security-crypto-sockets.md` **implemented** or **documented gap + tracking id** per **§1**.
- **Super-admin / global role API:** if touched, **super-admin-api.md** is **normative**.
- **Swagger in production:** restricted per **§11**.
- **Dependencies:** audited per **§11**; results in `docs/guides/security-crypto-sockets.md` or agent report.
- **Uploads, ai_demo gRPC, E2E, contracts, CSRF doc, IDOR tests:** per **§12**.

### 17.3 Testing requirements (all mandatory)

**Backend**

- JWT edge cases; refresh reuse; rate limit **429**; **J6**; OAuth errors per **§6.1**; **exempt paths** (`/api/oauth2`, etc.) **still** work **without** erroneous face-prefix enforcement — **regression tests required**.
- **Every hub** in **§8.1**: automated test **or** **documented manual matrix** with steps.
- ACL matrix: tenant vs admin client; `ADMIN` vs `SUPER_ADMIN` where applicable.

**Frontend / admin**

- Vitest per **§13**; **§18** granularity.

**E2E / contract**

- Per **§12** — **required**; if impossible, **manual script in docs** + **tracking id**.

### 17.4 Code documentation

- **§14** on **every** changed file (exception **§14.3** only).

### 17.5 Documentation + Mermaid

- **§15** in full; **§15.2** render validation **required**.

### 17.6 Process

1. Inventory vs **§2** and **K/J/O/T/S/H/D/M**.
2. Implement in dependency order (keys → validate → refresh/J6 → OAuth → SignalR → TLS/docs scripts → headers → ACL → audit → SPAs → ai_demo/uploads/E2E).
3. **Run full test suite** after each logical chunk; fix failures.
4. Final report: tests list, files list, **§16 + §17 + §18** checklist **fully** addressed.
5. **Never** mark optional — use **blocked + tracking id** only when **§1** allows.

### 17.7 Hard boundaries (without explicit user approval, you must not)

- Replace Bearer + localStorage with **httpOnly cookies** (large product change).
- Run **external penetration tests** or touch **infrastructure outside this repo**.
- Change **unrelated business features**.

These boundaries **do not** relax **§16** — they **narrow scope of rewrite**, not **documentation or tests**.

---

## 18. Extended test checklist (mandatory ticks)

- [ ] **BE:** Exempt OAuth/auth paths **regression** (no spurious face requirement).
- [ ] **BE:** `invalid_client` / `invalid_grant` / rate limit — match **§6.1** table.
- [ ] **BE:** Concurrent refresh **or** documented impossibility + tracking id.
- [ ] **BE:** OpenAPI/sample contract checks for OAuth + capabilities **or** documented gap + tracking id.
- [ ] **FE:** `acl/permissions` + `parseMeCapabilities` exhaustive edge cases.
- [ ] **FE:** Auth refresh + 401 + no infinite loop.
- [ ] **FE:** Face prefix on **all** scoped API calls in tests.
- [ ] **admin_demo:** Admin prefix + capabilities + error states.
- [ ] **E2E:** Cypress (or repo E2E) auth path **or** manual script in docs + tracking id.
- [ ] **Dependencies:** `dotnet` + `npm`/`yarn` audit logged in `docs/guides/security-crypto-sockets.md` or agent report; highs addressed or tracked.

---

## 19. Changelog

- **v1** — Initial combined prompt.
- **v2** — English comments + docs audit + Mermaid expansion.
- **v3** — **Strict mode:** no optional items; full monorepo scope (ai_demo, db, logger, uploads, Redis/jobs, CI); hub inventory; OAuth error policy; Swagger prod; dependency audit; E2E/contract/IDOR/CSRF doc; canonical Mermaid + render validation; private-method and test comments; **§16/§17/§18** master checklists; super-admin + mermaid-style prompt cross-links.
