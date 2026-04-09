# Autentifikácia, JWT a „zostať trvalo prihlásený“

Tento dokument podrobne vysvetľuje **prihlásenie** v projekte BeDemo naprieč **API** (`be_demo`), **hlavným frontendom** (`fe_demo`) a **admin rozhraním** (`admin_demo`): OAuth2 password grant, pole **`rememberMe`**, konfiguráciu dĺžky platnosti JWT, úložisko v prehliadači a spôsob, ako klient zistí **vypršanie** tokenu.

Anglická verzia (rovnaká štruktúra): [authentication-and-sessions.md](./authentication-and-sessions.md).  
Návod cez **curl** (registrácia, token): [api-oauth-stories-curl.md](./api-oauth-stories-curl.md).

---

## 1. Základné pojmy a význam

| Pojem | Čo znamená v tomto projekte |
|-------|-----------------------------|
| **Access token (prístupový token)** | **JWT** reťazec, ktorý API vráti z `POST /api/oauth2/token`. Prehliadač ho uloží a pri volaniach API posiela hlavičku `Authorization: Bearer <token>`. |
| **Nárok `exp` v JWT** | Čas vo formáte Unix (sekundy), do kedy je token z pohľadu API **platný**. Po vypršaní API odpovie **401 Unauthorized** — bez ohľadu na to, či UI ešte používateľa „zobrazuje“ ako prihláseného. |
| **„Zostať trvalo prihlásený“ (`rememberMe`)** | **Nie** je to druhá, paralelná relácia. Je to len **príznak v tele požiadavky na token**, ktorý povie serveru: vydaj JWT s **dlhšou** životnosťou (iná hodnota v konfigurácii). Spôsob uloženia tokenu v prehliadači je rovnaký ako pri krátkej relácii (`localStorage`). |
| **Refresh token** | V odpovedi API pole `refreshToken` **existuje**, ale grant typu **`refresh_token` na serveri nie je implementovaný** (validácia a obnova nefungujú). Pre „dlhé“ prihlásenie sa teda spoliehame na **dlho platný access JWT**, ak používateľ zaškrtne zostať prihlásený. |

**Praktický záver:** krátka relácia = krátky čas do `exp`; trvalé prihlásenie = dlhý čas do `exp`, oboje stále jeden bearer token v `localStorage`.

---

## 2. Backend (`be_demo`)

### 2.1 Endpoint `POST /api/oauth2/token`

- Endpoint je **verejný** z pohľadu používateľa (bez JWT), ale **middleware** pred kontrolérom overí **`client_id`** a **`client_secret`** (OAuth2 klient z konfigurácie).
- Telo požiadavky zodpovedá modelu **`OAuth2TokenRequest`** (súbor `BeDemo.Api/Models/DTOs/OAuth2Request.cs`).
- V **`OAuth2Service.GenerateTokenAsync`** sa spracúva:
  - **`password`** — prihlásenie menom/e-mailom a heslom; voliteľne **`rememberMe`**.
  - **`refresh_token`** — v demo implementácii **vždy zlyhá** (nie je uložená validácia refresh tokenu v databáze).

### 2.2 Pole `rememberMe` — význam hodnôt

| Hodnota v JSON | Význam na serveri |
|----------------|-------------------|
| Pole **vynechané** | Krátka životnosť tokenu (`Jwt:ExpiresInMinutes`). |
| **`false`** alebo **`null`** | Rovnako krátka životnosť. |
| **`true`** | Dlhá životnosť (`Jwt:ExpiresInMinutesRememberMe`). |

Server používa výhradne podmienku **`RememberMe == true`** (striktná rovnosť). To je zámerne zosúladené s frontendom: ten do tela posiela **`rememberMe: true` len ak je zaškrtnutý checkbox** (funkcia `buildPasswordGrantTokenRequest`).

### 2.3 Konfigurácia JWT v `appsettings.json`

