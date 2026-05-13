# Database repo SQL seeds vs backend seeders — Agent prompt

## 1. Mission

Split **demo / reference database seeding** between:

- **`many_faces_database`** — versioned **PostgreSQL `.sql` scripts** (and optional shell orchestration) owned by the database submodule.
- **`many_faces_backend`** — only what **cannot** be expressed safely or maintainably in plain SQL (primarily **ASP.NET Identity** password hashing, **OAuth client secret hashing**, **startup maintenance jobs**, and **test-only** seed helpers).

**Operational assumption (explicit):** It is acceptable to **wipe the database** (drop volume / remove containers / `docker compose down -v`) and start from a clean PostgreSQL volume when validating the new flow. Design for **greenfield + migrate-first**, not in-place repair of legacy rows.

**Non-goals for the first implementation pass:**

- Replacing **EF Core migrations** (schema) with SQL in the database repo. Schema stays in **`many_faces_backend`** until a separate product decision says otherwise.
- Production-grade secret management inside committed SQL (demo secrets only; document rotation for real envs).

**Success criteria (summary):** After `MigrateAsync`, applying SQL seeds yields the same **observable** reference data as today’s C# seed for those tables; the API **does not** double-insert; **`Testing`** + **`BeDemo.Api.Tests`** still work without `psql`; **`many_faces_database/README.md`** documents copy-paste commands for developers.

---

## 2. Current state (inspection summary)

### 2.1 Where seeding runs today

| Location                                                      | Responsibility                                                                                                                                                                                                                               |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `many_faces_backend/BeDemo.Api/Program.cs`                    | Non-`Testing`: retries `DatabaseInitializer.InitializeAsync`, then `DatabaseSeeder.SeedAsync`, `SeedUsersAsync`, `SeedFaceGridContentAsync`, then `ReactivateExpiredStoriesForStartupAsync`.                                                 |
| `many_faces_backend/BeDemo.Api/Scripts/InitializeDatabase.cs` | `MigrateAsync`, optional Mermaid ERD generation, `SeedUserRolesAsync`, creates **`admin@admin.com`** (password `admin`) via **`UserManager`**, ensures `UserProfile`.                                                                        |
| `many_faces_backend/BeDemo.Api/Scripts/DatabaseSeeder.cs`     | `MigrateAsync` again at start of `SeedAsync`, then reference data, OAuth demo client, faces/pages, bulk demo users + profiles + face roles, grid demo content (wall, albums, blogs, reels, stories, chat rooms), story reactivation helpers. |
| `many_faces_backend/BeDemo.Api.Tests/TestHelpers.cs`          | `Testing` env via `CustomWebApplicationFactory`: `EnsureCreated`, `DatabaseSeeder.SeedDataOnlyAsync`, `IntegrationTestSeed.EnsureAsync` / `EnsureSuperAdminAsync`.                                                                           |
| `many_faces_backend/BeDemo.Api.Tests/IntegrationTestSeed.cs`  | In-memory integration users (`integration-admin@test.com`, `integration-superadmin@test.com`) — **must remain in backend tests**; not for production SQL.                                                                                    |

**Implementation note — duplicate `MigrateAsync`:** Migrations run from **both** `DatabaseInitializer.InitializeAsync` and the start of `DatabaseSeeder.SeedAsync` (redundant but harmless today). When touching this area, **consolidate to a single `MigrateAsync` per process start** (e.g. only in initializer, or only in a dedicated migrate step) and keep behaviour documented.

**Implementation note — duplicate `SeedUserRolesAsync`:** Invoked from **`InitializeDatabase`** (before creating `admin@admin.com`) and again from **`SeedAsync`** / **`SeedDataOnlyAsync`**. Both paths are **idempotent** today; SQL move should replace **both** C# insert paths for roles with one SQL file + guards so roles are not re-inserted from C# when SQL already ran.

**Testing (`ASPNETCORE_ENVIRONMENT=Testing`) — `Program.cs` branch:** Uses `EnsureCreatedAsync` + **`SeedDataOnlyAsync` only** (no `InitializeDatabase`, no `SeedUsersAsync`, no `SeedFaceGridContentAsync`, no startup story reactivation in that branch). **`IntegrationTestSeed`** is **not** invoked from `Program.cs`; it runs only inside **`CustomWebApplicationFactory`** (`TestHelpers.cs`). Integration tests therefore **must not** depend on Postgres or `psql` unless you explicitly add a separate test category.

