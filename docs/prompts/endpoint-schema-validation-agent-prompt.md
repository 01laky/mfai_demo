# Endpoint schema & input validation — `many_faces_backend` agent prompt

**Language:** English (identifiers and paths follow the repository).  
**Use:** Copy **§0** (master instructions) or the **whole document** into a new AI agent session. Documentation deliverables are **§17**; code comments are **§15**.

**Engagement name:** **Endpoint schema validation** (FluentValidation rollout for `BeDemo.Api`).  
**Scope:** `many_faces_backend/BeDemo.Api` only — REST controllers under `Controllers/`. SignalR hub message payloads are **out of scope** unless explicitly added in a follow-up.

**Related docs:**

| Doc | Purpose |
|-----|---------|
| [../guides/authentication-and-sessions.md](../guides/authentication-and-sessions.md) | OAuth2, JWT, password policy (Identity is source of truth for password **strength**) |
| [../guides/acl-and-capabilities.md](../guides/acl-and-capabilities.md) | Authorization stays in controllers/services — **not** in FluentValidation |
| [../guides/ai-assisted-content-approval.md](../guides/ai-assisted-content-approval.md) | Moderation enums and pipeline |
| [security-hardening-v2-agent-prompt.md](./security-hardening-v2-agent-prompt.md) | BE-U1 upload magic bytes — complements multipart validators |
| [super-admin-api.md](./super-admin-api.md) | Super-admin / global-operator HTTP surfaces |
| [../guides/api-request-validation.md](../guides/api-request-validation.md) | **To be created in P7 (§17.1)** — canonical guide for this engagement; link is the target path |
| [../guides/openapi-client-generation.md](../guides/openapi-client-generation.md) | FE clients; link validation error shape |
| [../guides/testing-and-ci-matrix.md](../guides/testing-and-ci-matrix.md) | CI rows for validator parity script + integration tests |

**Routing note:** Clients call `/{face-prefix}/api/...` for face-scoped APIs. Validators describe the **logical** path after `RoutingMiddleware` (`/api/...`). Face-prefix exempt routes: `/api/oauth2/*`, `/api/auth/*`, `/api/localization/*`, `/api/oauth2/jwks`, etc.

**Worksheet vs git:** `[ ]` lists are **templates** for PR/agent reports; do not mass-replace with `[x]` in git unless the team adopts this file as a living completion log ([prompts/README.md](./README.md)).

---

## 0. Master instructions (paste into agent chat)

You are implementing **centralized request validation** for `many_faces_backend` (`BeDemo.Api`) using **FluentValidation** (the .NET equivalent of Zod-style per-request schemas).

**Non-negotiable rules:**

1. **One FluentValidation class per request schema** (body DTO, query object, or multipart form model). Naming: `{RequestName}Validator` validating `{RequestName}`.
2. **Every schema listed in §11 with a named validator MUST appear in §12.1** and have `{RequestName}Validator` + `{RequestName}ValidatorTests` (§4). **No schema ships without tests.** Rows marked `—` (no body/query schema) or **route-only** do **not** require a validator or tests unless a shared route validator is introduced (§12.2 optional; document in PR).
3. **Remove duplicate inline validation** from controllers once the validator runs (keep authz, 404, domain rules).
4. **Do not** use validation to enforce ACL (`CanManageAllFaces`, `Forbid`) — only **input shape, bounds, and safe formats**.
5. **Password strength** for register/complete/admin-create-user: HTTP schema checks **presence + max length + no null bytes**; **minimum length/complexity** remains **ASP.NET Identity** (`IdentityPasswordPolicyOptions`, `UserManager`).
6. **Uniform 400 response:** `ValidationProblemDetails` via `AddFluentValidationAutoValidation()` unless an endpoint must keep OAuth2 error shape (`OAuth2TokenRequest` → custom filter or dual pipeline documented in PR).
7. **Relocate** request types from controller file bottoms into `BeDemo.Api/Models/Requests/**` (preserve JSON property names / camelCase).
8. After each phase, run `dotnet test many_faces_backend/BeDemo.Api.Tests` — all new validator tests must pass.
9. **Comment all validation code in English** — every validator, shared rule, filter, and non-obvious test must carry `///` or `//` explaining **why** the bound exists and **where** it is defined (EF, controller legacy, product rule). See §15.
10. **Ship documentation** — create or update the guides in §17; do not merge validation work without the guide and API reference subsection.

**Deliverables:** NuGet packages, `Program.cs` wiring, `Validation/Rules/*` shared extensions, `IFileValidator` (§7), **every §12.1 row** (validator + tests), **every §12 P0/P7** checkbox, controller cleanup, **§16** items done or `TRACK-VAL-*`, and **full documentation** per §17. Track progress in PR body by copying §12 checklists.

---

## 1. Objectives

1. Replace ad-hoc `if (string.IsNullOrWhiteSpace…)` / inconsistent `ModelState` usage with **testable schemas**.
2. Document **every HTTP endpoint** input contract (body, query, route, form).
3. Guarantee **edge-case unit test coverage per schema** (mandatory gate for merge).
4. Align with SHV2 **BE-U1** for uploads (validator + magic-byte service).
5. Leave **maintainable, commented** validation code and a **guide** so future contributors know what each rule means without reading the whole controller history.
6. Document the **HTTP 400 contract** for portal, admin, and mobile clients.

---

## 2. Technology choice

| Layer | Choice |
|-------|--------|
| Library | **FluentValidation 11.x** + ASP.NET Core integration package(s) for your target SDK |
| Registration | `AddFluentValidationAutoValidation()`, `AddValidatorsFromAssemblyContaining<Program>()` |
| Query binding | `[AsParameters]` records or `[FromQuery] QueryDto` + validator |
| Tests | `FluentValidation.TestHelper` (`TestValidate`, `ShouldHaveValidationErrorFor`) |

