# ACL, roles, and authorization — TODO + technical design (AI-oriented)

Language: English. Audience: implementers / AI agents. Not end-user documentation.

**Related (crypto, TLS, JWT lifecycle, SignalR):** [`SECURITY_CRYPTO_SOCKETS_DESIGN.md`](./SECURITY_CRYPTO_SOCKETS_DESIGN.md)

**Implemented surface (concise):** [`docs/acl-and-capabilities.md`](./docs/acl-and-capabilities.md) — permission keys, `GET …/api/me/capabilities`, PageTypes / `my-role`, refresh tokens, rate limits, audit logs, OpenAPI Bearer, **test file index**. **Part A** is kept as a checklist and was **closed in Revision 7** (all items addressed in code or linked docs — see Part F).

---

## Part A — Implementation TODO (checklist)

Use this as a work backlog; order is suggestive, not mandatory.

- [x] **A1** Document canonical source of truth — **`ApplicationUser` XML** + [`authentication-and-sessions.md`](./docs/authentication-and-sessions.md): JWT uses `UserRole` / `UserRoles.Name`; `AspNetRoles` not used for bearer authZ.
- [x] **A2** Align `JwtBearerOptions.TokenValidationParameters.ValidateLifetime` with `OAuth2Service` token `Expires` — **`ValidateLifetime = true`**, `ClockSkew = Zero` in `Program.cs`; tests: `AclBearerJwtValidationTests`.
- [x] **A3** Introduce single abstraction — **`IAccessEvaluator`** / `AccessEvaluator` (scoped DI); policy-based `IAuthorizationHandler` deferred as optional refinement.
- [x] **A4** Define enum/string catalog: `PermissionResource`, `PermissionAction` (or equivalent) — **done as string catalog** `AclPermissionKeys` (+ FE `ACL_PERMISSION_KEYS`); full enum split deferred.
- [x] **A5** Define role → permission matrix — **`Security/AclRolePermissionMatrix.cs`** (documentation) + [`docs/acl-and-capabilities.md`](./docs/acl-and-capabilities.md) tables; runtime = `AccessCapabilitiesService` + controller gates.
- [x] **A6** Refactor controllers — inject **`IAccessEvaluator`**; shared **`TenantFaceAccessGate`** for tenant face 404 pattern (FacesController).
- [~] **A7** Specify semantics of `SUPER_ADMIN` vs `ADMIN` — **capabilities** add `platform:super` only for `SUPER_ADMIN`; **most controller gates** still treat both as global admins (`IsGlobalAdmin`). Further divergence optional.
- [x] **A8** Specify semantics of global `HOST` vs face `FACE_HOST` — **`UserRole`**, **`FaceRoleParticipation`**, seeder file header comments.
- [x] **A9** Decide JWT strategy — documented in **`docs/authentication-and-sessions.md` §6** (thin token + DB; invalidation / refresh behaviour).
- [x] **A10** Add API surface for UI: **`GET /{face}/api/me/capabilities`** (`MeController` + `AccessCapabilitiesService`); FE/admin consume via `fetchMeCapabilities` / `useMeCapabilities`.
- [x] **A11** Audit SignalR — **`ChatHub`** file header + [`docs/acl-and-capabilities.md`](./docs/acl-and-capabilities.md) (face-prefixed `/{face}/hubs/...`); hub still `[Authorize]`; per-connection `IFaceScopeContext` not injected (documented gap if product requires it).
- [x] **A12** Migration hygiene — integration tests **`UserRolesSeededScopeTests`** assert seeded `RoleScope`; production legacy rows = operational follow-up if any.
- [x] **A13** Optional DB `RolePermissions` — **deferred**: static matrix + `AclPermissionKeys`; reopen if product needs runtime-editable ACL UI.
- [x] **A14** Cross-reference — `docs/README.md` links here and to **`docs/acl-and-capabilities.md`**; `docs/DEVELOPMENT.md` links both.
- [x] **A15** `PageTypesController` mutations gated by **`CanMutateGlobalPageTypes` / `CanManageAllFaces()`**; tests: `PageTypesControllerTests`, `AclIntegrationTests`.
- [x] **A16** `SetMyFaceRole` whitelist via **`FaceRoleSelfServiceRules`**; `GET face-roles` hides `FACE_ADMIN` from non–platform-admin; tests: `AclIntegrationTests`, `FaceRoleSelfServiceRulesTests`.
- [x] **A17** OAuth2 `refresh_token` grant — **`OAuthRefreshToken`** + **`OAuthRefreshTokenStore`** (hash, rotation, single-use); tests: **`RefreshTokenEdgeCaseTests`**; config `Jwt:RefreshTokenDays*`.
- [x] **A18** Deprecate or harden `AuthController` — **documented** as legacy cookie path in **`AuthController`** XML; SPAs should use OAuth2 (A18 prose).
- [x] **A19** Social subgraph — **`UsersController.GetUsers`** remarks document `UserBlocks` + tenant directory scope; further APIs (messages, likes) follow same tenant rules when exposed.
- [x] **A20** `ChatHub.SendToAi` — **`IChatHubAiRateLimiter`** (memory, configurable window); authenticated-only hub retained.
- [x] **A21** Rate limit `POST /api/oauth2/token` — **`EnableRateLimiting("oauth-token")`** + `AddRateLimiter` in `Program.cs` (relaxed in `Testing`).
- [x] **A22** Audit trail — **`SecurityAuditLog`** structured templates for face role + PageType mutations (`TraceIdentifier` correlation).
- [x] **A23** OpenAPI — **`AddSecurityDefinition("Bearer", …)`** in SwaggerGen; exempt routes described in description; **`BearerAuthOperationFilter`** adds per-operation Bearer `security` for `[Authorize]` actions (Swashbuckle 10).

