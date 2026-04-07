# Face wall tickets

End-to-end feature: per-face **idea / feedback tickets** with **likes** and **comments**, **moderation** (global Admin / SuperAdmin only), **hard delete**, and **delayed deletion** of denied tickets via the Redis job worker.

## Data model

- **FaceWallTicket** — `FaceId`, `CreatorUserId`, `Title` (max 200), `Description` (text, max 8000 in API), `Status` (`active` | `approved` | `denied`), timestamps.
- **FaceWallTicketComment** — `FaceWallTicketId`, `UserId`, `Content` (max **255** plain text).
- **FaceWallTicketLike** — unique (`FaceWallTicketId`, `UserId`).

Deleting a ticket removes comments and likes (EF cascade).

## Status and rules

| Status    | Visible on wall | Likes / comments | Author edit | Author delete | Notes |
|-----------|-----------------|------------------|-------------|---------------|--------|
| Active    | Yes             | Yes (non-host)   | Yes         | Yes           | Max **20** tickets per user per face (any status counts). |
| Approved  | Yes             | **Frozen** (read counts) | No  | No            | Moderation final. |
| Denied    | Yes             | **Frozen**       | No          | No            | Scheduler **hard-deletes** after **2 days** (`wall.ticket-delete` job). |

- **Host** face role: may **view** list and detail; **cannot** create, like, comment, or unlike.
- **Global Admin / SuperAdmin** (application role in DB, same check as chat-room admin tools): moderation APIs only; not “face admin” (planned separately).

## Backend API

Base URL is the API origin (e.g. `https://localhost:7xxx`). All routes require `Authorization: Bearer <access_token>` unless noted.

### User — `api/faces/{faceId}/wall-tickets`

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Paginated list (`page`, `pageSize` 1–100). Response includes **`isHostViewer`** (face-level host). |
| GET | `/{ticketId}` | Detail + embedded `comments` (ordered oldest first). |
| POST | `/` | Create (`title`, `description`). **403** if host. **400** if over 20 tickets for user+face. |
| PUT | `/{ticketId}` | Author only; **active** only. |
| DELETE | `/{ticketId}` | Author + **active**, or **global admin** (any status). Hard delete. |
| POST | `/{ticketId}/like` | Toggle on; **active** only; not host. |
| DELETE | `/{ticketId}/like` | Unlike; same rules. |
| GET | `/{ticketId}/comments` | List comments. |
| POST | `/{ticketId}/comments` | Add comment; **active** only; not host; body `{ "content": "..." }` (≤255). |

### Admin — `api/admin/faces/{faceId}/wall-tickets`

**403** if caller is not global Admin/SuperAdmin.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Paginated list (same paging as above). |
| GET | `/{ticketId}` | Full detail + comments. |
| POST | `/{ticketId}/approve` | **Active → approved** only. |
| POST | `/{ticketId}/deny` | **Active → denied**; schedules **`wall.ticket-delete`** at **UTC + 2 days**. |
| DELETE | `/{ticketId}` | Hard delete any status. |
| DELETE | `/{ticketId}/comments/{commentId}` | Remove one comment. |

Authors **cannot** delete comments; only admins (this route).

## Redis worker

- Job type: **`wall.ticket-delete`**
- Payload: `{ "wallTicketId": <int> }`
- Registered in `RedisJobWorkerService`; handler resolves `IFaceWallTicketLifecycleService` and calls **`DeleteTicketHardAsync`**.
- **Testing** environment uses `NoOpRedisJobQueue` — deny still updates status in DB, but no delayed job is enqueued; use integration tests or call `DeleteTicketHardAsync` manually when verifying.

## Frontend (`fe_demo`)

- Pages with **`pageType.index === 'wall'`** render the wall list inside `FacePageView`, optional grid below if configured.
- **Header** “+” on wall routes opens **`WallTicketCreateTopPanel`** (same pattern as stories).
- **Ticket row** opens a **right slide-out** (`WallTicketDetailPanel`) for description, like, comments, author edit/delete when allowed.
- **i18n**: `wallTickets.*` and extra `common.cancel|save|delete|close` in **en / sk / cz**.
- Path detection uses **`pathnameMatchesWallPage`** so translated page routes still match.

## Admin UI (`admin_demo`)

- From **Face detail**, button **Wall tickets (moderation)** → `/:lang/.../faces/:id/wall-tickets`.
- Table: approve / deny / delete ticket; open title for full text and comments; delete individual comments.
- Strings under **`pages.faceWallTickets`** and **`pages.faceDetail.wallTickets`** (en / sk / cz).

## Database migration

Apply with EF (non-Testing): migration **`AddFaceWallTickets`**. Testing uses `EnsureCreated` and picks up new tables automatically.

## Automated tests

`BeDemo.Api.Tests/FaceWallTicketsControllerTests.cs` covers host create forbidden, create/like/comment + approve freeze, deny + hard delete service, admin comment delete, 20-ticket cap, non-admin forbidden on admin list, author vs approved edit/delete, long comment, double approve, **list when face not found (404)**, **deny then like frozen (400)**.

Frontends: Vitest tests for `parseApiErrorBody` / `getApiErrorMessage` in `fe_demo` and `admin_demo` (`src/utils/apiErrorMessage.test.ts`).

## Client error display (FE / admin)

Failed `fetch` calls use a shared helper that turns response bodies into toast / inline messages (ProblemDetails, `{ error }`, validation `errors`). See [DEVELOPMENT.md](./DEVELOPMENT.md#api-error-messages-in-the-browser).

### UX notes

- **FE**: Host viewers do not get the wall “create” shortcut; `Escape` closes wall panels and settings where implemented.
- **Admin**: Face wall moderation page disables destructive / moderation actions while a mutation is in progress (`actionBusy`).

## Manual checks (curl)

1. Run API with `ASPNETCORE_ENVIRONMENT=Testing` (in-memory DB + seed).
2. OAuth2 **password** grant: `POST /api/oauth2/token` with client `be-demo-client` / secret from appsettings (see existing story/chat tests).
3. `PUT /api/faces/{faceId}/my-role` with **FACE_USER** role id from `GET /api/faces/face-roles`.
4. `POST /api/faces/{faceId}/wall-tickets` with JSON body.
5. `GET /api/faces/{faceId}/wall-tickets?page=1&pageSize=20`.
6. Promote user to Admin in DB (or use seeded admin — note seed admins are **host** on faces, so use a fresh user + `PromoteUserToGlobalAdmin` pattern from tests) and call `POST /api/admin/faces/{faceId}/wall-tickets/{id}/approve` or `deny`.

## Future (out of scope for this baseline)

- Face-level moderators, notifications, reports, full-text filters, cancelling deny jobs if workflow changes, optional 24h vs 2d deny retention.