**P0 package check (required):** At implementation time, verify current NuGet IDs on [nuget.org](https://www.nuget.org) for **.NET 10** (e.g. `FluentValidation`, `FluentValidation.DependencyInjectionExtensions`, and whichever package exposes `AddFluentValidationAutoValidation()` — often still `FluentValidation.AspNetCore` but confirm before pinning versions).

**Not in scope:** JSON Schema files, source generators, client-side Zod generation (optional follow-up).

---

## 3. Project layout (target)

```text
BeDemo.Api/
  Models/Requests/           # input-only types (move from Controllers/)
    Auth/ OAuth/ Users/ …
  Validation/
    Rules/                   # SafeHttpUrlRule, PaginationRules, NoNullBytesRule, …
    Auth/
    OAuth/
    …                        # mirror Requests folders
BeDemo.Api.Tests/
  Validation/
    Auth/
    …                        # {RequestName}ValidatorTests.cs — REQUIRED per schema
```

---

## 4. Mandatory edge-case unit tests (every schema)

For **each** `{RequestName}Validator`, create `{RequestName}ValidatorTests` with **at least** these cases (skip only if logically N/A — document N/A in test name comment):

| ID | Case | Expect |
|----|------|--------|
| T1 | `default`/empty instance | Errors on all required members |
| T2 | Required string whitespace-only (`"   "`) | Error |
| T3 | Required string one below min length | Error |
| T4 | String one above max length | Error |
| T5 | Null byte `\0` in string fields (where applicable) | Error |
| T6 | Numeric below min / above max | Error |
| T7 | Enum/int out of defined range | Error |
| T8 | Collection empty when min count required | Error |
| T9 | Collection count max+1 | Error |
| T10 | Cross-field rule (e.g. `fromUtc > toUtc`, reject without reason) | Error |
| T11 | **Valid minimal** payload | **No** errors |
| T12 | **Valid maximal** payload (all optional fields populated within bounds) | **No** errors |

**OAuth2 token** and **registration** schemas: add grant-type conditional tests (password vs refresh_token).  
**Multipart/upload** schemas: T11 with mock `IFormFile` (length > 0, allowed content-type); T4 file over size limit.

**CI gate:** PR must not add a validator file without matching `*ValidatorTests.cs`. Code review checks **§12.1** row flipped to `[x]` for both validator and tests; §16.2 parity script enforces automatically.

---

## 5. Shared validation rules (`Validation/Rules/`)

Implement once, reuse in validators:

| Rule helper | Behavior |
|-------------|----------|
| `PaginationRules` | `page` ≥ 1; `pageSize` / `take` in 1–100; `skip` ≥ 0 |
| `SafeHttpUrlRule` | Absolute `http`/`https` only (wrap `ContentModerationHelpers.IsSafeHttpUrl`) |
| `NoNullBytesRule` | Reject `\0` in strings |
| `IdentityUserIdRule` | Non-empty, max length (~450), no whitespace |
| `EmailRule` | `EmailAddress` equivalent, max 256, trim |
| `OptionalTrimmedString` | Null OK; if present, trim; max length |
| `EnumDefinedRule<T>` | Enum binds or fails |
| `FaceIdRule` | `> 0` when required |
| `ConfidenceRangeRule` | `0.0`–`1.0` when present |
| `UtcRangeRule` | `from <= to`, max span (366 days for stats) |
| `PlatformPushRule` | `ios` or `android` lowercase (`POST /api/me/push-token`) |
| `RegistrationPlatformRule` | `mobile` or null/empty (`POST /api/oauth2/register/*`) — deep-link only |
| `ImageUrlListRule` | Max N URLs, each safe HTTP(S) |
| `SlugPathRule` | Page path: leading `/`, max length, no `..` |
| `GridSchemaJsonRule` | Optional: max byte length for `GridSchema` string |

---

## 6. Error response policy

| Surface | 400 shape |
|---------|-----------|
| Default API | `ValidationProblemDetails` (`errors` dictionary) |
| `POST /api/oauth2/token` | Keep `OAuth2ErrorResponse` with `invalid_request` / `invalid_grant` — implement `IValidator<OAuth2TokenRequest>` but map failures via filter or manual `Validate` in action |
| Deprecated `POST /api/oauth2/register` | Unchanged (always 400 deprecated) |

### 6.1 Client contract (portal / admin / mobile)

Document in §17 and [`api-request-validation.md`](../guides/api-request-validation.md):

| Topic | Normative choice |
|-------|------------------|
| Success path | Unchanged |
| New validation failures | `400` + `application/problem+json` or `application/json` with `ValidationProblemDetails` shape: top-level `title`, `status`, `errors` object keyed by **camelCase** property paths (`email`, `items[0].contentType`, …) |
| Legacy `{ error: "string" }` | Controllers may still return these for **domain** errors (404 message text, business rules). **Do not** mix legacy shape for pure input validation once FV is enabled on that action |
| OAuth2 | Never switch token endpoint to `ValidationProblemDetails` without explicit filter mapping to `OAuth2ErrorResponse` |
| FE handling | Portal/admin: map `errors[field]` to form field helpers; mobile: show first error or field map per screen — note in guide, no FE implementation required in this engagement unless user asks |

**Stable machine hints (recommended):** In validators use `.WithErrorCode("val_email_invalid")` (or similar `val_*` prefix) in addition to human-readable English messages so clients can branch without parsing prose. List codes in the guide appendix.

### 6.2 Error message policy

- Messages: **English**, short, user-safe (no stack traces, no internal ids).
- Property names in `errors`: match JSON serializer (**camelCase**).
- Do not localize server-side validation messages in this engagement (i18n stays on FE); optional `errorCode` is the hook for translated UI.

### 6.3 Conditional validation pattern (reference)

Use FluentValidation `When` for grant-type and moderation rules — keeps one validator per DTO:

```csharp
When(x => x.GrantType == "password", () =>
{
    RuleFor(x => x.Username).NotEmpty();
    RuleFor(x => x.Password).NotEmpty();
});
When(x => x.GrantType == "refresh_token", () =>
{
    RuleFor(x => x.RefreshToken).NotEmpty();
});
```

---

## 7. What stays in controllers (not validators)

- `[Authorize]` / `[AllowAnonymous]` / `Forbid()` / `CanManageAllFaces()`
- Entity existence → `NotFound`
- Duplicate like, friendship state, moderation state machine
- Face scope gates (`IFaceScopeContext`, `GateTenantFaceOrNotFound`)
- Identity `UserManager.CreateAsync` / `AddPasswordAsync` failures
- File **magic-byte** check (SHV2 BE-U1) — via **`IFileValidator`** (below), not duplicated in every controller

### 7.1 Upload validation — `IFileValidator` (required for uploads)

Implement a single service used by profile avatar and story image actions:

```text
BeDemo.Api/Validation/Files/IFileValidator.cs
BeDemo.Api/Validation/Files/FileValidator.cs   # or Services/ depending on DI style
```

| Step | Responsibility |
|------|----------------|
| FluentValidation on form model | File present, allowed extension/content-type, size ≤ limit |
| `IFileValidator.ValidateImageAsync(stream, fileName, ct)` | Magic-byte / format check (BE-U1); returns `(bool Ok, string? ErrorCode)` |
| Controller | Authz + call validator + `IFileValidator`; return `BadRequest` with agreed shape |

Unit-test `FileValidator` with small fixture bytes (PNG/JPEG magic); story/profile controllers get at least one integration test returning 400 on fake extension.

### 7.2 `DataAnnotations` migration

- Request DTOs: **remove** `[Required]`, `[MaxLength]`, etc. after FluentValidation covers the same rules (avoids double validation).
- Response DTOs: **no** FluentValidation.
- First cleanup targets: `RegistrationInviteDtos.cs`, `RegisterPushTokenRequestDto.cs`, `CreateUserModel`, face/page models that already use annotations.

---

## 8. Implementation phases

| Phase | Content |
|-------|---------|
| **P0** | Packages, `Program.cs`, `Validation/Rules`, error policy, sample `PaginationQuery` + tests |
| **P1** | Auth + OAuth + registration + admin invites (§11.1–11.5) |
| **P2** | Users, profile, me/push-token (§11.6–11.8) |
| **P3** | UGC: reels, blogs, albums, stories + nested comments (§11.23–11.30) |
| **P4** | Faces, pages, CMS, face-scoped social (§11.9–11.17, §11.12–11.13) |
| **P5** | Moderation, stats, admin tools (§11.18–11.21) |
| **P6** | Social graph: friends, blocks, follows, messages, notifications (§11.31–11.33) |
| **P7** | Remove dead inline checks; full `dotnet test`; **§17 documentation**; §16 CI + integration tests; comment pass on all new validation code |

---

## 9. Endpoint inventory conventions

Columns:

- **Schema** — request type to create (or `—` if no body/query schema; route-only)
- **Validator** — FluentValidation class name
- **Validation rules** — normative bounds to encode
- **Edge tests** — minimum extra cases beyond §4

Optional column when relevant in PR notes: **Behavior change** — validator is stricter than current controller (e.g. messages `limit` clamp). Call out so FE/manual QA can verify.

Face-scoped routes omit `/{face}` prefix in tables.

**Bounds source of truth:** Prefer `ApplicationDbContext` fluent `HasMaxLength` over ad-hoc controller checks. Where the controller is stricter today, the validator should match **EF** (and fix controller drift). Where the app adds a cap (e.g. blog `Content` is PostgreSQL `text`), document the chosen cap in the validator with a comment referencing EF.

**Current type names:** Tables use **target** request names after refactor. Today many types still live at the bottom of controller files (e.g. `RegisterModel`, `CreateReelDto`) — rename on move to `Models/Requests/`.

---

## 10. Code-grounded audit (2026-05-16)

Verified against `BeDemo.Api/Controllers` (**44** files, **178** `[Http*]` actions) and `ApplicationDbContext`.

| Finding | Resolution in this prompt |
|---------|---------------------------|
| Missing §10 (jump 9→11) | Added this section |
| Phase §8 pointed at wrong §11 ranges | Fixed in §8 |
| `RegisterRequestValidator` used for both cookie register and `RegisterRequestDto` | Signup DTO → `RegisterSignupRequestValidator` (§11.3) |
| `POST /api/oauth2/register` (deprecated) ignores body | **No validator/tests** (§11.2) |
| Registration `hash` max 200 in prompt | **128** per `RegistrationInvite.LinkHash` |
| Registration `code` length 4–12 | **`RegistrationInviteOptions.CodeLength`** (default **6**) |
| Face profile list `pageSize` 1–50 | **1–100** per controller clamp |
| UGC comment `max 4000` | **2000** for album/blog/reel/story comments (EF); **4000** for face-profile comments only |
| Reel `description` max 4000 | **2000** (EF); `videoUrl` max **1000** |
| Story upload `description` max 500 | **2000** (EF `StoryImage.Description`) |
| Blog `title` | **Required** on create (controller) |
| Moderation **approve** | **Reason required** when overriding `AiReviewStatus.RecommendedReject` |
| `GET /api/search/health` | **`[AllowAnonymous]`** + public face prefix (like Stats/public) |
| Messages/notifications `limit` | Controllers default **50** with **no clamp** today — validators should enforce **1–200** / **1–100** (behavior improvement) |
| §12.1 schema count | Prompt claimed **77** rows; actual §12.1 checklist count is **76** (P4 = 20, not 21) — fixed in §12.3/§12.4/§19 |
| Avatar error message | `ProfileController` returns **“Max 5 MB”** while limit is **30 MB** — align in validator rollout (**BE-U2**) |
| `POST` reel comment | Optional query **`faceId`** — add query schema |
| Route casing | `[controller]` routes are PascalCase in code (`ContentModeration`, `Stats`); URLs are case-insensitive |

---

## 11. Full endpoint catalog

### 11.1 AuthController — `api/auth`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/auth/register` | `RegisterRequest` *(today: `RegisterModel`)* | `RegisterRequestValidator` | Email required, valid, max 256; password required, max 128, no `\0` (min length/complexity via **Identity**, not FV — see §0.5); first/last name optional max 100; trim. **Today:** `RegisterModel` has no DataAnnotations — FV is the first structured gate. | Valid register; invalid email; password empty; null byte in email |
| POST | `/api/auth/login` | `LoginRequest` *(today: `LoginModel`)* | `LoginRequestValidator` | Email required valid; password required not empty; rememberMe bool | Empty password; invalid email |
| POST | `/api/auth/logout` | — | — | No input schema | — |

### 11.2 OAuth2Controller — `api/oauth2`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/oauth2/token` | `OAuth2TokenRequest` | `OAuth2TokenRequestValidator` | `grantType` required, whitelist `password` \| `refresh_token`; password grant: username+password required, no `\0`; refresh grant: refreshToken required; clientId/secret max lengths; rememberMe optional bool; signature fields optional max length | Each grant type valid/invalid; missing username on password grant; null byte; empty grantType |
| POST | `/api/oauth2/register` | — *(body ignored)* | — | **Deprecated** — always `400 registration_flow_deprecated`; do **not** add validator/tests | — |

### 11.3 OAuth2RegistrationController + AdminRegistrationInvites — registration

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/oauth2/register/request` | `RegisterRequestDto` | `RegisterSignupRequestValidator` | Email required valid; first/last optional max 100; locale optional max 20; platform optional — if set must be `mobile` (`RegistrationPlatformRule`); no `\0` in email | platform `ios` invalid |
| POST | `/api/oauth2/register/resend` | `RegisterResendDto` | `RegisterResendDtoValidator` | Email required valid; locale/platform optional (same as request) | — |
| GET | `/api/oauth2/register/prefill` | `RegisterPrefillQuery` | `RegisterPrefillQueryValidator` | `hash` required, non-whitespace, max **128**, no `\0` | missing hash; whitespace hash |
| POST | `/api/oauth2/register/complete` | `RegisterCompleteDto` | `RegisterCompleteDtoValidator` | hash required max **128**; code required length = `RegistrationInviteOptions.CodeLength` (default **6**, configurable); password required max 128 no `\0` (min **12** enforced by **Identity** after BE-A3 — add integration test for 11-char password → 400, not FV T3); clientId/secret optional max 200; rememberMe optional | wrong code length; null byte in hash; password below Identity minimum (integration) |
| GET | `/api/admin/registration-invites` | `AdminInviteListQuery` | `AdminInviteListQueryValidator` | skip ≥ 0; take 1–100 | take=0; take=101 |
| POST | `/api/admin/registration-invites` | `AdminCreateRegistrationInviteDto` | `AdminCreateRegistrationInviteValidator` | email required valid; names optional max 100 | — |
| POST | `/api/admin/registration-invites/{id}/revoke` | — | `GuidRouteValidator` optional | `id` non-empty guid | empty guid |

### 11.4 OAuthJwksController — `api/oauth2`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/oauth2/jwks` | — | — | No inputs | — |

### 11.5 LocalizationController — `api/localization` (face exempt)

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/localization/{app}` | `LocalizationBundleQuery` | `LocalizationBundleQueryValidator` | route `app` parsed via `LocalizationAppParser` (portal\|admin\|mobile); query `v` optional max 64 alphanumeric/hash | unknown app → 404 (controller); `v` too long |

### 11.6 UsersController — `api/users`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/users` | `GetUsersQuery` | `GetUsersQueryValidator` | page ≥ 1; pageSize 1–100; search optional max 200; forAddFriend bool | page=0; pageSize=101 |
| GET | `/api/users/{id}` | — | `IdentityUserIdRouteValidator` | `id` non-empty user id | empty id |
| POST | `/api/users` | `CreateUserRequest` | `CreateUserRequestValidator` | email required; password min 12 **for operator create** (configurable via `IdentityPasswordPolicyOptions`); names optional max 100 | password 11 chars |
| PUT | `/api/users/{id}` | `UpdateUserRequest` | `UpdateUserRequestValidator` | email optional valid; password optional min 12 if provided; names optional | password empty string vs omit |

### 11.7 MeController + MePushTokenController — `api/me`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/me/capabilities` | — | — | No inputs (face scope from middleware) | — |
| POST | `/api/me/push-token` | `RegisterPushTokenRequestDto` | `RegisterPushTokenRequestValidator` | token required length 10–512; platform `ios`\|`android`; installationId optional max 200 | token 9 chars; platform `windows` |
| DELETE | `/api/me/push-token` | `DeletePushTokenQuery` | `DeletePushTokenQueryValidator` | installationId optional max 200 | — |

### 11.8 ProfileController — `api/profile`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/profile/me` | `ProfileMeQuery` | `ProfileMeQueryValidator` | faceId optional > 0 if present | faceId=0 |
| PUT | `/api/profile/me` | `UpdateProfileRequest` | `UpdateProfileRequestValidator` | first/last optional max 100; at least one field present | both null |
| POST | `/api/profile/me/avatar` | `AvatarUploadRequest` | `AvatarUploadRequestValidator` | file required; extension in `.jpg,.jpeg,.png,.gif,.webp`; size ≤ **30 MB** (`ProfileController.MaxFileSizeBytes` — fix legacy **“Max 5 MB”** user message in controller when touching uploads, SHV2 **BE-U2**); BE-U1 magic bytes via `IFileValidator` in handler | no file; `.exe` extension; oversize file |
| POST | `/api/profile/me/faces/{faceId}/avatar` | `FaceAvatarUploadRequest` | `FaceAvatarUploadRequestValidator` | faceId > 0 + same file rules as avatar (30 MB + BE-U2 message alignment) | faceId invalid |

### 11.9 FacesController — `api/faces`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/faces` | — | — | — | — |
| GET | `/api/faces/config` | — | — | — | — |
| GET | `/api/faces/face-roles` | — | — | — | — |
| PUT | `/api/faces/{id}/my-role` | `SetMyFaceRoleRequest` | `SetMyFaceRoleRequestValidator` | userRoleId > 0 | userRoleId=0 |
| POST | `/api/faces/{id}/visit` | — | `FaceIdRouteValidator` | id > 0 | id=0 |
| POST | `/api/faces/{id}/exit-face` | — | `FaceIdRouteValidator` | id > 0 | — |
| GET | `/api/faces/{id}` | — | `FaceIdRouteValidator` | id > 0 | — |
| POST | `/api/faces` | `CreateFaceRequest` | `CreateFaceRequestValidator` | index required max 100 kebab-safe; title required max 200; description max 1000; gradientSettings max 4000 JSON string; booleans; visibility enum if set | index empty; title 201 chars |
| PUT | `/api/faces/{id}` | `UpdateFaceRequest` | `UpdateFaceRequestValidator` | all optional with same max as create; at least one field | empty body |
| DELETE | `/api/faces/{id}` | — | `FaceIdRouteValidator` | id > 0 | — |

### 11.10 FaceProfilesController — `api/faces/{faceId}/profiles`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `.../profiles` | `FaceProfileListQuery` | `FaceProfileListQueryValidator` | page ≥ 1; pageSize 1–**100** (controller clamps) | pageSize=101 |
| GET | `.../profiles/{userId}` | — | `FaceIdRouteValidator` + `IdentityUserIdRouteValidator` | | |
| POST | `.../profiles/{userId}/like` | — | route only | | |
| DELETE | `.../profiles/{userId}/like` | — | route only | | |
| GET | `.../profiles/{userId}/likes` | — | route only | | |
| GET | `.../profiles/{userId}/comments` | — | route only | | |
| POST | `.../profiles/{userId}/comments` | `FaceProfileCommentRequest` | `FaceProfileCommentRequestValidator` | body required max 4000 trim | empty body; 4001 chars |
| DELETE | `/api/faces/{faceId}/profiles/comments/{commentId}` | — | route | commentId > 0 | |
| GET | `.../profiles/{userId}/reviews` | — | route only | | |
| POST | `.../profiles/{userId}/reviews` | `FaceProfileReviewRequest` | `FaceProfileReviewRequestValidator` | title required max 200; text required max 8000; stars optional 1–6 | stars=0; stars=7 |
| DELETE | `/api/faces/{faceId}/profiles/reviews/{reviewId}` | — | route | reviewId > 0 | |

### 11.11 FaceChatRoomsController — `api/faces/{faceId}/chat-rooms`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `.../chat-rooms` | — | `FaceIdRouteValidator` | | |
| GET | `.../chat-rooms/{roomId}` | — | faceId, roomId > 0 | | |
| POST | `.../chat-rooms` | `CreateFaceChatRoomRequest` | `CreateFaceChatRoomRequestValidator` | title required max 200; description optional max 2000; isPublic bool | empty title |
| POST | `.../chat-rooms/system` | `CreateSystemFaceChatRoomRequest` | `CreateSystemFaceChatRoomRequestValidator` | title required max 200; description optional max 2000 | — |
| PUT | `.../chat-rooms/{roomId}` | `UpdateFaceChatRoomRequest` | `UpdateFaceChatRoomRequestValidator` | title/description optional with max; at least one field | — |
| DELETE | `.../chat-rooms/{roomId}` | — | route | | |
| POST | `.../chat-rooms/{roomId}/join` | — | route | | |
| POST | `.../chat-rooms/{roomId}/join-requests` | — | route | | |
| POST | `.../chat-rooms/requests/{requestId}/approve` | — | requestId > 0 | | |
| POST | `.../chat-rooms/requests/{requestId}/deny` | — | requestId > 0 | | |
| GET | `.../chat-rooms/{roomId}/messages` | `ChatMessagesQuery` | `ChatMessagesQueryValidator` | pageSize 1–100; beforeId optional > 0 | pageSize=0 |

### 11.12 FaceWallTicketsController — `api/faces/{faceId}/wall-tickets`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `.../wall-tickets` | `WallTicketListQuery` | `WallTicketListQueryValidator` | page ≥ 1; pageSize 1–100 | — |
| GET | `.../wall-tickets/{ticketId}` | — | route ids > 0 | | |
| POST | `.../wall-tickets` | `WallTicketWriteRequest` | `WallTicketWriteRequestValidator` | title required max 200; description required max 8000 | title empty; description 8001 |
| PUT | `.../wall-tickets/{ticketId}` | `WallTicketWriteRequest` | same | same (controller checks frozen status) | — |
| DELETE | `.../wall-tickets/{ticketId}` | — | route | | |
| POST | `.../wall-tickets/{ticketId}/like` | — | route | | |
| DELETE | `.../wall-tickets/{ticketId}/like` | — | route | | |
| GET | `.../wall-tickets/{ticketId}/comments` | — | route | | |
| POST | `.../wall-tickets/{ticketId}/comments` | `WallTicketCommentRequest` | `WallTicketCommentRequestValidator` | content required max 255 | empty; 256 chars |

### 11.13 AdminFaceWallTicketsController — `api/admin/faces/{faceId}/wall-tickets`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `.../wall-tickets` | `WallTicketListQuery` | reuse | same as 11.12 | — |
| GET | `.../wall-tickets/{ticketId}` | — | route | | |
| POST | `.../wall-tickets/{ticketId}/approve` | — | route | | |
| POST | `.../wall-tickets/{ticketId}/deny` | — | route | | |
| DELETE | `.../wall-tickets/{ticketId}` | — | route | | |
| DELETE | `.../wall-tickets/{ticketId}/comments/{commentId}` | — | route | | |

### 11.14 PagesController — `api/pages`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/pages` | `GetPagesQuery` | `GetPagesQueryValidator` | faceId optional > 0 | faceId=0 |
| GET | `/api/pages/{id}` | — | id > 0 | | |
| POST | `/api/pages` | `CreatePageRequest` | `CreatePageRequestValidator` | faceId>0; pageTypeId>0; name required max 200; path required max 500 slug rule; index ≥ 0; description max 1000 | path without leading `/` |
| PUT | `/api/pages/{id}` | `UpdatePageRequest` | `UpdatePageRequestValidator` | optional fields with bounds; gridSchema max 100_000 chars | gridSchema too large |
| DELETE | `/api/pages/{id}` | — | route | | |
| GET | `/api/pages/{pageId}/translations` | — | pageId > 0 | | |
| PUT | `/api/pages/{pageId}/translations` | `UpsertPageTranslationsRequest` | `UpsertPageTranslationsRequestValidator` | list non-empty max 50; each languageCode required max 10; translatedRoute required max 200 | empty list; duplicate language |

### 11.15 PageTypesController — `api/pagetypes`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/pagetypes` | — | — | | |
| GET | `/api/pagetypes/{id}` | — | id > 0 | | |
| POST | `/api/pagetypes` | `CreatePageTypeRequest` | `CreatePageTypeRequestValidator` | index required max 50 (slug) | — |
| PUT | `/api/pagetypes/{id}` | `UpdatePageTypeRequest` | `UpdatePageTypeRequestValidator` | index optional max 50 | — |
| DELETE | `/api/pagetypes/{id}` | — | route | | |

### 11.16 PageComponentsController — `api/pagecomponents`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/pagecomponents/page/{pageId}` | — | pageId > 0 | | |
| GET | `/api/pagecomponents/{id}` | — | id > 0 | | |
| POST | `/api/pagecomponents` | `CreatePageComponentRequest` | `CreatePageComponentRequestValidator` | pageId, componentTypeId, displayModeId > 0; grid x,y,w,h ≥ 0; minW/minH ≥ 0; label/title/icon max lengths | negative w |
| PUT | `/api/pagecomponents/{id}` | `UpdatePageComponentRequest` | `UpdatePageComponentRequestValidator` | optional bounds | — |
| DELETE | `/api/pagecomponents/{id}` | — | route | | |

### 11.17 ComponentTypesController + DisplayModesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/componenttypes` | — | — | | |
| GET | `/api/componenttypes/{id}` | — | id > 0 | | |
| GET | `/api/displaymodes` | — | — | | |
| GET | `/api/displaymodes/{id}` | — | id > 0 | | |

### 11.18 StatsController — `api/Stats`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/Stats` | — | — | authz only | — |
| GET | `/api/Stats/public` | — | — | anonymous | — |
| GET | `/api/Stats/timeseries` | `StatsTimeseriesQuery` | `StatsTimeseriesQueryValidator` | metric required whitelist; fromUtc/toUtc required, from≤to, span ≤366d; bucket `day`\|`week` | unknown metric; from>to; 367-day span |

### 11.19 SearchController — `api/search`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/search/health` | — | — | **`[AllowAnonymous]`** — call via **public** face prefix (same pattern as `GET /api/Stats/public`) | — |

### 11.20 AdminMailerTestController + AdminPushTestController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/admin/mailer/test-self` | — | — | no body; authz | — |
| GET | `/api/admin/mailer/pilot-link` | — | — | AllowAnonymous | — |
| POST | `/api/admin/push/test-self` | — | — | no body; authz | — |

### 11.21 ContentModerationController — `api/ContentModeration` *(case-insensitive)*

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/contentmoderation` | `GetModerationQueueQuery` | `GetModerationQueueQueryValidator` | optional enums valid; faceId>0 if set; authorId/reviewerId identity rule; flagContains max 200; confidence 0–1, min≤max; date range valid; minQueueAgeHours ≥ 0 | minConfidence>maxConfidence |
| GET | `/api/contentmoderation/{contentType}/{contentId}/events` | — | enum route + contentId>0 | | |
| GET | `/api/contentmoderation/metrics` | — | — | | |
| POST | `/api/contentmoderation/bulk` | `BulkModerationRequest` | `BulkModerationRequestValidator` | action enum; items count 1–100; distinct pairs; reason required when reject/remove; reason/userMessage max 2000 | 0 items; 101 items; reject without reason |
| POST | `.../approve` | `ModerationDecisionRequest` *(today: `ModerationDecisionDto`)* | `ModerationDecisionRequestValidator` | reason/userMessage optional max **2000**; **reason required** when content has `AiReviewStatus.RecommendedReject` (override approve) | approve AI-recommended-reject without reason |
| POST | `.../reject` | `ModerationDecisionRequest` | same | reason required non-whitespace | missing reason |
| POST | `.../remove` | `ModerationDecisionRequest` | same | reason required | — |

### 11.22 MyContentSubmissionsController — `api/my/content-submissions`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/my/content-submissions` | — | — | | |

### 11.23 ReelsController — `api/reels`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/reels` | `ReelListQuery` | `ReelListQueryValidator` | faceId optional > 0 | — |
| GET | `/api/reels/{id}` | `ReelDetailQuery` | `ReelDetailQueryValidator` | id>0; faceId optional > 0 | — |
| GET | `/api/reels/user/{userId}` | `ReelByUserQuery` | `ReelByUserQueryValidator` | userId required; faceId optional | — |
| POST | `/api/reels` | `CreateReelRequest` | `CreateReelRequestValidator` | title required max 200; videoUrl required safe http(s) max **1000**; description optional max **2000**; faceIds each >0 max 20 | unsafe url; videoUrl 1001 chars |
| PUT | `/api/reels/{id}` | `UpdateReelRequest` | `UpdateReelRequestValidator` | optional fields with bounds | — |
| DELETE | `/api/reels/{id}` | — | id > 0 | | |

### 11.24 ReelCommentsController + ReelLikesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/reels/{reelId}/comments` | — | reelId > 0 | | |
| POST | `.../comments` | `CreateReelCommentRequest` + `ReelCommentCreateQuery` | `CreateReelCommentRequestValidator`, `ReelCommentCreateQueryValidator` | body: content required max **2000**; query: `faceId` optional, if present > 0 | empty content |
| PUT | `.../comments/{id}` | `UpdateReelCommentRequest` | `UpdateReelCommentRequestValidator` | content required max **2000** | — |
| DELETE | `.../comments/{id}` | — | route | | |
| GET | `.../likes` | — | route | | |
| POST | `.../likes` | — | — | no body | — |
| DELETE | `.../likes` | — | — | | |

### 11.25 BlogsController — `api/blogs`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/blogs` | `BlogListQuery` | `BlogListQueryValidator` | faceId optional > 0 | — |
| GET | `/api/blogs/{id}` | — | id > 0 | | |
| POST | `/api/blogs` | `CreateBlogRequest` | `CreateBlogRequestValidator` | **title required** max 200; content required (EF `text` — app cap e.g. **100_000**); faceId > 0; imageUrls max 3 each safe url max **500** | missing title; 4 image urls |
| PUT | `/api/blogs/{id}` | `UpdateBlogRequest` | `UpdateBlogRequestValidator` | optional with bounds | — |
| DELETE | `/api/blogs/{id}` | — | route | | |

### 11.26 BlogCommentsController + BlogLikesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/blogs/{blogId}/comments` | — | blogId > 0 | | |
| POST | `.../comments` | `CreateBlogCommentRequest` | `CreateBlogCommentRequestValidator` | content required max **2000** | — |
| PUT | `.../comments/{id}` | `UpdateBlogCommentRequest` | same | — | |
| DELETE | `.../comments/{id}` | — | route | | |
| GET/POST/DELETE | `.../likes` | — | POST no body | — | — |

### 11.27 AlbumsController — `api/albums`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/albums` | `AlbumListQuery` | `AlbumListQueryValidator` | faceId optional > 0 | — |
| GET | `/api/albums/{id}` | — | id > 0 | | |
| GET | `/api/albums/user/{userId}` | `AlbumByUserQuery` | `AlbumByUserQueryValidator` | userId required | — |
| POST | `/api/albums` | `CreateAlbumRequest` | `CreateAlbumRequestValidator` | title required max 200; description max 4000; albumType/mediaType enum defined; faceIds optional each >0 max 20 | invalid enum |
| PUT | `/api/albums/{id}` | `UpdateAlbumRequest` | `UpdateAlbumRequestValidator` | optional bounds | — |
| DELETE | `/api/albums/{id}` | — | route | | |

### 11.28 AlbumCommentsController + AlbumLikesController

Same pattern as §11.26 (`CreateAlbumCommentRequest`, content max **2000** per EF).

### 11.29 StoriesController — `api/stories`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/stories` | `StoryListQuery` | `StoryListQueryValidator` | **`faceId` required** (`int`, must be > 0 after scope resolve) | faceId=0 |
| GET | `/api/stories/me` | `StoryMineQuery` | `StoryMineQueryValidator` | `faceId` optional; if present > 0 | — |
| GET | `/api/stories/{id}` | `StoryDetailQuery` | `StoryDetailQueryValidator` | id>0; **faceId required** > 0 | faceId missing |
| POST | `/api/stories` | `CreateStoryRequest` | `CreateStoryRequestValidator` | title required max 200; faceIds optional each >0 max 20 | — |
| POST | `/api/stories/{id}/publish` | `PublishStoryRequest` | `PublishStoryRequestValidator` | scheduledPublishAt optional, must be UTC future if set | past date |
| DELETE | `/api/stories/{id}` | — | route | | |
| POST | `/api/stories/{id}/view` | `StoryViewQuery` | `StoryViewQueryValidator` | faceId > 0 | — |
| POST | `/api/stories/{id}/images` | `StoryImageUploadForm` | `StoryImageUploadFormValidator` | file required image/*; size ≤ 52MB (`RequestSizeLimit`); sortOrder 0–9; description optional max **2000**; BE-U1 | sortOrder=10; non-image |

### 11.30 StoryCommentsController + StoryLikesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `.../comments` | `StoryScopedQuery` | faceId > 0 | | |
| POST | `.../comments` | `CreateStoryCommentRequest` + `StoryScopedQuery` | `CreateStoryCommentRequestValidator`, `StoryScopedQueryValidator` | content required max **2000**; query `faceId` > 0 | empty content |
| GET/POST/DELETE | `.../likes` | `StoryScopedQuery` | faceId > 0 | | |

### 11.31 MessagesController — `api/messages`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/messages/conversations` | — | — | | |
| GET | `/api/messages/requests` | — | — | | |
| GET | `/api/messages/with/{otherUserId}` | `MessageHistoryQuery` | `MessageHistoryQueryValidator` | route `otherUserId` required; `limit` 1–**200** (default 50 today — **add clamp** in validator) | limit=0; limit=201 |
| POST | `/api/messages/with/{otherUserId}/read` | — | otherUserId route | | |

### 11.32 FriendsController + FriendRequestsController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/friends` | — | — | | |
| GET | `/api/friendrequests` | — | — | | |
| POST | `/api/friendrequests` | `SendFriendRequestRequest` | `SendFriendRequestRequestValidator` | receiverId required, not equal to self (requires user id in validator via context or check in controller after valid shape) | empty receiverId |
| POST | `/api/friendrequests/{id}/accept` | — | id > 0 | | |
| POST | `/api/friendrequests/{id}/reject` | — | id > 0 | | |

### 11.33 UserBlocksController + UserFollowsController + NotificationsController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/userblocks` | — | — | | |
| GET | `/api/userblocks/status/{userId}` | — | userId route | | |
| POST | `/api/userblocks` | `BlockUserRequest` | `BlockUserRequestValidator` | blockedId required, not self | self-block id |
| DELETE | `/api/userblocks/{userId}` | — | route | | |
| GET | `/api/userfollows/following` | — | — | | |
| GET | `/api/userfollows/followers` | — | — | | |
| GET | `/api/userfollows/status/{userId}` | — | route | | |
| POST | `/api/userfollows` | `FollowUserRequest` | `FollowUserRequestValidator` | followedId required | empty |
| DELETE | `/api/userfollows/{userId}` | — | route | | |
| GET | `/api/notifications` | `NotificationsListQuery` | `NotificationsListQueryValidator` | `limit` 1–**100** (default 50 today — **add clamp**) | limit=0; limit=101 |

---

## 12. Validator & test registry (master checklist)

**Rule:** For each `[ ]` below, mark `[x]` only when **both** the implementation **and** `{Name}ValidatorTests` exist with §4 satisfied (T1–T12 or documented N/A).

**Cross-reference:** Normative bounds per endpoint → **§11**. EF limits → **§18**.

**Phase gate:** Do not mark **P*n* complete** until **every** `[ ]` in that phase (including §12.1 rows tagged P*n*) is `[x]` or `TRACK-VAL-*` in the report.

**Execution order (normative):** **P0** → **P1** → **P2** → **P3** → **P4** → **P5** → **P6** → **P7** (matches §8). §12.1 groups P4 before P3 for readability only — still implement in phase order.

**Progress:** Copy §12 + §12.1 into the PR description; tick there. See **§12.4** for per-phase counts and §11 parity.

---

### P0 — Infrastructure (complete before P1)

#### Packages & host wiring

- [ ] `FluentValidation` + `FluentValidation.AspNetCore` (or current .NET 10–recommended package) in `BeDemo.Api.csproj`
- [ ] `FluentValidation.TestHelper` in `BeDemo.Api.Tests.csproj`
- [ ] `Program.cs`: `AddFluentValidationAutoValidation()`, `AddValidatorsFromAssemblyContaining<Program>()`
- [ ] `Models/Requests/` folder tree created (mirror §3)
- [ ] `Validation/` folder tree created (`Rules/`, `Auth/`, …, `Files/`)
- [ ] `BeDemo.Api.Tests/Validation/` folder tree created

#### OAuth2 error mapping (required)

- [ ] Implement OAuth2 validation filter or action filter: FV failures on `OAuth2TokenRequest` → `OAuth2ErrorResponse` (not `ValidationProblemDetails`)
- [ ] Document mapping in guide §17 + PR; unit/integration test: missing `grantType` → OAuth2 error JSON

#### Shared rules (`Validation/Rules/`) — each with `*Tests.cs`

- [ ] `PaginationRules` + tests
- [ ] `SafeHttpUrlRule` + tests
- [ ] `NoNullBytesRule` + tests
- [ ] `EmailRule` + tests
- [ ] `IdentityUserIdRule` + tests
- [ ] `OptionalTrimmedString` extensions + tests
- [ ] `EnumDefinedRule` + tests
- [ ] `FaceIdRule` + tests
- [ ] `ConfidenceRangeRule` + tests
- [ ] `UtcRangeRule` + tests
- [ ] `PlatformPushRule` + tests
- [ ] `RegistrationPlatformRule` + tests
- [ ] `ImageUrlListRule` + tests
- [ ] `SlugPathRule` + tests
- [ ] `GridSchemaJsonRule` + tests

#### Sample + uploads infrastructure

- [ ] `PaginationQuery` + `PaginationQueryValidator` + tests (P0 reference implementation)
- [ ] `IFileValidator` + `FileValidator` + `FileValidatorTests` (magic bytes BE-U1, §7.1)
- [ ] Register `IFileValidator` in DI (`Program.cs`)

---

### P1 — Auth & OAuth (§11.1–11.5)

*Detail rows: §12.1 — P1 block.*

- [ ] **P1 phase complete** (all §12.1 P1 rows `[x]` or tracked)

---

### P2 — Users & profile (§11.6–11.8)

*Detail rows: §12.1 — P2 block.*

- [ ] **P2 phase complete**

---

### P3 — UGC (§11.23–11.30)

*Detail rows: §12.1 — P3 block.*

- [ ] **P3 phase complete**

---

### P4 — Faces & CMS (§11.9–11.17, §11.12–11.13)

*Detail rows: §12.1 — P4 block.*

- [ ] **P4 phase complete**

---

### P5 — Moderation & admin stats (§11.18–11.21)

*Detail rows: §12.1 — P5 block.*

- [ ] **P5 phase complete**

---

### P6 — Social (§11.31–11.33)

*Detail rows: §12.1 — P6 block.*

- [ ] **P6 phase complete**

---

### P7 — Cleanup, docs, cross-cutting

#### Controller & DTO hygiene

- [ ] Inline input-validation `BadRequest` / redundant `ModelState` removed from all §12.1-covered actions
- [ ] Request DTOs moved from controller file bottoms → `Models/Requests/**` (preserve JSON names)
- [ ] Remove `[Required]` / `[MaxLength]` from request DTOs where FV replaced them (§7.2):
  - [ ] `RegistrationInviteDtos.cs`
  - [ ] `RegisterPushTokenRequestDto.cs`
  - [ ] `CreateUserModel` / `UpdateUserModel` (after rename to `*Request`)
  - [ ] `CreateFaceModel` / `UpdateFaceModel` / page models with annotations
  - [ ] `FaceProfileCommentDto` / `FaceProfileReviewDto` attributes
- [ ] `.WithErrorCode("val_*")` on non-trivial rules; catalog written in guide §17.1

#### Tests & CI

- [ ] `dotnet test` full `BeDemo.Api.Tests` green (including `Testing` environment per §16.5)
- [ ] §16.2 CI parity script added and documented
- [ ] §16.3 integration tests (3 cases) green
- [ ] §16.4 Swagger FV — done or `TRACK-VAL-swagger`

#### Documentation (§17) — each file

- [ ] **§17.1** Create/update [`docs/guides/api-request-validation.md`](../guides/api-request-validation.md) (all 8 sections)
- [ ] **§17.1** `errorCode` catalog (`val_*`) in guide
- [ ] **§17.1** Mermaid diagram (optional — `[x]` if skipped with reason)
- [ ] [`many_faces_backend/docs/reference/01-features-running-and-api.md`](../../many_faces_backend/docs/reference/01-features-running-and-api.md) — **Request validation** subsection
- [ ] [`docs/guides/authentication-and-sessions.md`](../guides/authentication-and-sessions.md) — OAuth FV note
- [ ] [`docs/guides/openapi-client-generation.md`](../guides/openapi-client-generation.md) — validation errors paragraph
- [ ] [`docs/guides/testing-and-ci-matrix.md`](../guides/testing-and-ci-matrix.md) — parity script + test filter rows
- [ ] [`docs/prompts/README.md`](./README.md) — row for this prompt

#### §16 remainder

- [ ] §16.1 EF appendix §18 reviewed/updated if EF changed
- [ ] §16.5 Testing-environment test fixes

#### Quality gate

- [ ] Comment pass §15 on all validators, rules, `IFileValidator`, OAuth filter
- [ ] **P7 phase complete**

---

### 12.1 Full per-schema checklist (validator + tests)

Format: `[ ] \`RequestType\` → \`RequestTypeValidator\` + \`RequestTypeValidatorTests\` (§11.x)`

#### P1 — Auth & OAuth

- [ ] `RegisterRequest` → `RegisterRequestValidator` (§11.1)
- [ ] `LoginRequest` → `LoginRequestValidator` (§11.1)
- [ ] `OAuth2TokenRequest` → `OAuth2TokenRequestValidator` (§11.2)
- [ ] `RegisterRequestDto` → `RegisterSignupRequestValidator` (§11.3)
- [ ] `RegisterResendDto` → `RegisterResendDtoValidator` (§11.3)
- [ ] `RegisterPrefillQuery` → `RegisterPrefillQueryValidator` (§11.3)
- [ ] `RegisterCompleteDto` → `RegisterCompleteDtoValidator` (§11.3)
- [ ] `AdminInviteListQuery` → `AdminInviteListQueryValidator` (§11.3)
- [ ] `AdminCreateRegistrationInviteDto` → `AdminCreateRegistrationInviteValidator` (§11.3)
- [ ] `LocalizationBundleQuery` → `LocalizationBundleQueryValidator` (§11.5)

*Skipped by design:* `POST /api/oauth2/register` (deprecated, body ignored).

#### P2 — Users, me, profile

- [ ] `GetUsersQuery` → `GetUsersQueryValidator` (§11.6)
- [ ] `CreateUserRequest` → `CreateUserRequestValidator` (§11.6)
- [ ] `UpdateUserRequest` → `UpdateUserRequestValidator` (§11.6)
- [ ] `RegisterPushTokenRequestDto` → `RegisterPushTokenRequestValidator` (§11.7)
- [ ] `DeletePushTokenQuery` → `DeletePushTokenQueryValidator` (§11.7)
- [ ] `ProfileMeQuery` → `ProfileMeQueryValidator` (§11.8)
- [ ] `UpdateProfileRequest` → `UpdateProfileRequestValidator` (§11.8)
- [ ] `AvatarUploadRequest` → `AvatarUploadRequestValidator` (§11.8)
- [ ] `FaceAvatarUploadRequest` → `FaceAvatarUploadRequestValidator` (§11.8)

#### P4 — Faces, profiles, chat, wall (implement in P4 even if listed before UGC in §8)

- [ ] `SetMyFaceRoleRequest` → `SetMyFaceRoleRequestValidator` (§11.9)
- [ ] `CreateFaceRequest` → `CreateFaceRequestValidator` (§11.9)
- [ ] `UpdateFaceRequest` → `UpdateFaceRequestValidator` (§11.9)
- [ ] `FaceProfileListQuery` → `FaceProfileListQueryValidator` (§11.10)
- [ ] `FaceProfileCommentRequest` → `FaceProfileCommentRequestValidator` (§11.10)
- [ ] `FaceProfileReviewRequest` → `FaceProfileReviewRequestValidator` (§11.10)
- [ ] `CreateFaceChatRoomRequest` → `CreateFaceChatRoomRequestValidator` (§11.11)
- [ ] `CreateSystemFaceChatRoomRequest` → `CreateSystemFaceChatRoomRequestValidator` (§11.11)
- [ ] `UpdateFaceChatRoomRequest` → `UpdateFaceChatRoomRequestValidator` (§11.11)
- [ ] `ChatMessagesQuery` → `ChatMessagesQueryValidator` (§11.11)
- [ ] `WallTicketListQuery` → `WallTicketListQueryValidator` (§11.12–11.13)
- [ ] `WallTicketWriteRequest` → `WallTicketWriteRequestValidator` (§11.12)
- [ ] `WallTicketCommentRequest` → `WallTicketCommentRequestValidator` (§11.12)

#### P4 — CMS pages

- [ ] `GetPagesQuery` → `GetPagesQueryValidator` (§11.14)
- [ ] `CreatePageRequest` → `CreatePageRequestValidator` (§11.14)
- [ ] `UpdatePageRequest` → `UpdatePageRequestValidator` (§11.14)
- [ ] `UpsertPageTranslationsRequest` → `UpsertPageTranslationsRequestValidator` (§11.14)
- [ ] `CreatePageTypeRequest` → `CreatePageTypeRequestValidator` (§11.15)
- [ ] `UpdatePageTypeRequest` → `UpdatePageTypeRequestValidator` (§11.15)
- [ ] `CreatePageComponentRequest` → `CreatePageComponentRequestValidator` (§11.16)
- [ ] `UpdatePageComponentRequest` → `UpdatePageComponentRequestValidator` (§11.16)

#### P5 — Moderation & stats

- [ ] `GetModerationQueueQuery` → `GetModerationQueueQueryValidator` (§11.21)
- [ ] `BulkModerationRequest` → `BulkModerationRequestValidator` (§11.21)
- [ ] `ModerationDecisionRequest` → `ModerationDecisionRequestValidator` (§11.21)
- [ ] `StatsTimeseriesQuery` → `StatsTimeseriesQueryValidator` (§11.18)

#### P3 — Reels

- [ ] `ReelListQuery` → `ReelListQueryValidator` (§11.23)
- [ ] `ReelDetailQuery` → `ReelDetailQueryValidator` (§11.23)
- [ ] `ReelByUserQuery` → `ReelByUserQueryValidator` (§11.23)
- [ ] `CreateReelRequest` → `CreateReelRequestValidator` (§11.23)
- [ ] `UpdateReelRequest` → `UpdateReelRequestValidator` (§11.23)
- [ ] `CreateReelCommentRequest` → `CreateReelCommentRequestValidator` (§11.24)
- [ ] `ReelCommentCreateQuery` → `ReelCommentCreateQueryValidator` (§11.24)
- [ ] `UpdateReelCommentRequest` → `UpdateReelCommentRequestValidator` (§11.24)

#### P3 — Blogs

- [ ] `BlogListQuery` → `BlogListQueryValidator` (§11.25)
- [ ] `CreateBlogRequest` → `CreateBlogRequestValidator` (§11.25)
- [ ] `UpdateBlogRequest` → `UpdateBlogRequestValidator` (§11.25)
- [ ] `CreateBlogCommentRequest` → `CreateBlogCommentRequestValidator` (§11.26)
- [ ] `UpdateBlogCommentRequest` → `UpdateBlogCommentRequestValidator` (§11.26)

#### P3 — Albums

- [ ] `AlbumListQuery` → `AlbumListQueryValidator` (§11.27)
- [ ] `AlbumByUserQuery` → `AlbumByUserQueryValidator` (§11.27)
- [ ] `CreateAlbumRequest` → `CreateAlbumRequestValidator` (§11.27)
- [ ] `UpdateAlbumRequest` → `UpdateAlbumRequestValidator` (§11.27)
- [ ] `CreateAlbumCommentRequest` → `CreateAlbumCommentRequestValidator` (§11.28)
- [ ] `UpdateAlbumCommentRequest` → `UpdateAlbumCommentRequestValidator` (§11.28)

#### P3 — Stories

- [ ] `StoryListQuery` → `StoryListQueryValidator` (§11.29)
- [ ] `StoryMineQuery` → `StoryMineQueryValidator` (§11.29)
- [ ] `StoryDetailQuery` → `StoryDetailQueryValidator` (§11.29)
- [ ] `CreateStoryRequest` → `CreateStoryRequestValidator` (§11.29)
- [ ] `PublishStoryRequest` → `PublishStoryRequestValidator` (§11.29)
- [ ] `StoryViewQuery` → `StoryViewQueryValidator` (§11.29)
- [ ] `StoryImageUploadForm` → `StoryImageUploadFormValidator` (§11.29)
- [ ] `CreateStoryCommentRequest` → `CreateStoryCommentRequestValidator` (§11.30)
- [ ] `StoryScopedQuery` → `StoryScopedQueryValidator` (§11.30)

#### P6 — Social

- [ ] `SendFriendRequestRequest` → `SendFriendRequestRequestValidator` (§11.32)
- [ ] `BlockUserRequest` → `BlockUserRequestValidator` (§11.33)
- [ ] `FollowUserRequest` → `FollowUserRequestValidator` (§11.33)
- [ ] `MessageHistoryQuery` → `MessageHistoryQueryValidator` (§11.31)
- [ ] `NotificationsListQuery` → `NotificationsListQueryValidator` (§11.33)

---

### 12.2 Optional route validators (implement only if adopted)

Not required for P7 unless team enables centralized route validation. If implemented, each needs validator + tests.

- [ ] `FaceIdRouteValidator` (faceId / id route segments > 0)
- [ ] `IdentityUserIdRouteValidator` (non-empty user id)
- [ ] `GuidRouteValidator` (admin invite revoke)
- [ ] Wire via filter or manual `Validate` in actions that today only use route ints

---

### 12.3 Checklist totals

| Category | Count |
|----------|------:|
| §12.1 request/query schemas (validator + tests each) | **76** |
| §12 P0 shared rules (`Validation/Rules/*`) | **14** |
| §12 P0 packages, folders, OAuth filter, sample, IFileValidator + DI | **11** |
| §12 P1–P6 phase-complete gates | **6** |
| §12 P7 cross-cutting (hygiene, tests, docs, comments) | **22** |
| §12.2 optional route validators | **4** |

**Required schema test pairs:** **76** (see §12.1; excludes deprecated OAuth2 register and route-only endpoints in §11).

### 12.4 §11 ↔ §12.1 parity (coverage index)

| Phase | §12.1 rows | §11 sections |
|-------|----------:|--------------|
| P1 | 10 | §11.1–11.5 |
| P2 | 9 | §11.6–11.8 |
| P3 | 28 | §11.23–11.30 (reels, blogs, albums, stories) |
| P4 | 20 | §11.9–11.16, §11.12–11.13 (faces 13 + CMS 7) |
| P5 | 4 | §11.18, §11.21 |
| P6 | 5 | §11.31–11.33 |
| **Total** | **76** | |

**§11 endpoints without a §12.1 row (by design):**

| Reason | Examples |
|--------|----------|
| Deprecated / body ignored | `POST /api/oauth2/register` |
| No body/query schema | `GET` lists, likes `POST` (no body), admin mailer/push test, `GET /api/search/health`, `GET /api/my/content-submissions` |
| Route-only (optional §12.2) | `GET /api/users/{id}`, `DELETE /api/reels/{id}`, face `visit`/`exit`, friend request accept/reject by `id` |
| Authz-only / no input shape | `GET /api/contentmoderation/metrics`, component-types CRUD without request DTOs (§11.17) |

**Dual-schema endpoints (two §12.1 rows each):** reel comment (`CreateReelCommentRequest` + `ReelCommentCreateQuery`); story comments/likes (`CreateStoryCommentRequest` + `StoryScopedQuery`).

**Shared validator across actions:** `ModerationDecisionRequestValidator` — approve / reject / remove (§11.21).

If §11 gains a new **named** validator column, add a matching §12.1 row and bump the **76** total in §12.3 and §19.

---

## 13. Anti-patterns (forbidden)

- Adding a validator **without** `*ValidatorTests.cs`
- Leaving duplicate inline string checks alongside FluentValidation for the same field
- Validating authorization inside FluentValidation (`MustBeAdmin` that hits DB)
- Using `[Required]` on DTOs **and** FluentValidation without migrating fully to FV
- Breaking OAuth2 error JSON shape without explicit filter
- Skipping upload edge tests (file null, wrong content-type, oversize)
- Validators/rules with **no comments** explaining non-obvious bounds
- Merging without §17 guide or without updating API reference validation section
- Leaving `[Required]` on request DTOs after FluentValidation is in place for the same fields

---

## 14. Verification commands

```bash
cd many_faces_backend/BeDemo.Api
dotnet restore
dotnet build

cd ../BeDemo.Api.Tests
dotnet test --filter "FullyQualifiedName~Validation"
dotnet test --filter "FullyQualifiedName~ValidationIntegration"
dotnet test
```

**Validator/test parity (after §16.2 script exists):**

```bash
./many_faces_backend/scripts/verify-validator-tests-parity.sh
```

---

## 15. Code documentation standards (required)

All new or materially changed validation code must be understandable **without** opening controllers or EF configuration.

### 15.1 What to comment

| Artifact | Required documentation |
|----------|-------------------------|
| **Validator class** | `///` summary: which endpoint(s) and HTTP method; pointer to §11 row |
| **Non-obvious rules** | Why max length, whitelist, or cross-field rule exists — cite **EF** (`ApplicationDbContext`), **§18 appendix**, or product doc |
| **Shared rules** (`Validation/Rules/*`) | XML doc on public extension methods; example usage in one line |
| **OAuth2 filter / error mapper** | How FV failures map to `OAuth2ErrorResponse` |
| **`IFileValidator`** | Supported formats, size limits, BE-U1 behavior |
| **Unit tests** | Name tests `Method_Scenario_Expected`; for T1–T12 use comments only when scenario is non-obvious |

### 15.2 What not to do

- Restate the code (`// check email` above `RuleFor(x => x.Email)`).
- Write essays — one or two sentences per rule group is enough.
- Document ACL or DB existence checks in validators (those stay in controllers).

### 15.3 Example (validator header)

```csharp
/// <summary>
/// POST /api/reels — <see cref="CreateReelRequest"/>.
/// Bounds: Title/Description/VideoUrl from EF (Reel entity); VideoUrl also uses <see cref="ContentModerationHelpers.IsSafeHttpUrl"/>.
/// </summary>
public sealed class CreateReelRequestValidator : AbstractValidator<CreateReelRequest>
```

---

## 16. Recommended enhancements (checklist)

Complete during P7 or mark `[ ]` with `TRACK-VAL-*` in the agent report.

### 16.1 EF appendix

- [ ] Keep **§18** in sync when EF `HasMaxLength` changes

### 16.2 CI — validator / test parity

- [ ] Add `many_faces_backend/scripts/verify-validator-tests-parity.sh` (or equivalent) that fails if any `BeDemo.Api/Validation/**/*Validator.cs` (excluding `AbstractValidator` bases) lacks `BeDemo.Api.Tests/Validation/**/*ValidatorTests.cs`
- [ ] Register script in [`testing-and-ci-matrix.md`](../guides/testing-and-ci-matrix.md) and parent CI if applicable

**Starter script (adjust paths if layout differs):**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="$ROOT/BeDemo.Api/Validation"
TESTS="$ROOT/BeDemo.Api.Tests/Validation"
shopt -s globstar nullglob
missing=0
for v in "$API"/**/*Validator.cs; do
  base="$(basename "$v" .cs)"
  [[ "$base" == *"AbstractValidator"* ]] && continue
  t="$TESTS/**/${base}Tests.cs"
  if ! compgen -G "$t" >/dev/null; then
    echo "MISSING TEST: $base -> expected ${base}Tests.cs under $TESTS"
    missing=1
  fi
done
exit "$missing"
```

### 16.3 Integration tests (minimal)

Add `BeDemo.Api.Tests/Validation/Integration/` (or extend existing factory tests):

| Test | Assert |
|------|--------|
| Invalid JSON body on a P1 endpoint | `400` + `errors` dictionary |
| `POST /api/oauth2/token` missing `grantType` | `400` + `OAuth2ErrorResponse`, not ProblemDetails |
| Story image upload with disallowed content-type | `400` |

### 16.4 Swagger (optional)

- [ ] `MicroElements.Swashbuckle.FluentValidation` or document rules in OpenAPI descriptions for P1 endpoints

### 16.5 Testing environment

- [ ] Run full `BeDemo.Api.Tests` under `Testing` environment; fix tests that assumed legacy `{ error }` for **input** validation only

---

## 17. Documentation & guides (required deliverables)

**Do not mark P7 complete** until these exist and are linked from the PR.

### 17.1 Primary guide (create or fully rewrite)

**File:** [`docs/guides/api-request-validation.md`](../guides/api-request-validation.md)

Minimum sections (each must exist — also tracked in §12 P7):

1. [ ] **Overview** — FluentValidation, one schema per request, where files live (`Models/Requests`, `Validation/`).
2. [ ] **How to add a new endpoint** — checklist: request DTO → validator → unit tests (§4) → assembly scan → thin controller.
3. [ ] **400 response shapes** — ProblemDetails vs OAuth2 vs legacy `{ error }` (§6).
4. [ ] **`errorCode` catalog** — table of `val_*` codes introduced in this engagement.
5. [ ] **Uploads** — `IFileValidator` + BE-U1 pointer to security guide.
6. [ ] **Face routing** — logical `/api/...` paths; exempt routes list.
7. [ ] **Testing** — unit (`TestValidate`) + integration + parity script.
8. [ ] **Appendix** — EF limits (duplicate §18 or link).

### 17.2 Updates to existing docs

| File | Change |
|------|--------|
| [`many_faces_backend/docs/reference/01-features-running-and-api.md`](../../many_faces_backend/docs/reference/01-features-running-and-api.md) | New subsection **Request validation** — link to guide, default 400 shape, package names |
| [`docs/guides/authentication-and-sessions.md`](../guides/authentication-and-sessions.md) | Short note: OAuth token validation via FV + error shape unchanged |
| [`docs/guides/openapi-client-generation.md`](../guides/openapi-client-generation.md) | One paragraph: validation errors in generated clients |
| [`docs/guides/testing-and-ci-matrix.md`](../guides/testing-and-ci-matrix.md) | Row: validator parity script + `Validation` + `ValidationIntegration` test filters |
| [`docs/prompts/README.md`](./README.md) | One row in the prompts table for this file |
| Portal/admin/mobile (optional note) | Register/complete UI should align with **12**-char policy (BE-A3); login forms may keep lower client min for existing accounts — document in guide §17.2 if not changed in this engagement |

### 17.3 Mermaid (optional but encouraged)

One small diagram in the guide: Client → Controller → FV auto-validation → 400 ProblemDetails vs OAuth filter branch.

---

## 18. Appendix — EF `HasMaxLength` cheat sheet

Use when writing validators; **prefer this over controller copy-paste**. If app cap ≠ EF (e.g. blog `Content`), comment the validator and list the cap here.

| Entity / field | Max length | Notes |
|----------------|------------|--------|
| `Face.Index` | 100 | |
| `Face.Title` | 200 | |
| `Face.Description` | 1000 | |
| `Page.Name` | 200 | |
| `Page.Path` | 500 | SlugPathRule also applies |
| `Page.Description` | 1000 | |
| `PageType.Index` | 50 | |
| `PageRouteTranslation.LanguageCode` | 10 | |
| `PageRouteTranslation.TranslatedRoute` | 200 | |
| `PageComponent.Label` / `Title` | 200 | |
| `PageComponent.Icon` | 100 | |
| `PageComponent.GridKey` | 100 | |
| `Blog.Title` | 200 | Required on create |
| `Blog.Content` | *(text)* | App cap e.g. 100_000 in validator |
| `BlogComment.Content` | 2000 | |
| `BlogImage.ImageUrl` | 500 | Max 3 per blog (controller) |
| `Album.Title` | 200 | |
| `Album.Description` | 2000 | |
| `AlbumComment.Content` | 2000 | |
| `Reel.Title` | 200 | |
| `Reel.Description` | 2000 | |
| `Reel.VideoUrl` | 1000 | Must be safe http(s) URL |
| `ReelComment.Content` | 2000 | |
| `Story.Title` | 200 | |
| `StoryImage.ImageUrl` | 1000 | |
| `StoryImage.Description` | 2000 | |
| `StoryComment.Content` | 2000 | |
| `UserFaceProfileComment.Body` | 4000 | |
| `UserFaceProfileReview.Title` | 200 | |
| `UserFaceProfileReview.Text` | 8000 | |
| `FaceWallTicket` title (app) | 200 | Controller constant |
| `FaceWallTicket` description | 8000 | `MaxDescriptionLength` |
| `FaceWallTicketComment.Content` | 255 | `MaxCommentLength` |
| `FaceChatRoom` title (app) | 200 | Validator normative |
| `FaceChatRoom` description | 2000 | Validator normative |
| `RegistrationInvite.LinkHash` | 128 | |
| `RegistrationInvite` code length | `RegistrationInviteOptions.CodeLength` (default 6) | Not max string length |
| `RegisterPushTokenRequestDto.RegistrationToken` | 512 | Min 10 in controller |
| Identity user id fields | 450 | |
| `Notification` / message title | 200 / 50 | |
| Moderation `HumanDecisionReason` etc. | 2000 | Decision DTO reason/message |

---

## 19. Agent final report template

```markdown
## Endpoint validation rollout — report

### Completed phases
- P0 … Pn

### §12.1 progress
- [ ] / 76 schema rows complete (validator + tests)
- [ ] P0 … P7 phase gates complete

### Validators added (count) — must match §12.1
### Test classes added (count) — must equal validators with input schemas

### Endpoints intentionally without schema
(list route-only)

### OAuth2 400 shape
(how mapped)

### Documentation (§17)
- [ ] `docs/guides/api-request-validation.md` created/updated
- [ ] `01-features-running-and-api.md` validation subsection
- [ ] Other guide cross-links listed in §17.2

### Code comments (§15)
- [ ] All validators and shared rules have class-level summary + bound sources where non-obvious

### §16 enhancements
| Item | Done | Tracking id |
|------|------|-------------|
| CI parity script | | |
| Integration tests | | |
| IFileValidator | | |
| Swagger FV | | |

### Blocked items
TRACK-VAL-* …
```

---

*Verified against `BeDemo.Api/Controllers` (**44** controllers, **178** HTTP actions, 2026-05-16). Re-verify against Swagger after implementation if controllers drift.*