| Kľúč | Význam |
|------|--------|
| **`Jwt:ExpiresInMinutes`** | Počet **minút** platnosti access tokenu pri **normálnom** prihlásení (bez „zostať prihlásený“). |
| **`Jwt:ExpiresInMinutesRememberMe`** | Počet **minút** platnosti access tokenu, ak klient pošle **`rememberMe: true`**. V demo prostredí môže byť veľmi vysoký (prakticky „nekonečno“); v produkcii treba **vedome nastaviť** podľa bezpečnostnej politiky. |
| **`Jwt:Issuer`**, **`Jwt:Audience`** | Štandardné JWT tvrdenia; musia sedieť medzi generovaním a validáciou tokenu. |

**Prepísanie cez premenné prostredia** (Docker, Kubernetes):

```text
Jwt__ExpiresInMinutes=60
Jwt__ExpiresInMinutesRememberMe=43200
```

(`__` je štandardný spôsob v .NET, ako z plochého mena urobiť vnorený kľúč.)

### 2.4 Odpoveď `OAuth2TokenResponse`

- **`expiresIn`** — životnosť **access** tokenu v **sekundách** (zodpovedá zvolenej minútovej konfigurácii × 60).
- **`accessToken`** — samotný JWT.
- **`refreshToken`** — v demo režime generovaný reťazec; **obnovenie relácie cez refresh grant nie je funkčné**.

### 2.5 Podpis požiadavky (voliteľné)

Ak telo obsahuje **`signature`** a **`signatureAlgorithm`**, middleware overí **ECDSA ES512**. Bežné webové klienty tieto polia **neposielajú**. Formát kanonickej správy pre podpis **nezahŕňa** `rememberMe` — pri zmene by sa museli aktualizovať všetci klienti, ktorí podpisujú.

### 2.6 Kľúčové súbory na backende

| Súbor | Úloha |
|-------|--------|
| `BeDemo.Api/Controllers/OAuth2Controller.cs` | HTTP endpointy token a register. |
| `BeDemo.Api/Middlewares/OAuth2Middleware.cs` | Overenie klienta, voliteľný podpis, čítanie tela požiadavky. |
| `BeDemo.Api/Services/OAuth2Service.cs` | Logika grantov, výber minút podľa `rememberMe`, podpis JWT. |
| `BeDemo.Api/Models/DTOs/OAuth2Request.cs` | DTO vrátane `RememberMe`. |

---

## 3. Hlavný frontend (`fe_demo`)

### 3.1 Zostavenie tela login požiadavky

- **`src/hooks/api/authTokenRequest.ts`** — funkcia **`buildPasswordGrantTokenRequest`**: zostaví password grant a nastaví **`rememberMe` na `true` len vtedy, keď parameter je striktne `true`**; inak **`false`**. Tým sa predíde nejednoznačnosti (napr. reťazec z formulára).
- **`src/hooks/api/useAuthApi.ts`** — hook **`useLogin`** zavolá generovaného API klienta, uloží token do **`localStorage`** a nastaví axios predvolenú hlavičku cez **`setAuthToken`**.

### 3.2 Kľúče v `localStorage`

| Kľúč | Účel |
|------|------|
| `auth_token` | Aktuálny JWT access token. |
| `auth_refresh_token` | Uložený, ak API niečo vráti; obnova cez refresh na klientovi **nespolahlivá**, kým BE refresh neimplementuje. |
| `auth_user` | JSON s údajmi pre UI (dekód z JWT / fallback); **nie** je to samostatná bezpečnostná vrstva. |

### 3.3 Funkcia `isTokenExpired`

- Súbor **`src/utils/jwtUtils.ts`**.
- Rozdelí JWT na časti, dekóduje **payload**, prečíta **`exp`** (sekundy od epochy).
- Ak **`exp` chýba** — považuje sa token za **neexpirovaný** (výnimka pre zvláštne prípady; naše API `exp` vždy nastavuje).
- Ak je reťazec **poškodený** (málo segmentov, neplatný base64/JSON) — považuje sa za **expirovaný**, aby sa vyčistilo úložisko a používateľ sa musel znova prihlásiť.

