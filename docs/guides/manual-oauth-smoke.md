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

## Copy-paste (`curl`, replace `API` and values)

Assume `API=http://localhost:8000` (or your mapped port).

```bash
API=http://localhost:8000
EMAIL="smoke_$(date +%s)@test.com"

curl -sS -X POST "$API/api/oauth2/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Test123!@#\",\"firstName\":\"S\",\"lastName\":\"M\"}"

TOK=$(curl -sS -X POST "$API/api/oauth2/token" \
  -H 'Content-Type: application/json' \
  -d "{\"grantType\":\"password\",\"clientId\":\"be-demo-client\",\"clientSecret\":\"be-demo-secret-very-strong-key\",\"username\":\"$EMAIL\",\"password\":\"Test123!@#\"}")
REF=$(echo "$TOK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refreshToken',''))")

curl -sS -o /dev/null -w "%{http_code}\n" "$API/public/api/me/capabilities" \
  -H "Authorization: Bearer $(echo "$TOK" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")"

curl -sS -X POST "$API/api/oauth2/token" \
  -H 'Content-Type: application/json' \
  -d "{\"grantType\":\"refresh_token\",\"clientId\":\"be-demo-client\",\"clientSecret\":\"be-demo-secret-very-strong-key\",\"refreshToken\":\"$REF\"}"
```

## Security checks (optional)

- Wrong `client_secret` → **401** `invalid_client`.
- Wrong password → **401** `invalid_grant`.
- Response includes security headers (`X-Content-Type-Options`, `Content-Security-Policy`) on JSON routes.
