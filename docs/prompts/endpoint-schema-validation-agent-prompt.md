# Endpoint schema & input validation — `many_faces_backend` agent prompt

**Language:** English (identifiers and paths follow the repository).  
**Use:** Copy **§0** (master instructions) or the **whole document** into a new AI agent session.

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

**Routing note:** Clients call `/{face-prefix}/api/...` for face-scoped APIs. Validators describe the **logical** path after `RoutingMiddleware` (`/api/...`). Face-prefix exempt routes: `/api/oauth2/*`, `/api/auth/*`, `/api/localization/*`, `/api/oauth2/jwks`, etc.

**Worksheet vs git:** `[ ]` lists are **templates** for PR/agent reports; do not mass-replace with `[x]` in git unless the team adopts this file as a living completion log ([prompts/README.md](./README.md)).

---

## 0. Master instructions (paste into agent chat)

You are implementing **centralized request validation** for `many_faces_backend` (`BeDemo.Api`) using **FluentValidation** (the .NET equivalent of Zod-style per-request schemas).

**Non-negotiable rules:**

1. **One FluentValidation class per request schema** (body DTO, query object, or multipart form model). Naming: `{RequestName}Validator` validating `{RequestName}`.
2. **Every schema listed in §11 with a validator name MUST have a dedicated edge-case unit test class** in `BeDemo.Api.Tests/Validation/` named `{RequestName}ValidatorTests`. **No schema ships without tests.**
3. **Remove duplicate inline validation** from controllers once the validator runs (keep authz, 404, domain rules).
4. **Do not** use validation to enforce ACL (`CanManageAllFaces`, `Forbid`) — only **input shape, bounds, and safe formats**.
5. **Password strength** for register/complete/admin-create-user: HTTP schema checks **presence + max length + no null bytes**; **minimum length/complexity** remains **ASP.NET Identity** (`IdentityPasswordPolicyOptions`, `UserManager`).
6. **Uniform 400 response:** `ValidationProblemDetails` via `AddFluentValidationAutoValidation()` unless an endpoint must keep OAuth2 error shape (`OAuth2TokenRequest` → custom filter or dual pipeline documented in PR).
7. **Relocate** request types from controller file bottoms into `BeDemo.Api/Models/Requests/**` (preserve JSON property names / camelCase).
8. After each phase, run `dotnet test many_faces_backend/BeDemo.Api.Tests` — all new validator tests must pass.

**Deliverables:** NuGet packages, `Program.cs` wiring, `Validation/Rules/*` shared extensions, all validators + tests per §12 registry, controller cleanup, short note in `many_faces_backend/docs/reference/01-features-running-and-api.md` (validation section only).

---

## 1. Objectives

1. Replace ad-hoc `if (string.IsNullOrWhiteSpace…)` / inconsistent `ModelState` usage with **testable schemas**.
2. Document **every HTTP endpoint** input contract (body, query, route, form).
3. Guarantee **edge-case unit test coverage per schema** (mandatory gate for merge).
4. Align with SHV2 **BE-U1** for uploads (validator + magic-byte service).

---

## 2. Technology choice

| Layer | Choice |
|-------|--------|
| Library | **FluentValidation 11.x** + **FluentValidation.AspNetCore** |
| Registration | `AddFluentValidationAutoValidation()`, `AddValidatorsFromAssemblyContaining<Program>()` |
| Query binding | `[AsParameters]` records or `[FromQuery] QueryDto` + validator |
| Tests | `FluentValidation.TestHelper` (`TestValidate`, `ShouldHaveValidationErrorFor`) |

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

**CI gate:** PR must not add a validator file without matching `*ValidatorTests.cs`. Code review checks §12 registry row flipped to `[x]` for both validator and tests.

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
| `PlatformPushRule` | `ios` or `android` lowercase |
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

---

## 7. What stays in controllers (not validators)

- `[Authorize]` / `[AllowAnonymous]` / `Forbid()` / `CanManageAllFaces()`
- Entity existence → `NotFound`
- Duplicate like, friendship state, moderation state machine
- Face scope gates (`IFaceScopeContext`, `GateTenantFaceOrNotFound`)
- Identity `UserManager.CreateAsync` / `AddPasswordAsync` failures
- File **magic-byte** check after model binding (SHV2 BE-U1) — called from action or `IFileValidator`

---

## 8. Implementation phases

| Phase | Content |
|-------|---------|
| **P0** | Packages, `Program.cs`, `Validation/Rules`, error policy, sample `PaginationQuery` + tests |
| **P1** | Auth + OAuth + registration + admin invites (§11.1–11.3) |
| **P2** | Users, profile, me/push-token (§11.4–11.6) |
| **P3** | UGC: reels, blogs, albums, stories + nested comments (§11.14–11.21) |
| **P4** | Faces, pages, CMS components, face-scoped social (§11.7–11.13, §11.22–11.24) |
| **P5** | Moderation, stats, admin tools (§11.25–11.28) |
| **P6** | Social graph: friends, blocks, follows, messages, notifications (§11.29–11.33) |
| **P7** | Remove dead inline checks; full `dotnet test`; update API reference doc |