### 2.2 `many_faces_database` today

- **`docker-compose.yml`:** Postgres 16 + pgAdmin; **no** `docker-entrypoint-initdb.d` volume for BeDemo app tables.
- **`scripts/start-db.sh`**, **`stop-db.sh`**, **`clear-db.sh`**, **`create-bedemo-role.sh`:** infra helpers. **`clear-db.sh`** / `docker compose … down -v` removes the **named volume** — full data loss; use when validating greenfield + migrate + SQL seed (see **§11**).

### 2.3 `SeedAsync` vs `SeedDataOnlyAsync` (what each loads)

| Method / block                            |                 In `SeedAsync`                 | In `SeedDataOnlyAsync` |
| ----------------------------------------- | :--------------------------------------------: | :--------------------: |
| `MigrateAsync` (+ EnsureCreated fallback) |                      Yes                       |         **No**         |
| `SeedUserRolesAsync`                      |                      Yes                       |          Yes           |
| `SeedPageTypesAsync`                      |                      Yes                       |          Yes           |
| `SeedComponentTypesAsync`                 |                      Yes                       |          Yes           |
| `SeedDisplayModesAsync`                   |                      Yes                       |          Yes           |
| `SeedFacesAndPagesAsync`                  |                      Yes                       |          Yes           |
| `SeedOAuthClientsAsync`                   |                      Yes                       |          Yes           |
| `SeedUsersAsync`                          | Only from `Program.cs`, not inside `SeedAsync` |         **No**         |
| `SeedFaceGridContentAsync`                |             Only from `Program.cs`             |         **No**         |
| `ReactivateExpiredStoriesForStartupAsync` |             Only from `Program.cs`             |         **No**         |

Any SQL that replaces **reference** rows must mirror what **`SeedDataOnlyAsync`** already covers so **in-memory tests** stay aligned with Postgres dev unless you intentionally fork behaviour (discouraged).

### 2.4 Reference data implemented in C# (candidates for SQL)

From `DatabaseSeeder` (and helpers it depends on):

- **`SeedUserRolesAsync`** — global + face-scoped `UserRole` rows. Exact **`Name`** strings and **`Scope`** enum values **must** match `BeDemo.Api.Models.UserRole` (**§12.1**).
- **`SeedPageTypesAsync`** — `PageTypes` with **`Index`**: `home`, `static`, `wall` (timestamps UTC).
- **`SeedComponentTypesAsync`** — fixed **`Id`** / **`Index`** / **`Name`** aligned with `ComponentTypeId` and `ComponentTypeIndex` (**§12.2**).
- **`SeedDisplayModesAsync`** — fixed **`Id`** / **`Index`** / **`Name`** aligned with `DisplayModeId` and `DisplayModeIndex` (**§12.3**).
- **`SeedFacesAndPagesAsync`** — faces **`public`**, **`basic`**, **`koncept`**, **`admin`** (admin index = `FaceScopeConstants.AdminFaceIndex` = `"admin"`), with **`Pages`** rows tied to `PageTypes`. **`GradientSettings`** text JSON from `FaceGradientPresets.JsonForFaceIndex(...)` (**§12.4**).
- **`SeedOAuthClientsAsync`** — client id **`be-demo-client`**, plaintext demo secret **`be-demo-secret-very-strong-key`** (must match `OAuth2:ClientSecret` / test token helpers), stored as **`PasswordHasher<OAuthClient>`** hash in **`OAuthClients.SecretHash`**.

### 2.5 Heavy / identity-bound seed (default: keep on backend)

- **`DatabaseInitializer`** — `admin@admin.com` + `UserManager.CreateAsync` + temporary removal of password validators + **`UserProfile`**.
- **`SeedUsersAsync`** — `admin1@demo.com`, `admin2@demo.com`, `user01@demo.com`–`user30@demo.com`, passwords **`admin`** / **`user123`**, **`UserProfile`**, **`UserFaceProfile`**, **`UserFaceRole`** for **every** face at seed time. Rules: demo admins → **FACE_ADMIN** on the **admin** face index, **FACE_HOST** on other faces; regular users → **FACE_USER** if present else **FACE_HOST**.
- **`SeedOAuthClientsAsync`** — unless **`SecretHash`** is **frozen** in SQL (export + doc regeneration), keep in C#.

### 2.6 Demo grid + maintenance (split decision)

