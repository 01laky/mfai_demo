# Strong cryptography, JWT, API, and WebSocket security — implementation backlog (AI-oriented)

Language: English. Audience: implementers / security review / AI agents. Actionable checklist; not end-user documentation.

**Scope:** Signing keys, JWT hardening, TLS, REST API, SignalR/WebSockets, OAuth2 client flows, operational controls.

**Related:** [acl-and-capabilities.md](./acl-and-capabilities.md) (authorization / capabilities); this file focuses on **transport + token + key lifecycle**.

---

## P0 — Signing keys and JWT issuer (foundational)

- [ ] **K1** Replace ephemeral in-process `ECDsa.Create(P-521)` (`ECDSAKeyService` constructor) with **deterministic key material in production**: load signing key from **Azure Key Vault**, **AWS KMS**, **HashiCorp Vault**, or **mounted PEM/PFX** with restricted filesystem permissions. Development may keep ephemeral keys; production must not rotate keys on every deploy unless coordinated with token invalidation strategy.
- [ ] **K2** Prefer **asymmetric signing only**: keep **private** key in HSM/vault; expose **public** key (or JWKS) to resource servers and gateways that validate JWTs. Never distribute private key to clients.
- [ ] **K3** Implement **JWKS endpoint** (e.g. `GET /.well-known/jwks.json` or `/api/oauth2/jwks`) publishing **public** `ECDSA` (or `RSA`) JWK set with `kid` matching JWT header `kid` / claim `key_id`. Enables multi-instance API clusters and API gateways to validate without shared private key.
- [ ] **K4** **Key rotation:** support **two** active signing keys (current + previous) for verification window; new tokens signed with current; old tokens valid until `exp`. Document rotation runbook (promote key, overlap period, retire old).
- [ ] **K5** Align algorithm choice with ecosystem: **ES512** (P-521) is strong; ensure all validators (gateways, libraries, mobile) support it. If interoperability limits appear, document fallback policy (e.g. **RS256** with 3072+ bit RSA) as secondary key in JWKS — do not weaken default without explicit decision.
- [ ] **K6** Store **no private key** in `appsettings.json` or git. Use environment variables referencing vault URIs, or runtime injection from secret store.

---

## P0 — JWT content and validation (API + SignalR consumers)

- [ ] **J1** Set `TokenValidationParameters.ValidateLifetime = true` in `JwtBearerOptions` (`Program.cs`). Align with issued `Expires` in `OAuth2Service` (already set per `Jwt:ExpiresInMinutes` / RememberMe).
- [ ] **J2** Set non-zero `ClockSkew` (e.g. 1–2 minutes) or keep zero only if all clocks are NTP-synced; document choice.
- [ ] **J3** Enforce `ValidateAudience`, `ValidateIssuer`, `ValidateIssuerSigningKey` (already largely present); add **`ValidAlgorithms`** whitelist (e.g. only `ES512`) to reject algorithm confusion.
- [ ] **J4** Add JWT **`aud`** (audience) per client or per surface if needed (e.g. `bedemo-api` vs `bedemo-signalr`) — optional but reduces token reuse across services.
- [ ] **J5** Short **access token TTL** in production (e.g. 5–15 minutes); long sessions via **refresh tokens** stored server-side (see `OAuthRefreshTokenStore` / [acl-and-capabilities.md](./acl-and-capabilities.md)), rotated on use, revocable.
- [ ] **J6** On **global role or security-sensitive claim change**, invalidate refresh tokens or bump **token version** claim (`token_version`) checked on each request — forces re-auth after privilege change.
- [ ] **J7** Do not put **PII** or large blobs in JWT claims; keep claims minimal (`sub`, `role`, `jti`, `iat`, `exp`, `nbf`, optional `token_version`).

---

## P0 — OAuth2 token endpoint and client authentication

- [ ] **O1** **Client authentication:** move `client_id` / `client_secret` validation from static config to **hashed secrets in DB** (bcrypt/Argon2) or confidential client registry; support **client credential rotation**.
- [ ] **O2** **Rate limiting** on `POST /api/oauth2/token` and `POST /api/oauth2/register`: per-IP, per-`client_id`, per-username (sliding window or token bucket). Return `429` with `Retry-After`.
- [ ] **O3** **Lockout / backoff** integration with Identity lockout on failed password grants (already partially configured on Identity options — verify it applies to OAuth password path).
- [ ] **O4** Fix or remove **optional request body ECDSA signature** (`OAuth2Middleware` + `OAuth2Service.ValidateRequestSignature`): current design verifies against **server** key — not standard “client signs with client private key.” Replace with either: (a) **mTLS** at reverse proxy for confidential clients, or (b) **private_key_jwt** (JWT client assertion, RFC 7523), or (c) drop feature and rely on TLS + `client_secret` + rate limits.
- [ ] **O5** **PKCE** for any future authorization-code flow from public clients (SPAs); document that password grant is **deprecated** in OAuth2.1 for third-party apps — migrate when feasible.
- [ ] **O6** **Register endpoint:** same rate limits; consider CAPTCHA or invite-only registration in production; email verification before full activation.

---