---

## 9. Endpoint inventory conventions

Columns:

- **Schema** — request type to create (or `—` if no body/query schema; route-only)
- **Validator** — FluentValidation class name
- **Validation rules** — normative bounds to encode
- **Edge tests** — minimum extra cases beyond §4

Face-scoped routes omit `/{face}` prefix in tables.

---

## 11. Full endpoint catalog

### 11.1 AuthController — `api/auth`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/auth/register` | `RegisterRequest` | `RegisterRequestValidator` | Email required, valid, max 256; password required, max 128, no `\0`; first/last name optional max 100; trim | Valid register; invalid email; password empty; null byte in email |
| POST | `/api/auth/login` | `LoginRequest` | `LoginRequestValidator` | Email required valid; password required not empty; rememberMe bool | Empty password; invalid email |
| POST | `/api/auth/logout` | — | — | No input schema | — |

### 11.2 OAuth2Controller — `api/oauth2`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/oauth2/token` | `OAuth2TokenRequest` | `OAuth2TokenRequestValidator` | `grantType` required, whitelist `password` \| `refresh_token`; password grant: username+password required, no `\0`; refresh grant: refreshToken required; clientId/secret max lengths; rememberMe optional bool; signature fields optional max length | Each grant type valid/invalid; missing username on password grant; null byte; empty grantType |
| POST | `/api/oauth2/register` | `OAuth2RegisterRequest` | `OAuth2RegisterRequestValidator` | Same as register (deprecated endpoint — validator for consistency even if always 400) | — |

### 11.3 OAuth2RegistrationController + AdminRegistrationInvites — registration

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/oauth2/register/request` | `RegisterRequestDto` | `RegisterRequestValidator` | Email required valid; first/last/locale/platform optional bounded; platform whitelist `mobile` if present; no `\0` in email | platform invalid; locale max length |
| POST | `/api/oauth2/register/resend` | `RegisterResendDto` | `RegisterResendValidator` | Email required valid; locale/platform optional | — |
| GET | `/api/oauth2/register/prefill` | `RegisterPrefillQuery` | `RegisterPrefillQueryValidator` | `hash` required, non-whitespace, max 200, no `\0` | missing hash; whitespace hash |
| POST | `/api/oauth2/register/complete` | `RegisterCompleteDto` | `RegisterCompleteValidator` | hash required max 200; code required length 4–12 (match invite service); password required max 128 no `\0`; clientId/secret optional max; rememberMe optional | missing code; null byte in hash |
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
| POST | `/api/profile/me/avatar` | `AvatarUploadRequest` | `AvatarUploadRequestValidator` | file required; extension in `.jpg,.jpeg,.png,.gif,.webp`; size ≤ 30MB; BE-U1 magic bytes in handler | no file; `.exe` extension |
| POST | `/api/profile/me/faces/{faceId}/avatar` | `FaceAvatarUploadRequest` | `FaceAvatarUploadRequestValidator` | faceId > 0 + same file rules as avatar | faceId invalid |

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
| GET | `.../profiles` | `FaceProfileListQuery` | `FaceProfileListQueryValidator` | page ≥ 1; pageSize 1–50 | — |
| GET | `.../profiles/{userId}` | — | `FaceIdRouteValidator` + `IdentityUserIdRouteValidator` | | |
| POST | `.../profiles/{userId}/like` | — | route only | | |
| DELETE | `.../profiles/{userId}/like` | — | route only | | |
| GET | `.../profiles/{userId}/likes` | — | route only | | |
| GET | `.../profiles/{userId}/comments` | — | route only | | |
| POST | `.../profiles/{userId}/comments` | `FaceProfileCommentRequest` | `FaceProfileCommentRequestValidator` | body required max 4000 trim | empty body; 4001 chars |
| DELETE | `.../profiles/comments/{commentId}` | — | `CommentIdRouteValidator` | commentId > 0 | |
| GET | `.../profiles/{userId}/reviews` | — | route only | | |
| POST | `.../profiles/{userId}/reviews` | `FaceProfileReviewRequest` | `FaceProfileReviewRequestValidator` | title required max 200; text required max 8000; stars optional 1–6 | stars=0; stars=7 |
| DELETE | `.../profiles/reviews/{reviewId}` | — | route only | reviewId > 0 | |

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
| GET | `/api/search/health` | — | — | | |

### 11.20 AdminMailerTestController + AdminPushTestController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| POST | `/api/admin/mailer/test-self` | — | — | no body; authz | — |
| GET | `/api/admin/mailer/pilot-link` | — | — | AllowAnonymous | — |
| POST | `/api/admin/push/test-self` | — | — | no body; authz | — |

### 11.21 ContentModerationController — `api/contentmoderation`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/contentmoderation` | `GetModerationQueueQuery` | `GetModerationQueueQueryValidator` | optional enums valid; faceId>0 if set; authorId/reviewerId identity rule; flagContains max 200; confidence 0–1, min≤max; date range valid; minQueueAgeHours ≥ 0 | minConfidence>maxConfidence |
| GET | `/api/contentmoderation/{contentType}/{contentId}/events` | — | enum route + contentId>0 | | |
| GET | `/api/contentmoderation/metrics` | — | — | | |
| POST | `/api/contentmoderation/bulk` | `BulkModerationRequest` | `BulkModerationRequestValidator` | action enum; items count 1–100; distinct pairs; reason required when reject/remove; reason/userMessage max 2000 | 0 items; 101 items; reject without reason |
| POST | `.../approve` | `ModerationDecisionRequest` | `ModerationDecisionRequestValidator` | reason/userMessage optional max 2000 | — |
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
| POST | `/api/reels` | `CreateReelRequest` | `CreateReelRequestValidator` | title required max 200; videoUrl safe http(s); description max 4000; faceIds each >0 max 20 | unsafe url; 21 face ids |
| PUT | `/api/reels/{id}` | `UpdateReelRequest` | `UpdateReelRequestValidator` | optional fields with bounds | — |
| DELETE | `/api/reels/{id}` | — | id > 0 | | |