- **`SeedFaceGridContentAsync`** — for each user with **`Email` ending with `@demo.com`** (case-sensitive match in SQL: seeded emails are lowercase) × each **`Faces`** row: ensure **`GridDemoItemsPerUserPerFace` = 5** of: `FaceWallTickets`, `Albums` + `AlbumFaces`, `Blogs` + `BlogImages`, `Reels` + `ReelFaces`, `Stories` (`Published`, long `ExpiresAt`) + `StoryFaces` + **two** `StoryImages` per new story, `FaceChatRooms`. **`admin@admin.com`** is **not** `@demo.com` → **no** grid rows for that account from this method.
- **Picsum URL seeds:** blog/story URLs use **`userId.GetHashCode()`** where **`userId`** is **`string`**. In modern .NET, **`string.GetHashCode()` is randomized per process** → URLs **change across restarts**. SQL or refactored C# should use **deterministic** slug material (e.g. `md5(creator_id || ':' || face_id::text || ':' || i::text)` truncated, or `encode(digest(...),'hex')` prefix) — **do not** rely on `GetHashCode()` for reproducible seeds.
- **`NormalizeDemoUserFaceRolesForProfileGridAsync`** — for users with email like `user**@demo.com`, updates **`UserFaceRoles`** from **FACE_HOST** → **FACE_USER** where applicable (grid directory behaviour).
- **`EnsureSecondStoryImageForDemoStoriesAsync`** — inserts a second **`StoryImages`** row only when a story has **exactly one** image (legacy). **New** stories created in `EnsureStoriesForUserFaceAsync` already get **two** images.
- **`ReactivateExpiredStoriesForStartupAsync` / `ReactivateDemoExpiredStoriesAsync`** — updates **`Stories`** by state/time; in **Production-like** env, restricts to creators in the demo user id list. **Operational / time-dependent** → keep in **backend** (or job), not static SQL.

---

## 3. Target architecture

### 3.1 Source of truth

| Concern                                                                                   | Owner                                                                                         |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Table DDL, indexes, FKs                                                                   | EF migrations in **`many_faces_backend`**                                                     |
| Reference + demo **static** rows (roles, types, faces, pages, optional bulk demo content) | **`many_faces_database/seed/sql/`** (or similar)                                              |
| Identity user creation, password hashes, security stamps                                  | **`many_faces_backend`** (or exported once into SQL with a documented regeneration procedure) |
| Startup “repair” jobs (expired demo stories)                                              | **`many_faces_backend`**                                                                      |

### 3.2 Suggested SQL file layout (in `many_faces_database`)

Use **ordered** prefixes so operators and CI always apply the same sequence:

1. `010_reference_user_roles.sql`
2. `020_reference_page_types.sql`
3. `030_reference_component_types.sql`
4. `040_reference_display_modes.sql`
5. `050_faces_and_pages.sql` (literal **`GradientSettings`** JSON — see **§12.4**)
6. `060_oauth_clients.sql` (**optional** — only if **`SecretHash`** is a **frozen** exported value; else keep **`SeedOAuthClientsAsync`** in API only)
7. `070_demo_users_profiles_face_links.sql` (**optional / advanced** — precomputed **`AspNetUsers`** + app tables; see **§5** and **§12.5**)
8. `080_demo_grid_content.sql` (**optional** — large; depends on §7 or runs after API user seed)

**Idempotency:** Prefer `INSERT … ON CONFLICT DO NOTHING` where a **unique index** exists; else `INSERT … SELECT … WHERE NOT EXISTS (SELECT 1 FROM …)`. Derive conflict targets from **`ApplicationDbContextModelSnapshot.cs`** (unique indexes per table).

**PostgreSQL identifiers:** EF maps to **PascalCase plural** table names (`Albums`, `Faces`, `UserRoles`, `OAuthClients`, …). Identity tables: **`AspNetUsers`**, **`AspNetRoles`**, … (see snapshot). Use **double-quoted** identifiers only when case/special chars require it; default unquoted lower-case in Postgres would **not** match `"Albums"` if the table was created quoted — verify actual names in snapshot / `\dt` in psql.

---

## 4. Execution order (critical)

### 4.1 Why not `docker-entrypoint-initdb.d` alone

