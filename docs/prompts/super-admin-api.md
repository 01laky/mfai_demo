# Super-admin only API — analýza, návrh a prompt pre implementáciu (AI)

Jazyk dokumentu: **slovenčina** (technické identifikátory a cesty v kóde ostávajú v angličtine).  
Súvisiaca dokumentácia: [acl-and-capabilities.md](../guides/acl-and-capabilities.md), [authentication-and-sessions.md](../guides/authentication-and-sessions.md).

---

## 1. Účel dokumentu

1. **Analyzovať** súčasný stav autorizácie `SUPER_ADMIN` vs `ADMIN` v repozitári `_mfai_demo`.
2. **Definovať**, čo znamená „super-admin only API“ z hľadiska bezpečnosti, routingu a dátového modelu.
3. **Zapísať detailný prompt pre AI agenta** (sekcia 10), ktorý stačí skopírovať do novej konverzácie a implementovať zmeny konzistentne s existujúcim kódom.

Tento dokument **nesamplementuje** kód; je vstupom pre ďalší implementačný krok.

---

## 2. Súčasný stav (inventory)

### 2.1 Globálna rola a JWT

- Globálna rola je na `ApplicationUser.UserRoleId` → tabuľka `UserRoles` (`Name`, `Scope` = `Global` | `Face`).
- Konštanty mien: `UserRole.GlobalRoleNames` — `SuperAdmin` = `"SUPER_ADMIN"`, `Admin` = `"ADMIN"`, `User`, `Host`.
- Pri vydaní access tokenu `OAuth2Service.BuildAccessJwtAsync` načíta aktuálny názov role z DB a vloží **jeden** claim `ClaimTypes.Role` s týmto názvom (tenký token, A1/A9).
- Po zmene `UserRoleId` v DB **starý JWT ešte obsahuje starú rolu** až do expirácie; nová rola sa prejaví po **obnovení tokenu** (`refresh_token` grant) alebo novom **password** logine — poznámka v [`OAuth2Service`](../be_demo/BeDemo.Api/Services/OAuth2Service.cs) (BuildAccessJwtAsync XML).

### 2.2 Kto dnes môže čo (platform vs super)

- `PlatformAccessRules.IsGlobalAdmin` = `ADMIN` **alebo** `SUPER_ADMIN` (JWT role claim).
- `PlatformAccessRules.IsGlobalSuperAdmin` = len `SUPER_ADMIN`.
- `CanManageAllFaces` = `IFaceScopeContext.IsAdminFaceScope` **a** `IsGlobalAdmin` — teda **obidve** roly majú rovnakú úroveň pre „platform“ operácie pod prefixom admin tváre (napr. `/admin/...`).
- `CanMutateGlobalPageTypes` = rovnaký prah ako `CanManageAllFaces`.
- `UsersController.CreateUser` / `UpdateUser` vyžadujú `CanManageAllFaces()` — **ADMIN aj SUPER_ADMIN** môžu vytvárať/aktualizovať používateľov, ale **nemôžu meniť globálnu rolu** (v `UpdateUserModel` nie je `UserRoleId`).
- **Neexistuje** verejný REST endpoint na zmenu `ApplicationUser.UserRoleId` (globálna rola) — zmena je prakticky len seed / DB / skripty (`InitializeDatabase`, `IntegrationTestSeed`).

### 2.3 Capabilities a frontend

- `AccessCapabilitiesService`: `platform:super` (`AclPermissionKeys.PlatformSuper`) len ak `IsGlobalSuperAdmin(principal)`; `platform:admin` ak `CanManageAllFaces`.
- FE: `fe_demo/src/acl/permissions.ts` — `canSuperAdmin(caps)` už existuje; katalóg kľúčov musí zostať v parite s `BeDemo.Api.Security.AclPermissionKeys` (Vitest).

### 2.4 Testovacia infraštruktúra

- `IntegrationTestSeed`: `integration-superadmin@test.com` + `GetSuperAdminAccessTokenAsync`; `integration-admin@test.com` + `GetAdminAccessTokenAsync`.
- `AclTestClients`: `GetPlatformSuperAdminTokenAsync`, `GetPlatformAdminTokenAsync`; OAuth cez `CreateUnscopedClient()`, API cez `CreateFaceClient("admin")` pre platform scope.
- Vzor testov: [`PageTypesControllerTests.cs`](../be_demo/BeDemo.Api.Tests/PageTypesControllerTests.cs) (401/403/200 podľa tokenu a face klienta).