---

## Part B — Current system (as-built inventory)

### B.1 HTTP pipeline order (`Program.cs`)

Relevant middleware sequence:

1. `UseCors`
2. Dev: OpenAPI / Swagger
3. `UseMiddleware<RoutingMiddleware>()` — face prefix strip + `HttpContext.Items` + query rewrite
4. `UseRouting`
5. `UseMiddleware<OAuth2Middleware>()` — only `POST /api/oauth2/token` body validation (client, optional signature)
6. `UseStaticFiles`
7. `UseAuthentication` — JWT bearer
8. `UseMiddleware<FaceScopeEnforcementMiddleware>()` — private face requires auth; query `faceId` / `requestFaceID` consistency vs scope
9. `UseAuthorization`
10. Map hubs + controllers

Implication: any authorization attribute runs **after** face scope is established (for non-exempt paths).

### B.2 Exempt paths (`Routing.IsExemptFromFaceScope`)

Prefixes: `/api/oauth2`, `/api/auth`, `/swagger`, `/openapi`, `/favicon`, `/uploads/`.

- No `Items` face keys.
- `IFaceScopeContext.IsAvailable == false` on these routes.

### B.3 Face prefix routing (`RoutingMiddleware`)

Input path: `/{faceKebab}/api/...` or `/{faceKebab}/hubs/...`.

- First segment matched against `Face.Index` via `Routing.ConvertToKebabCase`.
- Unknown prefix → 403 `Face path not allowed`.
- Bare `/api/...` or `/hubs/...` without prefix (and not exempt) → 400 with instructional body.

**Query stripping and injection:**

- Removes all client `faceId` and `requestFaceID`.
- Re-adds `requestFaceID=<resolved Face.Id>`.
- If tenant face: re-adds `faceId=<same Face.Id>`.
- If admin face (`FaceScopeConstants.AdminFaceIndex`, case-insensitive): preserves optional client `faceId` if parseable positive int (cross-tenant targeting for admin UI).

**Items set:**

- `BeDemo.RequestFaceId` → `int`
- `BeDemo.RequestFaceIndex` → `string`
- `BeDemo.RequestFaceIsPublic` → `bool` from `Face.IsPublic`
- `BeDemo.RequestFaceIsAdminScope` → `bool` from `IsAdminFaceIndex(Face.Index)`

**Caching:** `IMemoryCache` key `"Faces"` for face list (5 min TTL). Invalidate on face mutations via `FacesController.InvalidateFacesRoutingCache()`.

### B.4 Face scope enforcement (`FaceScopeEnforcementMiddleware`)

 Preconditions (non-exempt paths):

1. `Items` must contain valid `RequestFaceId`; else 400.
2. If not public face: `User.Identity.IsAuthenticated` required; else 401 plain text.
3. Tenant scope: every query value for `faceId` and `requestFaceID` must match scoped face id (missing key allowed).
4. Admin scope: `requestFaceID` must match admin face id; optional `faceId` values must parse and exist in `Faces` table.

### B.5 JWT construction (`OAuth2Service.GenerateTokenAsync`)

Claims:

- `NameIdentifier`, `Name`, `Email`, optional `GivenName`, `Surname`
- `jti`, `iat`
- **Single** `ClaimTypes.Role` = `ApplicationUser.UserRole.Name` (global `UserRoles` row), loaded from DB at token issue time

Token descriptor: ECDSA ES512, issuer/audience from config, `Expires` from `Jwt:ExpiresInMinutes` or `Jwt:ExpiresInMinutesRememberMe` when `RememberMe == true`.

**Not in JWT:** face roles (`UserFaceRole`), multiple global roles, permissions bitmask.

### B.6 JWT validation (`Program.cs` JwtBearer)

`ValidateLifetime = true` and `ClockSkew = TimeSpan.Zero` so access token `exp` is enforced consistently with `OAuth2Service` token lifetime (**A2**). Misconfigured or expired tokens yield **401** before controller execution. Tests: `AclBearerJwtValidationTests`.