## P0 — TLS and transport (HTTP + WebSocket)

- [ ] **T1** Terminate **TLS 1.2+** (prefer **TLS 1.3**) at reverse proxy (nginx, Traefik, cloud LB) or Kestrel with valid **server certificate** (Let’s Encrypt or corporate PKI). No mixed content for browser clients.
- [ ] **T2** **HSTS** header on HTTPS responses (`Strict-Transport-Security`) with appropriate `max-age` (e.g. ≥ 6 months) after confirming HTTPS everywhere.
- [ ] **T3** **WebSocket upgrade (`wss://`)** only in production; `ws://` allowed only on localhost dev. SignalR clients must use same origin policy or explicit allowed origins.
- [ ] **T4** Optional **mTLS** for admin or machine-to-machine callers: client certificates validated at proxy; forward verified client identity as header only if proxy strips spoofed headers.

---

## P0 — SignalR / WebSockets (same security bar as REST)

- [ ] **S1** Keep **`[Authorize]`** on hubs; ensure **JwtBearer** `OnMessageReceived` reads `access_token` query param **only over WSS** in production (query string can leak in logs — prefer **subprotocol** or **post-connect** negotiation if upgrading stack allows; if not, **short-lived tokens** + **no server logging of query**).
- [ ] **S2** Validate **same JWT rules** as HTTP: issuer, audience, lifetime, signing key, algorithm whitelist. No separate “weak” path for SignalR.
- [ ] **S3** **Face scope:** if hub methods are tenant-sensitive, inject `IFaceScopeContext` (or parse allowed face from connection URL after `RoutingMiddleware`) and **reject** connections or method calls that do not match claimed tenant. Document required client URL: `wss://host/{face}/hubs/...?access_token=...`.
- [ ] **S4** **Authorization per hub method:** use `IHubFilter` or explicit checks for sensitive operations (e.g. broadcast to group = tenant id only).
- [ ] **S5** **Connection limits** per user id / IP at proxy or custom middleware to reduce DoS.
- [ ] **S6** **AI / gRPC from hub** (`ChatHub.SendToAi`): rate limit per user; optional quota; audit log; reject unauthenticated or expired connection.

---

## P1 — API surface and headers

- [ ] **H1** Add security headers middleware: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` or `frame-ancestors` via CSP, **`Content-Security-Policy`** appropriate for API (often minimal for JSON API).
- [ ] **H2** **`Referrer-Policy`**, **`Permissions-Policy`** as needed.
- [ ] **H3** CORS: replace `AllowAnyMethod` / review if all methods needed; keep **`AllowCredentials`** only with **explicit origins** (already partially explicit — add production domains via config).
- [ ] **H4** Disable **detailed error bodies** in production for auth failures where they aid enumeration; log details server-side only.

---

## P1 — OpenAPI and clients

- [ ] **D1** OpenAPI 3: `components.securitySchemes.bearer` (JWT); apply `security` globally; document **`Authorization: Bearer <token>`** for REST.
- [ ] **D2** Document SignalR: WSS URL pattern, query param name `access_token`, token TTL recommendation.

---

## P1 — Monitoring and audit

- [ ] **M1** Structured logs for **auth failures** (no passwords): `invalid_client`, `invalid_grant`, `invalid_signature`, JWT validation failure reason (expired, bad signature, wrong `kid`).
- [ ] **M2** **Audit log** for key rotation, client secret change, admin user creation, global role change (`A22` ACL doc).
- [ ] **M3** Alerting on spike in 401/403/429 on `/api/oauth2/token`.

---

## P2 — Advanced / optional

- [ ] **X1** **Token binding** or **DPoP** (RFC 9449) if threat model includes token theft from browser storage.
- [ ] **X2** **Certificate pinning** for mobile/native apps (document trade-offs: operational pain vs MITM resistance).
- [ ] **X3** **FIPS**-validated modules if deployment requires (Windows FIPS policy, cloud HSM FIPS endpoints).

---

## Current baseline (repo facts — do not assume improved until implemented)

| Area | Current behavior |
|------|------------------|
| JWT signing | In-memory **P-521 ECDSA**, new key per process start (`ECDSAKeyService` singleton) |
| Certificate | **No** X.509 for JWT signing in code |
| JWT `ValidateLifetime` | **Disabled** in `JwtBearer` (`Program.cs`) |
| Refresh tokens | Issued; **not** stored/validated for refresh grant (`OAuth2Service`) |
| Optional OAuth body signature | **ES512** verify using **server** key — not client PKI model |
| SignalR auth | JWT via query `access_token`; same bearer config as API |
| TLS | Dev often HTTP; production must enforce TLS at edge |

---

## Suggested implementation order (for agents)

1. **K1–K4, J1–J5** — production keys + JWKS + lifetime + refresh store (blocks most other work).
2. **T1–T3, S1–S3** — TLS + SignalR parity + face scope on hubs if multi-tenant.
3. **O1–O4** — client secrets + rate limits + fix/remove broken request signing model.
4. **H*, D*, M*** — headers, OpenAPI, logging.

---

## Changelog

- v1: Initial backlog for strong crypto, JWT, API, WebSockets (AI-oriented).
