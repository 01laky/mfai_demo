# Manual OAuth smoke (when Cypress / full stack is not running)

Use this when automated E2E is skipped (`SKIP_CYPRESS=1`) or CI has no browser agent. **Tracking:** complements `scripts/test-all.sh` E2E; not a substitute for Cypress where that pipeline is enabled.

## Preconditions

- API running with a reachable base URL (e.g. `https://localhost:8000` or Docker port mapping).
- PostgreSQL migrated and seeded if not using `Testing` in-memory.

## Steps

1. **Register**  
   `POST /api/oauth2/register` with JSON `{ "email": "...", "password": "Test123!@#", "firstName": "A", "lastName": "B" }`  
   Expect **200**.

2. **Token (password grant)**  
   `POST /api/oauth2/token` with JSON matching `OAuth2TokenRequest`: `grant_type`, `client_id`, `client_secret`, `username`, `password`.  
   Expect **200** and JSON with `accessToken`, `refreshToken`.

3. **Authenticated call**  
   `GET /api/me/capabilities` with header `Authorization: Bearer <accessToken>` on a **face-prefixed** base URL if your deployment uses routing (e.g. `/public/api/me/capabilities`).  
   Expect **200** JSON with `permissions` array.

4. **Refresh**  
   `POST /api/oauth2/token` with `grant_type=refresh_token` and `refresh_token` from step 2.  
   Expect **200** and **new** `refreshToken`. Replaying the **old** refresh string must return **401** `invalid_grant`.

5. **JWKS**  
   `GET /api/oauth2/jwks` — expect **200** and `keys` non-empty.

## Security checks (optional)

- Wrong `client_secret` → **401** `invalid_client`.  
- Wrong password → **401** `invalid_grant`.  
- Response includes security headers (`X-Content-Type-Options`, `Content-Security-Policy`) on JSON routes.