Postgres **`docker-entrypoint-initdb.d`** scripts run **only on first cluster init** (empty data directory) and **before** any application has run **EF migrations**. BeDemo app tables (`Faces`, `Pages`, …) **do not exist** yet. Therefore **all BeDemo seed SQL must run after migrations**, via **`psql`** from the host (or `docker exec` into Postgres **after** migrate), not as the sole init strategy for app data.

### 4.2 Demo stack: canonical connection parameters

Aligned with **`many_faces_database/README.md`** (adjust if compose changes):

| Parameter | Value (host → Postgres container)           |
| --------- | ------------------------------------------- |
| Host      | `localhost` (from dev machine)              |
| Port      | **`54320`** (maps to 5432 inside container) |
| Database  | **`bedemo`**                                |
| User      | **`bedemo_user`**                           |
| Password  | **`bedemo_password`**                       |

**ADO.NET / backend:**

`Host=localhost;Port=54320;Database=bedemo;Username=bedemo_user;Password=bedemo_password`

**libpq / `psql` URI (`DATABASE_URL` style):**

`postgresql://bedemo_user:bedemo_password@localhost:54320/bedemo`

**`psql` individual flags (equivalent):**

`psql -h localhost -p 54320 -U bedemo_user -d bedemo`  
(Password via **`PGPASSWORD=bedemo_password`** or `.pgpass`; **`PGSSLMODE=disable`** if your client insists on SSL for localhost.)

**From inside the `postgres` container** (same compose network, DB on localhost:5432):

`psql -h localhost -p 5432 -U bedemo_user -d bedemo` with password **`bedemo_password`**.

### 4.3 Recommended local workflows

**Workflow A — First-time dev (simplest mental model):**

1. `cd many_faces_database && ./scripts/start-db.sh` (or `docker compose up -d`).
2. Run migrations once: start backend briefly, or `dotnet ef database update` from **`many_faces_backend`** with the connection string above (**§11.2**).
3. Run **`psql`** against **`seed/sql/*.sql`** in order (**§11.3**).
4. Start backend with **configuration that skips** C# reference seeding already covered by SQL (feature flag / `Seed:*` — implement explicitly). **`InitializeDatabase`** must still create **`admin@admin.com`** unless you also moved that to SQL (not default).

**Workflow B — Scripted “migrate then seed” (CI or wrapper script):**

1. Start Postgres.
2. `dotnet ef database update --project … --connection "…"` (or a one-shot `dotnet run -- migrate-only` if you add such a command).
3. `psql` all seed files with **`ON_ERROR_STOP=1`**.
4. Start long-running API with SQL reference paths disabled in C#.

**Chicken-and-egg on very first boot:** Today’s **`Program.cs`** calls **`InitializeDatabase`** then **`SeedAsync`** in one process. If SQL is **manual** between runs, the **first** API start may still run **`SeedAsync`** before you had a chance to `psql` — plan either: (1) two-step doc (“first start applies schema only, stop, psql, second start”), or (2) **`seed-after-migrate.sh`** invoked by dev compose / Makefile before `dotnet run`, or (3) env var **`SKIP_REFERENCE_SEED=1`** until SQL applied. The implementing agent must pick one and document it in **`many_faces_database/README.md`**.

### 4.4 After SQL: avoid duplicate inserts

If reference data is already in SQL, **`SeedAsync`** / **`SeedDataOnlyAsync`** must **not** re-insert the same unique keys. Use explicit configuration (preferred) or guarded early-return per table. **`Testing`** should keep **`SeedDataOnlyAsync`** filling in-memory DB **without** requiring SQL files unless you add a dedicated Postgres integration project.

---

## 5. What to move to SQL vs keep in C# (decision matrix)

Legend: **SQL** = recommended for `many_faces_database`; **API** = keep in `many_faces_backend`; **Either** = product choice.