### B.7 Data model

**`ApplicationUser`:** extends `IdentityUser`; FK `UserRoleId` → `UserRoles` (custom table, not `AspNetRoles`).

**`UserRole`:**

- `Name`, `Description`, `RoleScope` enum (`Global` | `Face`)
- Global constants: `SUPER_ADMIN`, `ADMIN`, `USER`, `HOST`
- Face constants: `FACE_ADMIN`, `FACE_USER`, `INZERENT`, `SUBSCRIBER`, `FACE_HOST`

**`UserFaceRole`:** composite key `(UserId, FaceId)`; `UserRoleId` must reference a `UserRole` with `Scope == Face`.

**`UserProfile` / `UserFaceProfile`:** per-user profile and per-face participation (visited, intro flags, `IsActive` synced with role semantics in migrations).

**Legacy / confusion:** EF migrations include `AspNetRoles`, `AspNetUserRoles` (Identity). OAuth2 JWT does **not** populate roles from Identity role store. Authorization uses `User.IsInRole` which reads **role claims** from JWT — fed only by custom `UserRole.Name`.

### B.8 Seeder behavior (`DatabaseSeeder.SeedUserRolesAsync`)

Upserts global and face role rows by **name**, sets `RoleScope` correctly, repairs wrong `Scope` on existing rows.

Historical migration `20260118000332_AddUserRole` inserted rows without `Scope` column (later added); runtime seeder is corrective.

### B.9 Controller authorization patterns (recurring)

**Pattern `CanManageAllFaces()`:**

```text
_faceScope.IsAdminFaceScope && (User.IsInRole("ADMIN") || User.IsInRole("SUPER_ADMIN"))
```

Used in: `FacesController`, `UsersController`, `StoriesController`, `PagesController`, `AlbumsController` (verify `AlbumsController` parity with `PagesController`).

**Shared implementation:** `PlatformAccessRules.CanManageAllFaces(IFaceScopeContext, ClaimsPrincipal)` centralizes the admin-face + global-admin check; new code should call it instead of duplicating the expression. **`PageTypesController`** mutations use **`PlatformAccessRules.CanMutateGlobalPageTypes`** (admin scope + global admin — see `PlatformAccessRules.cs`).

**Pattern tenant isolation:**

- Filter queries by `_faceScope.FaceId` or `GateTenantFaceOrNotFound(targetFaceId)` returning `NotFound` to avoid ID leakage.

**`IFaceScopeContext.ResolveDataFaceId(int? queryFaceId)`:**

- Admin scope + optional query → use query if valid.
- Else → always scoped `FaceId`.

### B.10 Face-specific business rules

**`FaceRoleParticipation`:**

- `IsHostFaceRole` → name equals `FACE_HOST` (ordinal string compare).
- `IsActiveForFaceRoleName` → not host (directory “active” participant).

**`StoryViewerRules`:**

- `ViewerHasFaceMembershipAsync` — any `UserFaceRole` row for `(userId, faceId)` (includes host).
- `ViewerIsActiveNonHostInFaceAsync` — membership + non-host face role; used e.g. for story view recording endpoint.

**`FacesController.GetFacesConfig`:**

- Admin prefix + authenticated + global admin → all faces with pages graph.
- Admin prefix + non-admin → `Forbid`.
- Public face + anonymous → all **public** faces (cross-public directory).
- Else → single scoped face.
- Augments response with `myFaceRoleId` / `myFaceRoleName` from `UserFaceRoles` when authenticated.

**`UsersController.GetUsers`:**

- Non-admin: restrict to users having `UserFaceProfile` for `_faceScope.FaceId`.
- Admin `CanManageAllFaces`: full user list (subject to blocklist filters).

**`UsersController.CreateUser`:** requires `CanManageAllFaces`.

### B.11 SignalR

Hubs: `ChatHub`, `MessengerHub`, `ChatRoomHub` — `[Authorize]` on hub class; authentication via query `access_token` (JwtBearer events).

Face scope for hub connections depends on client using face-prefixed URL so `RoutingMiddleware` runs; verify integration tests / docs for actual URL shape.

### B.12 ASP.NET attributes usage

Widespread `[Authorize]` without `Roles =`. No centralized policy names for `ADMIN`, `SUPER_ADMIN`, or face permissions.

### B.13 OAuth2 controller surface (`OAuth2Controller`)

- Route prefix `/api/oauth2` (exempt from face routing).
- **No** `[Authorize]` on controller class: `POST .../token` and `POST .../register` are reachable without bearer token.
- `OAuth2Middleware` validates `client_id` / `client_secret` (and optional ES512 body signature) for **token** only; register endpoint is not covered by that middleware — rely on `UserManager` + validation only.
- Implication: registration and token issuance are **platform-global** operations; not tenant-scoped.

### B.14 Legacy `AuthController` (`/api/auth/*`, exempt)