### 3.4 `AuthContext` a React Query

- **`useAuthToken`** pri načítaní z cache/`localStorage` skontroluje expiráciu; pri expirovanom tokene **vymaže** všetky tri kľúče a vráti `null`.
- **`AuthProvider`**:
  - Pri štarte načíta stav z úložiska; expirovaný token zahodí a vyčistí auth query.
  - **Každých 30 sekúnd** skontroluje expiráciu; pri vypršaní zobrazí **toast** (relácia vypršala).
  - Počúva udalosť **`auth:unauthorized`** na `window` (ak ju API vrstva pri 401 vyšle), aby UI sedelo s realitou API.

### 3.5 Prihlasovacia stránka

- **`src/pages/LoginPage.tsx`** — checkbox **`rememberMe`** (predvolene nezaškrtnutý), odovzdá sa do `login(..., { rememberMe })`.
- Preklady: **`pages.login.rememberMe`** v `src/i18n/locales/sk.json` (a en, cz).

### 3.6 Konfigurácia klienta

- **`clientId` / `clientSecret`** pre volanie tokenu pochádzajú z **`src/config/env`** (build-time). Musia sa zhodovať s **`OAuth2`** sekciou v API, inak middleware vráti chybu klienta.

---

## 4. Admin (`admin_demo`)

Architektúra je **rovnaká** ako pri `fe_demo`:

- Rovnaké súbory konceptu: **`authTokenRequest.ts`**, **`useAuthApi.ts`**, **`jwtUtils.ts`**, **`AuthContext.tsx`**, **`LoginPage.tsx`**, lokalizácie.
- **`useAuthToken`** tiež pri expirovanom tokene čistí úložisko.
- Je tu **sledovanie relácie** (interval) a text **`pages.logout.sessionExpired`** pri vypršaní JWT.

---

## 5. Testovanie

| Vrstva | Kde | Čo overuje |
|--------|-----|------------|
| **BE integrácia** | `be_demo/BeDemo.Api.Tests/OAuth2RememberMeTests.cs` | Pri dočasnom prepísaní `Jwt:*` v testovacom hostiteľovi sa `rememberMe` true/false/bez poľa správne prejaví v **`expiresIn`** odpovede. |
| **FE jednotky** | `fe_demo/src/utils/__tests__/jwtUtils.test.ts` | Hranice `exp`, poškodené tokeny. |
| **FE jednotky** | `fe_demo/src/hooks/api/__tests__/authTokenRequest.test.ts` | Mapovanie `rememberMe` na boolean v tele požiadavky. |
| **Admin** | `admin_demo/src/utils/__tests__/jwtUtils.test.ts`, `.../authTokenRequest.test.ts` | Rovnaká logika ako vo FE. |

Príkazy:

```bash
cd be_demo && dotnet test BeDemo.Api.Tests/BeDemo.Api.Tests.csproj
cd fe_demo && yarn test
cd admin_demo && yarn test
```

---

## 6. Bezpečnosť a produktové upozornenia

1. **Dlhý platný JWT** na zdieľanom počítači znamená dlhší čas, kedy má ktokoľvek s prístupom k prehliadaču platný token.
2. **`localStorage`** je čitateľný z JavaScriptu (riziko pri XSS). **HttpOnly cookies** by vyžadovali iný návrh (nie je súčasť tejto demo architektúry).
3. Hodnotu **`Jwt:ExpiresInMinutesRememberMe`** treba **nastavovať podľa prostredia** (dev vs produkcia).
4. Kým nebude **implementovaný a persistovaný** refresh token na serveri, netreba spoliehať na obnovu relácie cez `refresh_token` grant.

---

## 7. Súvisiace dokumenty

- [api-oauth-stories-curl.md](./api-oauth-stories-curl.md) — curl príklady vrátane `rememberMe`.
- [DEVELOPMENT.md](./DEVELOPMENT.md) — vývoj v monorepe, CI, skripty.
- [be_demo/README.md](../be_demo/README.md) — prehľad API.