### 11.24 ReelCommentsController + ReelLikesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/reels/{reelId}/comments` | — | reelId > 0 | | |
| POST | `.../comments` | `CreateReelCommentRequest` | `CreateReelCommentRequestValidator` | content required max 4000 | empty |
| PUT | `.../comments/{id}` | `UpdateReelCommentRequest` | `UpdateReelCommentRequestValidator` | content required max 4000 | — |
| DELETE | `.../comments/{id}` | — | route | | |
| GET | `.../likes` | — | route | | |
| POST | `.../likes` | — | — | no body | — |
| DELETE | `.../likes` | — | — | | |

### 11.25 BlogsController — `api/blogs`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/blogs` | `BlogListQuery` | `BlogListQueryValidator` | faceId optional > 0 | — |
| GET | `/api/blogs/{id}` | — | id > 0 | | |
| POST | `/api/blogs` | `CreateBlogRequest` | `CreateBlogRequestValidator` | title max 200; content required max 50_000; faceId > 0; imageUrls max 3 each safe url | 4 image urls; invalid url |
| PUT | `/api/blogs/{id}` | `UpdateBlogRequest` | `UpdateBlogRequestValidator` | optional with bounds | — |
| DELETE | `/api/blogs/{id}` | — | route | | |

### 11.26 BlogCommentsController + BlogLikesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/blogs/{blogId}/comments` | — | blogId > 0 | | |
| POST | `.../comments` | `CreateBlogCommentRequest` | `CreateBlogCommentRequestValidator` | content required max 4000 | — |
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

Same pattern as §11.26 (`CreateAlbumCommentRequest`, content max 4000).