- Also exempt from face prefix; typically **no** bearer requirement on `register`/`login` (cookie-oriented Identity flows).
- Parallel to OAuth2: two registration/login paths if both enabled — increases attack surface and documentation burden.

### B.15 `[AllowAnonymous]` on face-scoped controllers

- `FacesController.GetFacesConfig` (`GET .../faces/config`) — anonymous allowed when scoped face is **public** (see `B.10`); admin branch still requires global admin when under admin prefix.
- `FacesController.GetFaceRoles` (`GET .../faces/face-roles`) — **`[AllowAnonymous]`** on any face prefix. Callers **without** `CanManageAllFaces()` receive only self-service face roles (`FACE_USER`, `INZERENT`, `SUBSCRIBER`, `FACE_HOST`); **`FACE_ADMIN` is omitted**. Platform admin on admin scope still receives the full face-scoped role list. Residual risk: anonymous callers can still enumerate **ids and names** for those four roles (product choice vs hardening).

### B.16 `PageTypesController` — global schema mutations

- Class-level `[Authorize]` on the controller.
- **`POST` / `PUT` / `DELETE`** require **`PlatformAccessRules.CanMutateGlobalPageTypes`** (admin face scope + global `ADMIN` or `SUPER_ADMIN`) — same bar as “platform can touch global `PageTypes` table”. **Reads** follow normal `[Authorize]` + tenant routing; integration tests use admin face + platform admin for mutations (`PageTypesControllerTests`, `AclIntegrationTests`).

### B.17 `PUT /api/faces/{id}/my-role` (self-service face role)

- Requires authenticated user + `GateTenantFaceOrNotFound(id)`.
- **`UserRoleId`** must reference a face-scoped `UserRole`. If the caller **does not** have `CanManageAllFaces()`, the role **name** must pass **`FaceRoleSelfServiceRules.IsSelfAssignableFaceRoleName`**; otherwise **403**. Platform admins bypass the whitelist.

### B.22 Capabilities API (`MeController`)

- **`GET /{face-prefix}/api/me/capabilities`** — `[Authorize]`; **400** if the request has no resolved face scope (bare `/api/me/...` without tenant/admin prefix).
- Response: `CapabilitiesResponse` — camelCase JSON fields `globalRole`, `requestFaceId`, `requestFaceIndex`, `isAdminFaceScope`, `myFaceRoleName`, `permissions` (string catalog aligned with **`AclPermissionKeys`**). Operational detail and FE paths: **`docs/acl-and-capabilities.md`**.

### B.18 `AlbumsController` (pattern differs from `PagesController`)

- Uses `CanManageAllFaces()` for mutating operations (create/update/delete paths — verify full file).
- Read paths: filter albums linked to `effectiveFaceId` via `AlbumFaces`; visibility combines `AlbumType` (public vs private/paid) with `CreatorId == UserId`.
- Does **not** use `UserFaceRole` for album list access — membership in face is implicit via album–face link + album type rules.

### B.19 `UsersController` summary

- `GET` list / `GET {id}`: tenant-filtered via `UserFaceProfile` presence for scoped face when not `CanManageAllFaces`.
- `POST` (create user), `PUT` (update user): require `CanManageAllFaces()` only.
- No endpoint in scanned file for **changing `ApplicationUser.UserRoleId`** (global role) — likely manual/DB/seeder only; document if intentional.

### B.20 `IFaceScopeContext.ResolveDataFaceId(int? queryFaceId)` (precise semantics)

- If `IsAdminFaceScope && queryFaceId.HasValue && queryFaceId.Value > 0` → returns `queryFaceId.Value`.
- Else → returns scoped `FaceId` (from URL prefix).
- Admin callers omitting `faceId` operate on **admin face id** as data scope for methods that pass `null` through — callers must be audited per endpoint.

### B.21 Tests vs API surface drift

- `BeDemo.Api.Tests` reference controllers (e.g. `FaceProfiles`, `Blogs`, `Reels`, `FaceWallTickets`, `FaceChatRooms`) **not** present under `BeDemo.Api/Controllers/` in current tree — either removed, renamed, or live in another project. Agents must not assume those endpoints exist; regenerate inventory when reintroduced.

---

## Part C — Gap analysis (machine-readable)