| Data / behaviour                                                | Move to SQL?         | Notes                                                                                                    |
| --------------------------------------------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------- |
| `UserRole` reference rows                                       | **SQL**              | Match **`Name`** + **`Scope`** exactly (**§12.1**).                                                      |
| `PageType`, `ComponentType`, `DisplayMode`                      | **SQL**              | Fixed IDs must match enums (**§12.2**, **§12.3**).                                                       |
| `Face` + `Page` for demo tenants                                | **SQL**              | **`Faces.Index`** unique; **`Pages`** FK to `Faces` / `PageTypes`. **`GradientSettings`** per **§12.4**. |
| `OAuthClients` demo row                                         | **Either**           | Prefer **API** unless **`SecretHash`** exported + regen doc (**§13**).                                   |
| `admin@admin.com` (super admin bootstrap)                       | **API**              | Identity + validators; **`UserRoleId`** = **SUPER_ADMIN** row.                                           |
| Demo users `admin1/2@demo.com`, `userNN@demo.com`               | **API** (default)    | **SQL** only with full **`AspNetUsers`** + app columns (**§12.5**).                                      |
| `UserProfile`, `UserFaceProfile`, `UserFaceRole` for demo users | **SQL** if users SQL | Else stays with **API**.                                                                                 |
| Bulk grid: wall, albums, blogs, reels, stories, chats           | **SQL** (max gain)   | After users exist; deterministic media URL seeds (**§2.6**).                                             |
| `NormalizeDemoUserFaceRolesForProfileGridAsync`                 | **SQL**              | `UPDATE` **`UserFaceRoles`** joining **`AspNetUsers`**, **`UserRoles`**.                                 |
| `EnsureSecondStoryImageForDemoStoriesAsync`                     | **Either**           | Legacy-only; optional SQL or omit after full volume reset.                                               |
| `ReactivateDemoExpiredStoriesAsync` / startup reactivation      | **API**              | Time + environment dependent.                                                                            |

**If seeding `AspNetUsers` via SQL:** Populate Identity-required columns and extended **`ApplicationUser`** columns exactly as in **`ApplicationDbContextModelSnapshot`** for entity **`ApplicationUser`** (`FirstName`, `LastName`, `CreatedAt`, `UserRoleId`, `AccessTokenVersion`, …). Bearer **global role** claims come from **`UserRoleId`** → **`UserRoles`**, not from **`AspNetUserRoles`** in this codebase — keep SQL consistent with that design.

---

## 6. Backend changes after SQL exists (high level)

When SQL seeds cover a subset of `DatabaseSeeder`:

- **Gate or remove** the corresponding C# paths. Prefer **`IConfiguration`** keys, e.g. `Seed:ApplyReferenceDataFromApi` default `false` when `Seed:AssumeExternalSqlReferenceApplied` is `true` — exact names are up to implementer; document in README.
- **Single `MigrateAsync`:** remove duplicate from `SeedAsync` once initializer (or a single entry point) owns migration.
- **`Testing` / in-memory:** keep **`SeedDataOnlyAsync`** (or equivalent) so **`CustomWebApplicationFactory`** needs **no** Postgres. **Do not** require `psql` for `dotnet test` unless adding a separate optional test suite.
- **`Program.cs` (non-Testing) today:** `InitializeAsync` → **`SeedAsync`** → **`SeedUsersAsync`** + **`SeedFaceGridContentAsync`** → **`ReactivateExpiredStoriesForStartupAsync`**. Target after SQL: **migrate once** → **SQL reference files** (external or scripted) → **C# for Identity bootstrap + demo users + grid + time jobs**, with **no** double-insert on unique constraints.

---

## 7. Verification checklist

- [ ] Fresh volume: `docker compose down -v` → start DB → migrate → `psql` all seed files → API starts **without** duplicate key violations on reference tables.
- [ ] Portal loads faces/pages; login **`admin@admin.com`** / demo users per chosen split.
- [ ] OAuth password grant / tests: client **`be-demo-client`** + secret **`be-demo-secret-very-strong-key`** still work if OAuth row is SQL-sourced (hash must verify).
- [ ] `dotnet test` on **`BeDemo.Api.Tests`** passes; **`Testing`** startup path unchanged or consciously extended.
- [ ] CI: if integration tests use **in-memory** factory only, **do not** require seed SQL in default pipeline; document optional Postgres+SQL job separately.
- [ ] **`many_faces_database/README.md`**: connection variants (**§11**), order migrate → psql → API, wipe instructions, “when EF model changes, update SQL files”.

---

## 8. Deliverables (for the implementing agent)

1. Directory **`many_faces_database/seed/sql/`** (or agreed name) with ordered idempotent `.sql` per **§3.2** (minimum: all **SQL** rows in **§5** that you adopt).
2. **`many_faces_database/scripts/seed-after-migrate.sh`** (recommended): exports **`PG*`** or **`DATABASE_URL`**, runs `psql -v ON_ERROR_STOP=1 -f` for each file in order; `chmod +x`; non-zero exit on first failure.
3. Backend: trim **`DatabaseSeeder`**, **`Program.cs`**, **`InitializeDatabase`** per **§6**; add config flags as needed.
4. Update **`many_faces_database/README.md`** with **§11**-level detail (avoid duplicating only in this prompt — README is the operator source of truth).