### 2.5 Audit

- `SecurityAuditLog`: šablóny pre face role, PageType, face config — **žiadna** šablóna pre zmenu globálnej platformovej roly.

### 2.6 OpenAPI

- `BearerAuthOperationFilter` pridáva `security: Bearer` pre akcie s `[Authorize]` (bez `[AllowAnonymous]`).

---

## 3. Problém a biznis požiadavka

**Požiadavka:** API, ktoré môže volať **iba** globálny `SUPER_ADMIN`, nie bežný `ADMIN`.

**Dôvody (z dizajnu ACL, Part D.6):**

- Oddeliť **eskaláciu** (priradenie `SUPER_ADMIN`, prípadne `ADMIN`) od bežnej správy používateľov.
- Znížiť blast radius: kompromitovaný `ADMIN` účet nesmie urobiť „break-glass“ zmeny.
- Zosúladiť produkt s capabilities: UI môže skrývať akcie za `platform:super` (`canSuperAdmin`).

---

## 4. Návrh rozsahu (fázy)

### 4.1 MVP (odporúčané ako prvý merge)

Jeden zdroj pravdy pre zmenu globálnej roly:

- **HTTP** `PUT` (alebo `PATCH`) pod **admin face prefixom** — konzistentné s `CanManageAllFaces` (platform UI beží na `/admin/...`).
- **Autorizácia:** volajúci musí mať:
  - platný JWT,
  - `IFaceScopeContext.IsAdminFaceScope == true`,
  - `_access.IsGlobalSuperAdmin(User) == true`.
- **Tel požiadavky:** napr. `{ "userRoleId": <int> }` kde `userRoleId` odkazuje na riadok `UserRoles` s `Scope == Global` a `Name` je v **whitelist** (nižšie).
- **Validácie (povinné):**
  1. Cieľový používateľ existuje (`FindByIdAsync`).
  2. Cieľový `UserRole` existuje, `Scope == Global`.
  3. Cieľová rola je jedna z: `USER`, `ADMIN`, `HOST`, `SUPER_ADMIN` (presne podľa `UserRole.GlobalRoleNames` — načítať z DB podľa mena, nie hardcodovať ID).
  4. **Zákaz** zmeny vlastnej globálnej roly volajúcim (prevencia self-lockout / eskalácie v jednom kroku).
  5. **Ochrana posledného SUPER_ADMIN:** ak meníš niekoho z `SUPER_ADMIN` na inú rolu, po zmene musí v systéme zostať aspoň jeden používateľ s touto rolou (inak `400` alebo `409` s jasnou správou).
  6. Voliteľne: zákaz degradácie iného `SUPER_ADMIN` ak volajúci nie je jediný super (produktové rozhodnutie — v MVP stačí bod 5).

- **Odpoveď:** 200 + JSON so `id`, `email`, `globalRole` (meno), prípadne `userRoleId`.
- **Chyby:** 400 (validácia), 401 (bez tokenu), 403 (`ADMIN` alebo tenant scope), 404 (neexistujúci user — alebo 404 vs 403 podľa politiky úniku informácií; pre interné admin API je 404 pre neznáme ID akceptovateľné).

### 4.2 Rozšírenia (mimo MVP, backlog)

- `GET /api/platform/.../global-roles` — read-only zoznam globálnych rolí pre UI (stále super-only alebo admin-readable — rozhodnutie).
- Samostatné endpointy `promote-super-admin` / `demote-super-admin` s extra potvrdením alebo 2FA (produkcia).
- Rate limiting na super-only cesty (napr. vlastná politika v `Program.cs`).
- Event do externého SIEM namiesto len Seq logu.

---

## 5. Technické rozhodnutia (odporúčania)

