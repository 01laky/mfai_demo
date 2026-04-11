# Security gap analysis — `_mfai_demo` (BeDemo)

This file satisfies the **SECURITY_GAP_ANALYSIS.md** deliverable from `docs/prompts/security-hardening-full-stack-edge-tests-agent-prompt.md` (checklist section 16). It is reconciled with **code + tests** as of the latest security-hardening iteration.

## Implemented (high level)

| Area | Implementation |
| ---- | -------------- |
| **O1** OAuth clients | `OAuthClients` table, hashed secrets (`IPasswordHasher<OAuthClient>`), `ValidateClientAsync`, seeder `SeedOAuthClientsAsync`, migration `AddOAuthClients`. |
| **O2** Rate limits | Fixed window per IP on `POST /api/oauth2/token` and `POST /api/oauth2/register`; **429** + **`Retry-After`** via `RateLimiterOptions.OnRejected`. Testing bypass via `OAuth2:BypassRateLimitInTesting` (default true); `RateLimitedOAuthWebApplicationFactory` sets it false for 429 tests. |
| **O4** Body signature | Rejected with **400** `invalid_request`; tests in `SecurityEdgeCaseTests`. |
| **J3 / J6** | `ValidAlgorithms` ES512; claim **`atv`** + `OnTokenValidated`; `ApplicationDbContext` invalidates on `PasswordHash` / `UserRoleId` change + refresh revocation; tests `AccessTokenVersionTests`, integration fixes after role promotion. |
| **K3 / K4** | `GET /api/oauth2/jwks`; optional **`Jwt:PreviousSigningPemPath`** + **`Jwt:PreviousKeyId`** for dual verification keys; `IssuerSigningKeys` on JwtBearer + `OAuth2Service` internal validation. |
| **H1** | `SecurityHeadersMiddleware` + minimal **CSP**; `SecurityHeadersIntegrationTests`. |
| **BE tests** | `OAuthErrorPolicyIntegrationTests`, `OAuthRateLimit429Tests`, `JwtValidationEdgeTests`, `ECDSAKeyServiceTests`, `RefreshTokenConcurrencyTests`, `OAuthExemptPathRegressionTests`, extended `OAuthJwksTests`, etc. |
| **FE / admin** | Vitest: `fe_demo/src/acl/__tests__/permissions.test.ts`, `admin_demo/src/acl/__tests__/permissions.test.ts`; existing `useMeCapabilities` / `jwtUtils` tests. |
| **Dependencies** | `dotnet list package --vulnerable`: **no vulnerable NuGet** (BeDemo.Api / Tests). `yarn npm audit` (fe_demo): **clean** after axios **1.15.0** + vite **7.3.2**; admin_demo same. |

## Remaining / deferred (with rationale or tracking)

| Item | Status |
| ---- | ------ |
| **Register policy 429** | **Covered** in `OAuthRateLimit429Tests.Register_burst_then_token_burst_each_return_429_with_retry_after` (dedicated factory, short windows, delay between phases). |
| **K1 production vault** | PEM path / env injection supported; **HSM/vault** — document operator procedure; full automation **TRACK-INFRA-KMS**. |
| **mTLS / private_key_jwt** | Not implemented; **TRACK-OAUTH-MTLS** if product requires confidential client PKI. |
| **Per-client_id / per-username rate partitions** | Currently **per IP** only for fixed window; extend **TRACK-OAUTH-RL-PARTITION**. |
| **Cypress E2E in CI** | Often skipped via `SKIP_CYPRESS=1`; **manual** path: [docs/guides/manual-oauth-smoke.md](./docs/guides/manual-oauth-smoke.md). **TRACK-CI-E2E-AUTH** to add a minimal always-on job if desired. |
| **IDOR matrix across all controllers** | Representative ACL tests exist; full resource matrix — **TRACK-QA-IDOR-MATRIX**. |
| **Mermaid CLI render gate in CI** | Diagrams added/updated in `docs/guides/`; validate locally with `@mermaid-js/mermaid-cli` or GitHub preview — **TRACK-DOCS-MERMAID-CI**. |
| **ai_demo gRPC threat model** | Brief cross-link in security doc; deep threat model — **TRACK-AI-GRPC-THREAT**. |

## Operational runbook (short)

- **JWT keys:** set `Jwt:SigningPemPath` + `Jwt:KeyId`; for rotation overlap set `Jwt:PreviousSigningPemPath` + `Jwt:PreviousKeyId`, deploy, wait for old `exp`, clear previous config.  
- **DB:** `dotnet ef database update` in `be_demo/BeDemo.Api`.  
- **OAuth demo client:** seeded `be-demo-client`; rotate by updating `OAuthClients` row + app config for new demo secret if needed.  
- **Audits:** run `dotnet list package --vulnerable` and `yarn npm audit` per release; record here or in CI logs.

## Prompt checklist (sections 16–18) — condensed

- **Gap analysis in repo:** this file — **done**.  
- **BE edge tests:** expanded suite — **done** (see `BeDemo.Api.Tests` names above).  
- **FE Vitest:** permissions + existing auth/capabilities tests — **done**.  
- **E2E:** manual script — **done** (`manual-oauth-smoke.md`); Cypress when enabled — **tracked** above.  
- **Mermaid canonical set:** key rotation + J6 + baseline updates in `security-crypto-sockets.md`, auth flows in `authentication-and-sessions.md`, hub matrix `signalr-hub-security-matrix.md` — **done** (CI render gate **tracked**).  
- **Full monorepo submodule README sweep:** not exhaustive — **TRACK-DOCS-SUBMODULES** if required as a separate doc pass.