---

## 9. Explicit out-of-scope

- Moving **EF migrations** into the database repo.
- Generating SQL from **production** dumps for this task (unless product explicitly requests).
- Changing password hashing algorithms or Identity schema.
- Seeding **`AspNetUserClaims`**, **`AspNetUserLogins`**, **`AspNetUserTokens`** unless product requires (demo does not use external logins today).

---

## 10. File map (quick reference)

| File                                                                            | Role                                                    |
| ------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `many_faces_backend/BeDemo.Api/Program.cs`                                      | Startup pipeline for DB init + seeding.                 |
| `many_faces_backend/BeDemo.Api/Scripts/DatabaseSeeder.cs`                       | Main seeder logic to split.                             |
| `many_faces_backend/BeDemo.Api/Scripts/InitializeDatabase.cs`                   | Migrate + bootstrap `admin@admin.com` + ERD optional.   |
| `many_faces_backend/BeDemo.Api/Data/ApplicationDbContext.cs`                    | Fluent API: indexes, FKs, column types.                 |
| `many_faces_backend/BeDemo.Api/Migrations/ApplicationDbContextModelSnapshot.cs` | **Authoritative** table/column/index names for raw SQL. |
| `many_faces_backend/BeDemo.Api/Models/UserRole.cs`                              | Global + face role **string** constants.                |
| `many_faces_backend/BeDemo.Api/Models/ComponentType.cs`                         | `ComponentTypeId` / `ComponentTypeIndex`.               |
| `many_faces_backend/BeDemo.Api/Models/DisplayMode.cs`                           | `DisplayModeId` / `DisplayModeIndex`.                   |
| `many_faces_backend/BeDemo.Api/Models/ApplicationUser.cs`                       | Extended Identity user columns for SQL user seed.       |
| `many_faces_backend/BeDemo.Api/Utils/FaceGradientPresets.cs`                    | Gradient JSON for known face indices + hash fallback.   |
| `many_faces_backend/BeDemo.Api/Utils/FaceScopeConstants.cs`                     | Admin face index (`admin`).                             |
| `many_faces_backend/BeDemo.Api.Tests/IntegrationTestSeed.cs`                    | Test-only users + OAuth token helpers.                  |
| `many_faces_backend/BeDemo.Api.Tests/TestHelpers.cs`                            | `CustomWebApplicationFactory` wiring.                   |
| `many_faces_database/docker-compose.yml`                                        | Postgres + pgAdmin.                                     |
| `many_faces_database/scripts/clear-db.sh`                                       | Wipe volume / reset instructions coordination.          |

---

## 11. Appendix — Copy-paste connection and `psql`

### 11.1 Environment variables (host machine)

```bash
export PGHOST=localhost
export PGPORT=54320
export PGUSER=bedemo_user
export PGPASSWORD=bedemo_password
export PGDATABASE=bedemo
# optional if psql complains about SSL on localhost:
export PGSSLMODE=disable
```

Or a single URI:

```bash
export DATABASE_URL='postgresql://bedemo_user:bedemo_password@localhost:54320/bedemo'
```

### 11.2 One-shot EF migrate (from repo root; adjust paths if monorepo layout differs)

```bash
cd many_faces_backend/BeDemo.Api
dotnet ef database update --connection "Host=localhost;Port=54320;Database=bedemo;Username=bedemo_user;Password=bedemo_password"
```

(Requires **`dotnet-ef`** tool and design-time `DbContext` factory if the project uses them — follow existing backend docs if present.)

### 11.3 Apply all seed SQL files in lexicographic order

**Using `PG*` env vars:**

```bash
cd many_faces_database
for f in seed/sql/*.sql; do
  echo "==> $f"
  psql -v ON_ERROR_STOP=1 -f "$f" || exit 1
done
```

**Using URI:**

```bash
cd many_faces_database
for f in seed/sql/*.sql; do
  echo "==> $f"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f" || exit 1
done
```

**From inside the `postgres` container** (after migrate has been applied at least once from the host so the DB exists):

```bash
docker exec -i postgres-dev psql -U bedemo_user -d bedemo -v ON_ERROR_STOP=1 < seed/sql/010_reference_user_roles.sql
```