| Téma | Odporúčanie |
|------|-------------|
| Umiestnenie | Nový controller, napr. `PlatformUsersController` alebo `SuperAdminUsersController`, route `api/platform/users/{id}/global-role` — aby sa neplietlo s existujúcim `UsersController`. |
| Face scope | Povinný **admin** prefix URL (`RoutingMiddleware`); rovnaký pattern ako `PageTypesController`. |
| Kontrola prístupu | Centralizovať: nová metóda v `PlatformAccessRules`, napr. `CanPerformSuperAdminPlatformActions(IFaceScopeContext, ClaimsPrincipal)` = `IsAdminFaceScope && IsGlobalSuperAdmin`, a expozícia cez `IAccessEvaluator` (konzistentné s A3). |
| DTO | V `Models/DTOs/` alebo pri controlleri — jasný názov `SetGlobalRoleRequest`. |
| EF | `UserManager` + `ApplicationDbContext` — po zmene `UserRoleId` `UpdateAsync` alebo priamy update cez context s kontrolou konzistencie; preferuj `UserManager` ak ide o používateľské polia. |
| Audit | Nová metóda `SecurityAuditLog.GlobalRoleChanged(...)` s `HttpContext.TraceIdentifier`. |
| OpenAPI | Len `[Authorize]` na controlleri; filter pridá Bearer automaticky. |
| Dokumentácia | Aktualizovať `docs/guides/acl-and-capabilities.md` (nový riadok v tabuľke / file map). |

---

## 6. Hrozby a mitigácie

| Riziko | Mitigácia |
|--------|-----------|
| ADMIN obíde ochranu | Gate výhradne `IsGlobalSuperAdmin`, nie `IsGlobalAdmin`. |
| Volanie z tenant URL | Vyžadovať `IsAdminFaceScope`; tenant JWT s `SUPER_ADMIN` by stále nemal mať admin scope bez `/admin/` prefixu — overiť v teste. |
| Únik, kto je super | Nepovinne nelogovať celý email do verejných chýb; audit len do structured logu. |
| Žiadny SUPER_ADMIN po zmene | Povinná kontrola počtu pred commitom. |
| Stale JWT | Dokumentovať v XML controllera: po zmene roly cieľa musí používateľ refreshnúť token. |

---

## 7. Test plán (akceptačné kritériá)

Pridať test triedu, napr. `SuperAdminGlobalRoleTests.cs` (alebo rozšíriť existujúcu ACL sadu):

1. **SUPER_ADMIN** + `CreateFaceClient("admin")` + Bearer → `PUT` úspech (napr. zmena test používateľa z `USER` na `ADMIN` a späť).
2. **ADMIN** + admin face + Bearer → **403**.
3. **SUPER_ADMIN** + `CreateFaceClient("public")` (tenant scope) → **403** (ak gate vyžaduje admin scope).
4. Bez tokenu → **401**.
5. Cieľový user neexistuje → **404**.
6. Neplatné / face `userRoleId` → **400**.
7. Pokus odsunúť posledného SUPER_ADMIN → **400/409**.
8. Self-target zmena roly → **400** (alebo 403).

Použiť existujúce seed používateľov alebo dočasného usera vytvoreného cez `UserManager` v teste.

---

## 8. Frontend (voliteľné v tom istom PR)

- Ak admin UI potrebuje tlačidlo „Zmeniť globálnu rolu“, zobraziť len ak `canSuperAdmin(caps)` z `useMeCapabilities`.
- Nový tenký API klient (axios) s base URL cez existujúci face routing interceptor (`/admin/...`).
- **Nepridávať** nový permission string, pokiaľ MVP stačí `platform:super` (už zodpovedá super-only UI).

---

## 9. Súbory, ktoré AI pravdepodobne upraví / vytvorí

| Akcia | Cesta (relatívne k root repa) |
|-------|-------------------------------|
| Nový controller | `be_demo/BeDemo.Api/Controllers/...` |
| DTO | `be_demo/BeDemo.Api/Models/DTOs/...` |
| `PlatformAccessRules` + `IAccessEvaluator` + `AccessEvaluator` | `be_demo/BeDemo.Api/Utils/`, `Services/` |
| `SecurityAuditLog` | `be_demo/BeDemo.Api/Utils/SecurityAuditLog.cs` |
| Testy | `be_demo/BeDemo.Api.Tests/...` |
| Dokumentácia | `docs/guides/acl-and-capabilities.md` |
| Voliteľne FE | `admin_demo/src/...`, `fe_demo/src/acl/...` |

---

## 10. PROMPT PRE AI AGENTA (skopíruj celý blok nižšie)