| ID | Topic | Observation | Risk |
|----|--------|-------------|------|
| G1 | ACL | No single permission matrix; rules embedded per controller method | Drift, incomplete audits |
| G2 | JWT lifetime | Bearer validates `exp` (`ValidateLifetime` true, zero skew — **B.6**) | **G12** refresh-token grant still mismatches client expectations |
| G3 | Role duplication | Identity `AspNetRoles` vs `UserRoles` | Confusion, dead schema |
| G4 | SUPER_ADMIN vs ADMIN | Treated identically in `IsInRole` checks | No escalation path definition |
| G5 | FACE_ADMIN vs global ADMIN | FACE_ADMIN not wired to CMS power; CMS power is URL `/admin/` + global role | Product semantics unclear |
| G6 | JWT payload | Face roles omitted | Every check hits DB; cannot offline-evaluate face permissions from token alone |
| G7 | FE sync | **`GET …/me/capabilities`** + `AclPermissionKeys` / FE `acl/*` (`docs/acl-and-capabilities.md`) | Residual drift if some UI still keys only on role names |
| G8 | PageTypes mutation | **Mitigated** — mutations require `CanMutateGlobalPageTypes` (**B.16**) | Other global config tables (**D.12**) still need explicit audit if added |
| G9 | Self-service face role | **Mitigated** — `FaceRoleSelfServiceRules` whitelist (**B.17**) | Keep whitelist aligned with product when adding face roles |
| G10 | Anonymous face-roles API | **Partially mitigated** — `FACE_ADMIN` hidden for non–platform-admin; four self-service roles still listable anonymously | Accept vs rate-limit / auth if enumeration becomes sensitive |
| G11 | Dual auth entrypoints | OAuth2 + `AuthController` | Inconsistent hardening, duplicate registration semantics |
| G12 | Refresh tokens | **Mitigated (A17)** — hashed rows, rotation, single-use grant; see `OAuthRefreshTokenStore` / `RefreshTokenEdgeCaseTests`. Row kept for changelog only. | — |
| G13 | Albums vs stories | Different enforcement primitives (`AlbumFaces` + type vs `UserFaceRole`) | Harder to unify under one ACL model without explicit rules |
| G14 | Hub tenancy | **Partially mitigated** — hubs resolve `IFaceScopeContext`; `ChatHub` uses per-face broadcast groups + tenant directory check on private messages; `MessengerHub` / `ChatRoomHub` align messaging / rooms with scoped face (see `TenantSocialScopeRules`, `docs/acl-and-capabilities.md`). Residual: review any new hub methods / groups. | Misconfigured client URLs |
| G15 | OpenAPI security | **Mitigated** — `BearerAuthOperationFilter` adds per-operation `security` for `[Authorize]` actions (Swashbuckle 10 + `OpenApiSecuritySchemeReference`). Anonymous / exempt controllers unchanged. | Stale generated clients if spec not regenerated |

---

## Part D — Target architecture (proposal)

### D.1 Dimensions (orthogonal)

1. **Request tenant context** — derived only from URL prefix + middleware (`IFaceScopeContext`). Not client-trusted beyond enforced query rewriting.
2. **Subject** — `sub` / `NameIdentifier` from JWT.
3. **Global platform role** — one of seeded global `UserRoles`; stored on user row; claim `role` in JWT.
4. **Face membership** — `UserFaceRole` (+ optional status on `UserFaceProfile`): defines face-scoped role name.
5. **Permission** — atomic check `(resource, action, scopeDescriptor)` where `scopeDescriptor` might be `Global`, `Face(faceId)`, `OwnResource(userId)`.

### D.2 Recommended permission tuple

Minimal structural type (conceptual):

```text
Resource ∈ { Face, Page, Story, Album, UserDirectory, UserAccount, FaceSettings, ChatRoom, Message, AdBlock, ... }
Action ∈ { Read, List, Create, Update, Delete, Publish, Moderate, Impersonate, ... }
Scope ∈ { Platform, FaceScoped(faceId), Own }
```

Evaluation function:

```text
Evaluate(userId, globalRole, faceMemberships, IFaceScopeContext, Resource, Action, targetEntityFaceId?, targetOwnerUserId?) → Allow | Deny | NotFound
```

Use `NotFound` where applicable to avoid leaking existence across tenants (consistent with current `GateTenantFaceOrNotFound`).

### D.3 Role-to-permission mapping (implementation options)

**Option 1 — Static code matrix:** C# dictionary or switch in one service; versioned in git; fastest to ship.

**Option 2 — Database `RolePermissions`:** `(RoleScope, RoleName, Resource, Action)` rows; admin UI can edit; requires seed + migration + cache invalidation.

**Option 3 — Hybrid:** static defaults + DB overrides merged at startup or cached per role version.

### D.4 ASP.NET Core integration

- Register policies: `RequireAssertion` or custom `AuthorizationHandler<PermissionRequirement>`.
- Requirements carry `(Resource, Action)`; handler resolves `IFaceScopeContext`, loads `UserFaceRole` for `(userId, FaceId)` when `FaceScoped`.
- Prefer **resource-based** handlers for entity-specific checks (e.g. story id → load `Story` → derive `FaceId` from `StoryFaces`).

### D.5 JWT strategies

**Thin token (recommended default):**

- Claims: identity + global role + standard JWT metadata.
- Face authorization always consults DB (or short-lived server-side cache keyed `userId:faceId` with TTL 60–300s).

**Fat token (optional):**

- Add claims `face_id`, `face_role` when issuing **face session** token; reduces DB; complicates revocation — pair with short `exp` and refresh.