(Repeat per file; or mount `seed/sql` into the container — prefer host `psql` for simplicity.)

---

## 12. Appendix — Reference constants (must match C#)

### 12.1 `UserRoles.Name` and `RoleScope`

**Global (`Scope = 0` / `Global`):** `SUPER_ADMIN`, `ADMIN`, `USER`, `HOST`  
**Face (`Scope = 1` / `Face`):** `FACE_ADMIN`, `FACE_USER`, `INZERENT`, `SUBSCRIBER`, `FACE_HOST`

Descriptions in SQL should match or exceed current C# strings for operator clarity (optional for machine behaviour).

### 12.2 `ComponentTypes` (fixed IDs)

| Id  | Index (`Index`) | Name         |
| --- | --------------- | ------------ |
| 1   | `ad`            | Ad           |
| 2   | `album`         | Album        |
| 3   | `blog`          | Blog         |
| 4   | `chatRoom`      | Chat Room    |
| 5   | `userProfile`   | User Profile |
| 6   | `story`         | Story        |
| 7   | `reel`          | Reel         |

### 12.3 `DisplayModes` (fixed IDs)

| Id  | Index      | Name     |
| --- | ---------- | -------- |
| 1   | `item`     | Item     |
| 2   | `grid`     | Grid     |
| 3   | `carousel` | Carousel |

### 12.4 `Faces.GradientSettings` JSON (`FaceGradientPresets`)

Known indices (from `FaceGradientPresets.JsonForFaceIndex` switch). **`admin`** uses the **default branch** (`PresetFromHash`); literal below verified against the same algorithm (`StableStringHash` over `"admin"`).

**`public`:**

```json
{
  "type": "linear",
  "colors": ["#6366f1", "#06b6d4", "#a78bfa"],
  "angle": 118,
  "animation": "rotate",
  "animationSpeed": 16
}
```

**`basic`:**

```json
{
  "type": "linear",
  "colors": ["#047857", "#34d399", "#065f46"],
  "angle": 52,
  "animation": "shift",
  "animationSpeed": 11
}
```

**`koncept`:**

```json
{
  "type": "linear",
  "colors": ["#ea580c", "#facc15", "#dc2626"],
  "angle": 195,
  "animation": "pulse",
  "animationSpeed": 4.5
}
```

**`admin`** (hash fallback for key `admin`; matches `FaceGradientPresets.PresetFromHash` with 32-bit `StableStringHash`):

```json
{
  "type": "linear",
  "colors": ["#14b8a6", "#84cc16", "#0d9488"],
  "angle": 72,
  "animation": "pulse",
  "animationSpeed": 20
}
```

If the C# algorithm for unknown keys changes, **regenerate** this JSON from code or from a DB row after migration.

### 12.5 `AspNetUsers` / `ApplicationUser` (only if doing advanced SQL user seed)

Minimum Identity columns typically include: **`Id`**, **`UserName`**, **`NormalizedUserName`**, **`Email`**, **`NormalizedEmail`**, **`EmailConfirmed`**, **`PasswordHash`**, **`SecurityStamp`**, **`ConcurrencyStamp`**, **`PhoneNumberConfirmed`**, **`TwoFactorEnabled`**, **`LockoutEnabled`**, **`AccessFailedCount`**, plus extended: **`FirstName`**, **`LastName`**, **`CreatedAt`**, **`UserRoleId`**, **`AccessTokenVersion`**.  
**Regenerate `PasswordHash`** with the same ASP.NET Identity version/options as the running API; do not invent hashes. **`NormalizedUserName`** / **`NormalizedEmail`** must match Identity’s **upper-invariant** normalisation rules.

---

## 13. Appendix — OAuth `SecretHash` export (optional SQL path)

1. Run the app once with **`SeedOAuthClientsAsync`** so `OAuthClients` contains **`be-demo-client`**.
2. Query: `SELECT "ClientId", "SecretHash" FROM "OAuthClients" WHERE "ClientId" = 'be-demo-client';`
3. Paste hash into **`060_oauth_clients.sql`** with idempotent insert and a comment: plaintext secret **`be-demo-secret-very-strong-key`**, regeneration date, Identity hash format version if applicable.
4. Remove or gate C# insert for the same `ClientId`.

---

Paste this entire file into an agent chat to execute the migration of seeds with the split above.