```
You are implementing a SUPER_ADMIN-only HTTP API in the BeDemo .NET 10 solution (repo: _mfai_demo, project be_demo/BeDemo.Api).

GOAL
- Expose a secure endpoint to change an ApplicationUser’s GLOBAL role (UserRoleId) in UserRoles table.
- Only callers with JWT role claim SUPER_ADMIN (UserRole.GlobalRoleNames.SuperAdmin) AND admin face URL scope may call it (same pattern as platform admin: IFaceScopeContext.IsAdminFaceScope).
- Regular ADMIN must receive 403. Tenant-scoped URL (e.g. /public/...) must receive 403 even if JWT is SUPER_ADMIN.

CONTEXT (read before coding)
- Global role is ApplicationUser.UserRoleId → UserRoles; OAuth2 JWT carries single ClaimTypes.Role from DB at token issue (OAuth2Service.BuildAccessJwtAsync).
- Use PlatformAccessRules.IsGlobalSuperAdmin; extend with a new rule e.g. PlatformAccessRules.CanPerformSuperAdminPlatformActions(IFaceScopeContext, ClaimsPrincipal) = IsAdminFaceScope && IsGlobalSuperAdmin, and expose on IAccessEvaluator / AccessEvaluator.
- Existing UsersController uses CanManageAllFaces for create/update but does NOT change global role.
- SecurityAuditLog exists; add GlobalRoleChanged(actorUserId, targetUserId, previousRoleName, newRoleName, correlationId).
- Integration tests: CustomWebApplicationFactory, AclTestClients.GetPlatformSuperAdminTokenAsync / GetPlatformAdminTokenAsync, CreateFaceClient("admin") vs CreateFaceClient("public"), CreateUnscopedClient for OAuth.
- BearerAuthOperationFilter already marks [Authorize] operations with OpenAPI security.

IMPLEMENTATION TASKS
1) Add DTO SetGlobalRoleRequest { int UserRoleId } (JSON camelCase).
2) Add controller (name your choice, e.g. PlatformUsersController) with route prefix api/platform/users and method:
   PUT {id}/global-role
   - [Authorize] on class
   - Load target user by id; return 404 if missing
   - If !CanPerformSuperAdminPlatformActions(_faceScope, User) return Forbid()
   - Resolve caller user id from claims; if target id equals caller return 400 (cannot change own global role)
   - Load requested UserRole by id; if null or Scope != RoleScope.Global return 400
   - Whitelist allowed global role Names: USER, ADMIN, HOST, SUPER_ADMIN (use UserRole.GlobalRoleNames constants compared to role.Name)
   - Before saving: if target is currently SUPER_ADMIN and new role is not SUPER_ADMIN, ensure at least one other user remains SUPER_ADMIN after update; else return 409 or 400 with clear error body
   - Persist UserRoleId change (UserManager.UpdateAsync or equivalent), then SecurityAuditLog.GlobalRoleChanged with HttpContext.TraceIdentifier
   - Return 200 with { id, email, globalRole (name), userRoleId }

3) XML docs on controller: note that target user’s JWT keeps old role until refresh/login.

4) Tests: new file SuperAdminGlobalRoleTests.cs (or similar) covering:
   - Super admin + admin face client → success
   - Admin JWT + admin face → 403
   - Super admin + public face client → 403
   - No auth → 401
   - Invalid role id → 400
   - Last super demotion blocked
   - Self change blocked

5) Update docs/guides/acl-and-capabilities.md (summary + file map) briefly.

CONSTRAINTS
- Do not widen ADMIN to this endpoint.
- Do not use AspNetRoles for authorization.
- Match existing code style, naming, and patterns (IAccessEvaluator, PlatformAccessRules, Forbid vs NotFound policy as in other controllers).
- Keep the diff focused; no unrelated refactors.
- Run: dotnet test be_demo/BeDemo.Api.Tests/BeDemo.Api.Tests.csproj and fix failures.

DELIVERABLE
- All tests green; endpoint documented; audit log called on success.
```

---

## 11. Poznámka pre ľudského reviewera

Pred merge odporúčam explicitne schváliť:

- či **HOST** môže super priradiť cez rovnaký endpoint ako ostatné globálne roly,
- či **404** vs **403** pre neexistujúceho usera v admin API,
- či je potrebná **2FA** alebo ticket systém pre produkciu (mimo demo).

---

*Dokument vytvorený ako podklad pre implementáciu super-admin only API; po implementácii doplniť odkaz na PR a prípadne skrátiť sekciu 10.*