### D.6 Explicit SUPER_ADMIN semantics (choose one)

- **Strict:** `SUPER_ADMIN` ⊃ `ADMIN` for all platform permissions; add permissions only for `SUPER_ADMIN` (e.g. delete tenant, rotate signing keys, assign `SUPER_ADMIN`).
- **Collapsed:** remove `SUPER_ADMIN` from product; use single `ADMIN` + audit log.

### D.7 FACE_ADMIN semantics (choose one)

- **Tenant CMS:** grant `Page:Update`, `FaceSettings:Update` for `FaceScoped(currentFace)` when face role is `FACE_ADMIN` **and** request is under tenant URL (not `/admin/`).
- **Moderation only:** FACE_ADMIN can moderate content but not restructure pages — narrow permission set.

Document chosen matrix in same repo file when decided.

### D.8 Capabilities endpoint (implemented contract)

**Implemented** — `MeController` + `AccessCapabilitiesService`; permission strings are **`AclPermissionKeys`** (not fine-grained resource CRUD yet). Example (camelCase JSON):

```json
{
  "globalRole": "USER",
  "requestFaceId": 2,
  "requestFaceIndex": "basic",
  "isAdminFaceScope": false,
  "myFaceRoleName": "FACE_USER",
  "permissions": [
    "face:member",
    "face:role:self-service",
    "tenant:session"
  ]
}
```

FE should render navigation from **`permissions`** (and scope fields), not from hardcoded global role switches alone. Full list and test index: **`docs/acl-and-capabilities.md`**.

### D.9 SignalR hardening

- If hub operations are tenant-sensitive: pass `faceId` claim or validate connection URL prefix matches expected face; reject cross-tenant group joins.
- Alternatively: require hub path under face prefix and inject `IFaceScopeContext` via hub filter / custom middleware (if supported by hosting model).

### D.10 Testing implications

- Integration tests: matrix of `(facePrefix, globalRole, faceRole, endpoint)` expected status codes.
- Regression tests for query injection bypass (`?faceId=` spoof) already partially covered by middleware; extend for new permission layer.

### D.11 Self-service vs delegated role assignment

- **Self-service:** constrained whitelist of face roles (demo UX: “pick how you participate”). Server validates requested `UserRoleId` ∈ `AllowedSelfServiceFaceRoles`.
- **Delegated:** `FACE_ADMIN` / moderation roles assigned only by `CanManageAllFaces()` or by existing `FACE_ADMIN` with `UserDirectory:Promote` (if introduced).
- On successful delegated change, **invalidate** cached capabilities (`A9`/`A10`) and optionally force re-login if using fat tokens.

### D.12 Split “platform metadata” vs “tenant data” controllers

- Move or protect endpoints that touch **global** tables (`PageTypes`, `ComponentTypes`, `DisplayModes`, future platform config) behind:
  - dedicated route prefix (e.g. `/admin-only/...` still needs face prefix strategy), **or**
  - policy `RequirePlatformAdmin` independent of tenant URL, **or**
  - separate internal API host not exposed to tenant SPAs.
- Tenant SPAs should only receive **read-only** metadata where possible (CDN or build-time snapshot).

### D.13 Anonymous read contracts

- For each `AllowAnonymous` endpoint, classify: **public marketing**, **directory discovery**, **sensitive enumeration**. If sensitive, require auth or rate limit / edge caching only.

### D.14 `NotFound` vs `Forbid` policy

- Preserve **404 for cross-tenant ID guess** on tenant routes.
- Use **403** when caller is authenticated but missing capability (clearer for admin UI); document consistent mapping so FE does not treat 403 as “missing entity”.

---

## Part E — File / type index (navigation aid for agents)