### 11.29 StoriesController — `api/stories`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/stories` | `StoryListQuery` | `StoryListQueryValidator` | faceId required > 0 (per controller) | — |
| GET | `/api/stories/me` | `StoryListQuery` | reuse | faceId optional | — |
| GET | `/api/stories/{id}` | `StoryDetailQuery` | `StoryDetailQueryValidator` | id>0; faceId>0 | — |
| POST | `/api/stories` | `CreateStoryRequest` | `CreateStoryRequestValidator` | title required max 200; faceIds optional each >0 max 20 | — |
| POST | `/api/stories/{id}/publish` | `PublishStoryRequest` | `PublishStoryRequestValidator` | scheduledPublishAt optional, must be UTC future if set | past date |
| DELETE | `/api/stories/{id}` | — | route | | |
| POST | `/api/stories/{id}/view` | `StoryViewQuery` | `StoryViewQueryValidator` | faceId > 0 | — |
| POST | `/api/stories/{id}/images` | `StoryImageUploadForm` | `StoryImageUploadFormValidator` | file required image/*; size ≤ 52MB; sortOrder 0–9; description max 500; BE-U1 | sortOrder=10; non-image |

### 11.30 StoryCommentsController + StoryLikesController

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `.../comments` | `StoryScopedQuery` | faceId > 0 | | |
| POST | `.../comments` | `CreateStoryCommentRequest` | content max 4000 + faceId query | | |
| GET/POST/DELETE | `.../likes` | `StoryScopedQuery` | faceId > 0 | | |

### 11.31 MessagesController — `api/messages`

| Method | Path | Schema | Validator | Validation rules | Edge tests |
|--------|------|--------|-----------|------------------|------------|
| GET | `/api/messages/conversations` | — | — | | |
| GET | `/api/messages/requests` | — | — | | |
| GET | `/api/messages/with/{otherUserId}` | `MessageHistoryQuery` | `MessageHistoryQueryValidator` | otherUserId required; limit 1–200 | limit=0 |
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
| GET | `/api/notifications` | `NotificationsListQuery` | `NotificationsListQueryValidator` | limit 1–100 | limit=101 |

---

## 12. Validator & test registry (master checklist)

**Rule:** For each row, `[ ]` → `[x]` only when **both** validator and `*ValidatorTests` exist and §4 matrix is satisfied.

### P0 — Infrastructure

- [ ] `FluentValidation` + `FluentValidation.AspNetCore` in `BeDemo.Api.csproj`
- [ ] `Program.cs` registration + OAuth2 error mapping decision documented
- [ ] `Validation/Rules/PaginationRules.cs` + tests
- [ ] `Validation/Rules/SafeHttpUrlRule.cs` + tests
- [ ] `Validation/Rules/NoNullBytesRule.cs` + tests

### P1 — Auth & OAuth (§11.1–11.5)

- [ ] `RegisterRequest` + tests
- [ ] `LoginRequest` + tests
- [ ] `OAuth2TokenRequest` + tests
- [ ] `RegisterRequestDto` / `RegisterResendDto` / `RegisterCompleteDto` + tests
- [ ] `RegisterPrefillQuery` + tests
- [ ] `AdminInviteListQuery` + tests
- [ ] `AdminCreateRegistrationInviteDto` + tests
- [ ] `LocalizationBundleQuery` + tests

### P2 — Users & profile (§11.6–11.8)

- [ ] `GetUsersQuery` + tests
- [ ] `CreateUserRequest` + tests
- [ ] `UpdateUserRequest` + tests
- [ ] `RegisterPushTokenRequest` + tests
- [ ] `UpdateProfileRequest` + tests
- [ ] `AvatarUploadRequest` / `FaceAvatarUploadRequest` + tests

### P3 — UGC (§11.23–11.30)

- [ ] All `Create*Request` / `Update*Request` for reels, blogs, albums, stories + comment schemas + tests
- [ ] `StoryImageUploadForm` + tests

### P4 — Faces & CMS (§11.9–11.17, §11.12–11.13)

- [ ] Face CRUD requests + `SetMyFaceRoleRequest` + tests
- [ ] Chat room requests + `ChatMessagesQuery` + tests
- [ ] Wall ticket write/comment + tests
- [ ] Page / page type / page component requests + tests

### P5 — Moderation & admin stats (§11.18–11.21)

- [ ] `GetModerationQueueQuery` + tests
- [ ] `BulkModerationRequest` + tests
- [ ] `ModerationDecisionRequest` + tests
- [ ] `StatsTimeseriesQuery` + tests

### P6 — Social (§11.31–11.33)

- [ ] Friend/block/follow/message/notification queries + tests

### P7 — Cleanup

- [ ] Inline `BadRequest` validation removed from controllers for covered endpoints
- [ ] `dotnet test` green
- [ ] API reference validation subsection updated

**Approximate schema count:** ~**75** validators (+ shared rules). **~75** test classes minimum.

---

## 13. Anti-patterns (forbidden)

- Adding a validator **without** `*ValidatorTests.cs`
- Leaving duplicate inline string checks alongside FluentValidation for the same field
- Validating authorization inside FluentValidation (`MustBeAdmin` that hits DB)
- Using `[Required]` on DTOs **and** FluentValidation without migrating fully to FV
- Breaking OAuth2 error JSON shape without explicit filter
- Skipping upload edge tests (file null, wrong content-type, oversize)

---

## 14. Verification commands

```bash
cd many_faces_backend/BeDemo.Api
dotnet restore
dotnet build

cd ../BeDemo.Api.Tests
dotnet test --filter "FullyQualifiedName~Validation"
dotnet test
```

---

## 15. Agent final report template

```markdown
## Endpoint validation rollout — report

### Completed phases
- P0 … Pn

### Validators added (count)
### Test classes added (count) — must equal validators with input schemas

### Endpoints intentionally without schema
(list route-only)

### OAuth2 400 shape
(how mapped)

### Blocked items
TRACK-VAL-* …
```

---

*Generated from `BeDemo.Api/Controllers` inventory (42 controllers, ~170 HTTP actions). Re-verify against Swagger after implementation if controllers drift.*
