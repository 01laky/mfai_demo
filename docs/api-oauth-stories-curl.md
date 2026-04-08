# BeDemo API: OAuth2, Faces a Stories — curl návod

Tento dokument popisuje, ako si cez **curl** overiť **OAuth2** registráciu a token, nastavenie **face role** (nutné pre zobrazenie zoznamu stories) a kompletný **Stories** flow. Hodí sa pri lokálnom vývoji aj pri smoke teste po nasadení.

## 1. Základná URL (BASE)

| Prostredie | Typická URL | Poznámka |
|------------|-------------|----------|
| Docker Compose (`docker-compose.dev.yml`) | `http://127.0.0.1:8000` | `ASPNETCORE_URLS` mapuje kontajner na host **8000**. |
| `dotnet run` z Visual Studio / `launchSettings` | `http://127.0.0.1:8080` | Over v `BeDemo.Api/Properties/launchSettings.json`. |

V príkazoch nižšie použijeme:

```bash
export BASE=http://127.0.0.1:8000
```

Ak voláš API na inom hoste/porte, zmeň `BASE`.

### Overenie, že beží aktuálna verzia API

Swagger UI: `$BASE/swagger/index.html`  
OpenAPI JSON: `$BASE/swagger/v1/swagger.json`

Po pridaní Stories musí v OpenAPI JSON existovať cesta obsahujúca `Stories` (napr. `/api/Stories` — ASP.NET routovanie je case-insensitive, takže `/api/stories` funguje rovnako). Ak endpointy **Stories** v Swaggeri **chýbajú**, kontajner alebo proces beží so **starým buildom** — urob **rebuild** image / reštart `dotnet run` po `git pull`.

## 2. OAuth2 klient (vývojové defaults)

Hodnoty z `BeDemo.Api/appsettings.json` (Development):

| Pole | Hodnota |
|------|---------|
| `clientId` | `be-demo-client` |
| `clientSecret` | `be-demo-secret-very-strong-key` |

V produkcii musia byť tajné kľúče v konfigurácii/sekretoch, nie v repozitári.

## 3. Registrácia používateľa

`POST /api/oauth2/register` — **AllowAnonymous**.

```bash
EMAIL="you+$(date +%s)@example.com"
PASS='Test123!@#'

curl -sS -X POST "$BASE/api/oauth2/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"firstName\":\"Test\",\"lastName\":\"User\"}"
```

Úspech: JSON s `userId`, `profileId`, prípadne `faceProfileCount`.  
Zlyhanie: `400` s chybami Identity (napr. slabé heslo, duplicitný e-mail).

## 4. Token — password grant

`POST /api/oauth2/token` — **AllowAnonymous**.

JSON používa **camelCase** property names (napr. `grantType`, `clientId`, `accessToken`).

```bash
TOK_JSON=$(curl -sS -X POST "$BASE/api/oauth2/token" \
  -H "Content-Type: application/json" \
  -d "{
    \"grantType\": \"password\",
    \"clientId\": \"be-demo-client\",
    \"clientSecret\": \"be-demo-secret-very-strong-key\",
    \"username\": \"$EMAIL\",
    \"password\": \"$PASS\"
  }")

ACCESS_TOKEN=$(echo "$TOK_JSON" | jq -r .accessToken)
REFRESH_TOKEN=$(echo "$TOK_JSON" | jq -r .refreshToken)
echo "$TOK_JSON" | jq .
```

Odpoveď pri úspechu obsahuje napr.:

- `accessToken` — JWT pre hlavičku `Authorization: Bearer …`
- `refreshToken` — na obnovenie access tokenu
- `expiresIn`, `tokenType` (typicky `Bearer`)

Chyby: `401` s `error` / `errorDescription` (OAuth2 error objekt), alebo `503` ak databáza nie je pripravená.

## 5. Token — refresh_token grant

```bash
TOK_JSON=$(curl -sS -X POST "$BASE/api/oauth2/token" \
  -H "Content-Type: application/json" \
  -d "{
    \"grantType\": \"refresh_token\",
    \"clientId\": \"be-demo-client\",
    \"clientSecret\": \"be-demo-secret-very-strong-key\",
    \"refreshToken\": \"$REFRESH_TOKEN\"
  }")
```

## 6. Face role — prečo je to dôležité pre Stories

`GET /api/stories?faceId=…` vráti zoznam **len** používateľom, ktorí v danom face majú **face rolu inú než host**.

Konštanta hosta v kóde: `FACE_HOST` (`UserRole.FaceRoleNames.FaceHost`). Nový používateľ po registrácii často dostane predvolene **FACE_HOST**; vtedy je potrebné cez API nastaviť napr. **FACE_USER**.

### 6.1 Zoznam faces (autorizovaný)