| Concern | Primary locations |
|---------|-------------------|
| Face constants | `be_demo/BeDemo.Api/Utils/FaceScopeConstants.cs` |
| Exempt routes | `be_demo/BeDemo.Api/Utils/Routing.cs` |
| Prefix rewrite | `be_demo/BeDemo.Api/Middlewares/RoutingMiddleware.cs` |
| Post-auth enforcement | `be_demo/BeDemo.Api/Middlewares/FaceScopeEnforcementMiddleware.cs` |
| OAuth2 token | `be_demo/BeDemo.Api/Services/OAuth2Service.cs` |
| JWT middleware config | `be_demo/BeDemo.Api/Program.cs` |
| Face scope accessor | `be_demo/BeDemo.Api/Services/IFaceScopeContext.cs`, `FaceScopeContext.cs` |
| Role entities | `be_demo/BeDemo.Api/Models/UserRole.cs`, `UserFaceRole.cs`, `ApplicationUser.cs` |
| Seeding | `be_demo/BeDemo.Api/Scripts/DatabaseSeeder.cs` |
| Story rules | `be_demo/BeDemo.Api/Utils/StoryViewerRules.cs`, `FaceRoleParticipation.cs` |
| Controllers (current tree) | `FacesController`, `UsersController`, `StoriesController`, `PagesController`, `AlbumsController`, `PageTypesController`, `OAuth2Controller`, `AuthController`, `MeController` |
| Permission string catalog | `be_demo/BeDemo.Api/Security/AclPermissionKeys.cs` |
| Platform / page-type access helpers | `be_demo/BeDemo.Api/Utils/PlatformAccessRules.cs` |
| Self-service face role whitelist | `be_demo/BeDemo.Api/Utils/FaceRoleSelfServiceRules.cs` |
| Capabilities aggregation | `be_demo/BeDemo.Api/Services/AccessCapabilitiesService.cs`, `IAccessCapabilitiesService.cs` |
| Capabilities DTO | `be_demo/BeDemo.Api/Models/DTOs/CapabilitiesResponse.cs` |
| OAuth2 middleware | `be_demo/BeDemo.Api/Middlewares/OAuth2Middleware.cs` |
| OpenAPI Bearer on operations | `be_demo/BeDemo.Api/Swagger/BearerAuthOperationFilter.cs` |
| Tenant directory for hubs / social | `be_demo/BeDemo.Api/Utils/TenantSocialScopeRules.cs` |
| Hubs | `be_demo/BeDemo.Api/Hubs/ChatHub.cs`, `MessengerHub.cs`, `ChatRoomHub.cs` |

---

## Part F — Changelog of this document

- Revision 8: **Part C** sync — **G12/G14/G15** aligned with code (refresh A17, hub tenancy + `TenantSocialScopeRules`, OpenAPI **`BearerAuthOperationFilter`**); **A23** / **Part E** index updated.
- Revision 6: **Doc sync** — updated **B.6, B.9, B.15–B.17**, added **B.22**, refreshed **Part C** rows **G2, G7–G10**, **D.8**, and **Part E** index; **Part G** retained as historical delta table. **H.1(1)** (rewrite stale sections) addressed by this revision.
- Revision 5: Appended **Part G** (stale inventory vs current code) and **Part H** (prioritized follow-up proposals).
- Revision 4: **`docs/acl-and-capabilities.md`** added (operational detail + test index); **`DEVELOPMENT.md`** ACL section; Part A markers updated for **A2, A4, A7 (partial), A10, A14, A15, A16**; cross-links from doc index.
- Initial version: TODO list + expanded technical specification (EN, AI-oriented).
- Revision 2: design review pass — added TODOs **A15–A23**; inventory **B.13–B.21**; gaps **G8–G15**; target sections **D.11–D.14**; expanded file index; documented `PageTypesController` and `SetMyFaceRole` escalation, OAuth2/anonymous endpoints, `ResolveDataFaceId` semantics, test/API drift note.
- Revision 3: cross-link to **`SECURITY_CRYPTO_SOCKETS_DESIGN.md`** (JWT keys, TLS, WebSockets hardening backlog).

---

## Part G — Document sync backlog (historical delta)

**As of Revision 6**, the rows below are merged into **Parts B, C, D, E** above. This table remains as a **changelog** of what the older prose claimed vs what the code does.

| Location | Was true in doc | Current behaviour |
|----------|-----------------|-------------------|
| **B.6** JWT validation | `ValidateLifetime = false` | **`ValidateLifetime = true`**, `ClockSkew = TimeSpan.Zero` in `Program.cs` (A2). |
| **B.15** `GET …/face-roles` | Anonymous receives full face role catalog including `FACE_ADMIN` | For callers **without** `CanManageAllFaces()`, response is **filtered** to self-service roles only (`FACE_USER`, `INZERENT`, `SUBSCRIBER`, `FACE_HOST`). Platform admin on admin scope still sees full list. |
| **B.16** `PageTypesController` | Any authenticated user can mutate global `PageTypes` | **Mutations** (`POST`/`PUT`/`DELETE`) require **`CanMutateGlobalPageTypes`** / `CanManageAllFaces()` (admin face + global Admin/SuperAdmin). Reads remain tenant-accessible where `[Authorize]` allows. |
| **B.17** `PUT …/my-role` | Any face-scoped `UserRoleId` accepted → self-assign `FACE_ADMIN` | **Whitelist** in `FaceRoleSelfServiceRules`; non-whitelisted roles return **403** unless `CanManageAllFaces()`. |
| **Part C — G2** | JWT `Expires` ignored by bearer middleware | **Mitigated** by lifetime validation (see B.6). Refresh-token grant mismatch (**G12**) remains. |
| **Part C — G7** | UI infers authz without server contract | **Mitigated** by `GET …/me/capabilities` + FE `acl/` helpers (`docs/acl-and-capabilities.md`). |
| **Part C — G8, G9** | PageTypes and unrestricted self-role | **Mitigated** in code; table should note **resolved** or move to changelog. |
| **Part C — G10** | Full taxonomy exposure | **Partially mitigated** (`FACE_ADMIN` hidden for tenants/anonymous); role **ids/names** for four roles still enumerable without auth — document risk vs product choice. |
| **D.8** example JSON | States capabilities response “not implemented” | **Implemented** — align example with `CapabilitiesResponse` / `docs/acl-and-capabilities.md` (field names: `requestFaceId`, `requestFaceIndex`, `isAdminFaceScope`, `myFaceRoleName`, `permissions`). |