```bash
curl -sS "$BASE/api/faces" -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

Vyber `id` cieľového face → `FACE_ID`.

### 6.2 Zoznam face rolí (verejný endpoint)

```bash
curl -sS "$BASE/api/faces/face-roles" | jq .
```

Nájdi `id` záznamu s `name` = `FACE_USER` (alebo iná ne-host rola) → `USER_ROLE_ID`.

### 6.3 Nastavenie mojej face role

```bash
curl -sS -X PUT "$BASE/api/faces/$FACE_ID/my-role" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"userRoleId\": $USER_ROLE_ID}" | jq .
```

## 7. Stories — kompletný curl flow

Stručný prehľad endpointov je v repozitári **be_demo**: [`STORIES_API.md`](../be_demo/STORIES_API.md).

### 7.1 Vytvorenie draftu

```bash
STORY_JSON=$(curl -sS -X POST "$BASE/api/stories" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Smoke test story"}')

STORY_ID=$(echo "$STORY_JSON" | jq -r .id)
echo "$STORY_JSON" | jq .
```

Bez poľa `faceIds` (alebo prázdne) cieli story **všetky** face (rovnaká idea ako pri reeloch). Voliteľne pošli `faceIds: [1,2]`.

### 7.2 Nahranie obrázka (multipart)

Povinné: aspoň jeden súbor pred publish. `sortOrder` 0–9.

```bash
curl -sS -X POST "$BASE/api/stories/$STORY_ID/images" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@/cesta/k/fotke.jpg;type=image/jpeg" \
  -F "sortOrder=0" \
  -F "description=Voliteľný popis" | jq .
```

### 7.3 Publikácia (ihneď)

```bash
curl -sS -X POST "$BASE/api/stories/$STORY_ID/publish" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"scheduledPublishAt":null}' | jq .
```

Naplánovanie: nastav `scheduledPublishAt` na ISO UTC reťazec; worker spracuje job `story.publish`.

### 7.4 Zoznam stories pre face (non-host viewer)

```bash
curl -sS "$BASE/api/stories?faceId=$FACE_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

Ak si stále **FACE_HOST** v tomto face, zoznam bude prázdny alebo nevhodná odpoveď podľa logiky API.

### 7.5 Ďalšie volania

- Detail: `GET /api/stories/{id}?faceId=…`
- Moje: `GET /api/stories/me`
- View: `POST /api/stories/{id}/view?faceId=…`
- Likes / comments: pozri tabuľku v `STORIES_API.md`

## 8. Jednoskriptový smoke test (bash)

Skript predpokladá `jq`, `curl` a platný `BASE`. Po registrácii nastaví `FACE_USER` na prvom face a vytvorí story s minimálnym JPEG (1×1) z base64, ak máš pripravený súbor `/tmp/story-smoke.jpg`.

```bash
#!/usr/bin/env bash
set -euo pipefail
BASE="${BASE:-http://127.0.0.1:8000}"
EMAIL="smoke+$(date +%s)@example.com"
PASS='Test123!@#'

curl -sf "$BASE/swagger/index.html" >/dev/null || { echo "API nebeží na $BASE"; exit 1; }

curl -sS -X POST "$BASE/api/oauth2/register" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" | jq .

TOK=$(curl -sS -X POST "$BASE/api/oauth2/token" -H "Content-Type: application/json" \
  -d "{\"grantType\":\"password\",\"clientId\":\"be-demo-client\",\"clientSecret\":\"be-demo-secret-very-strong-key\",\"username\":\"$EMAIL\",\"password\":\"$PASS\"}" | jq -r .accessToken)

FACE_ID=$(curl -sS "$BASE/api/faces" -H "Authorization: Bearer $TOK" | jq -r '.[0].id')
ROLE_USER=$(curl -sS "$BASE/api/faces/face-roles" | jq -r '.[] | select(.name=="FACE_USER") | .id')

curl -sS -X PUT "$BASE/api/faces/$FACE_ID/my-role" \
  -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" \
  -d "{\"userRoleId\":$ROLE_USER}" | jq .

# Ak /api/stories v Swaggeri neexistuje, nasledujúce kroky vrátia 404 — rebuild API.
STORY_ID=$(curl -sS -X POST "$BASE/api/stories" -H "Authorization: Bearer $TOK" \
  -H "Content-Type: application/json" -d '{"title":"smoke"}' | jq -r .id)

# Nahrať súbor namiesto preskočenia:
# curl -sS -X POST "$BASE/api/stories/$STORY_ID/images" -H "Authorization: Bearer $TOK" \
#   -F "file=@/tmp/story-smoke.jpg" -F "sortOrder=0"

curl -sS "$BASE/api/stories?faceId=$FACE_ID" -H "Authorization: Bearer $TOK" | jq .
```

## 9. Lint a testy v monorepe

Z koreňa `mfai_demo`:

```bash
./lint-all.sh
```

Backend testy (len test projekt):

```bash
cd be_demo && dotnet test BeDemo.Api.Tests/BeDemo.Api.Tests.csproj
```

Frontend:

```bash
cd fe_demo && yarn lint && yarn format:check && yarn test && yarn build
```

## 10. Súvisiaca dokumentácia

- [Stories API (tabuľka endpointov)](../be_demo/STORIES_API.md)
- [Docker dev stack](../docker-compose.dev.yml) — porty FE/BE/admin
- [README](../README.md) — celkový prehľad repozitára