**Part E** now includes these paths (Revision 6).

---

## Part H — Follow-up proposals (prioritized)

All items below are **suggestions**; track against Part A or new tickets.

### H.1 Short term (low effort, high clarity)

1. ~~**Rewrite stale sections** listed in **Part G**~~ — **done (Revision 6).**
2. **Formal role → capability matrix (lightweight)** — extend `docs/acl-and-capabilities.md` or add **Part A′** here: table of global roles × `AclPermissionKeys` × which mutations (e.g. PageTypes) apply; satisfies the *intent* of **A5** without a full `Resource`/`Action` enum.
3. **Close A1 in prose** — one-page decision: JWT authorization uses **`ApplicationUser.UserRole` / `UserRoles.Name`** in role claims; **`AspNetRoles` / `AspNetUserRoles`** are not used for bearer authZ; deprecate or map in a follow-up migration story.

### H.2 Medium term (architecture)

4. **A3 — Central evaluator or policies** — `IAccessEvaluator` or `AuthorizationHandler` for repeated `(IFaceScopeContext, User, action)` patterns; reduce copy-paste of `CanManageAllFaces` / tenant `NotFound` gates.
5. **A11 + G14 — SignalR audit** — document required hub URL shape under face prefix; verify `RoutingMiddleware` applies; decide whether hubs read `IFaceScopeContext` and how group names bind to `faceId` to prevent cross-tenant joins.
6. **A23 — OpenAPI** — `securitySchemes` (Bearer JWT) and per-operation `security`; list anonymous exempt routes explicitly for generated clients.

### H.3 Heavier / production hardening

7. **A17 — Refresh tokens** — persistent store, rotation, revocation aligned with **A2**; **or** document “intentionally access-JWT-only” and stop returning misleading refresh payloads from token endpoint.
8. **A21 — Rate limiting** — `POST /api/oauth2/token` (middleware or reverse-proxy contract) against brute-force / credential stuffing.
9. **A22 — Audit trail** — structured logs (correlation id) for: global role change, face role assignment, PageType/Page/Face mutations.
10. **A19 / A20 — Social + AI hubs** — extend capabilities or explicit checks for social subgraph APIs; rate limits + optional capability gate on `ChatHub.SendToAi` (gRPC path).

### H.4 Ongoing / documentation only

11. **A8** — Document global `HOST` vs face `FACE_HOST` semantics; align `DatabaseSeeder` comments and any controller usage.
12. **A9** — Decide and document JWT strategy (thin token + DB vs fat face claims) and **invalidation** when roles change (re-login vs cache TTL).
13. **A12** — Migration hygiene: verify legacy `UserRoles` rows vs `RoleScope`; data migration if invariants violated.
14. **A18** — Deprecate or harden `AuthController` vs OAuth2-only path; single supported auth story for SPAs.
15. **A13** — Optional DB-backed `RolePermissions` if product needs runtime-editable ACL.

### H.5 Part A items not listed above

- Any **Part A** row still marked `[ ]` or `[~]` stays in force until implemented or explicitly **cancelled** with a one-line rationale in **Part F**.

---

## Part I — Additional gaps & suggestions (post–Revision 6 review)

1. **Integration identities for agents** — document in this file or keep single source in **`docs/acl-and-capabilities.md`**: `IntegrationTestSeed` users (e.g. platform **ADMIN** vs **SUPER_ADMIN**) and how to obtain tokens in tests (`AclTestClients`, `GetSuperAdminAccessTokenAsync`).
2. **D.12 follow-through** — `PageTypes` mutations are gated; there is **no** `ComponentTypes` / `DisplayModes` controller in the current `Controllers` tree. When new platform-wide tables get REST mutators, apply the same **`CanMutateGlobalPageTypes`-class** bar (or a dedicated policy) and extend the gap table.
3. **B.11 / G14** — explicitly document the **face-prefixed hub URL** contract in **`docs/acl-and-capabilities.md`** or **SECURITY_CRYPTO_SOCKETS_DESIGN.md** once verified against `RoutingMiddleware` + client code.
4. **Slovak mirror** — optional `docs/acl-and-capabilities.sk.md` only if the team wants non-English operational docs; keep **ACL_ROLES_DESIGN.md** in English per header.
5. **Trim Part G later** — if the changelog noise outweighs value, replace the table with a one-line “pre–Revision 6 assumptions listed in git history” pointer.
