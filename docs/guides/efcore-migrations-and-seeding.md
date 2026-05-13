# EF Core migrations and seeding

## Migrations (backend)

- Migration C# files live under **`many_faces_backend/BeDemo.Api/Migrations/`**.
- From the backend project directory, use the standard **`dotnet ef`** workflow (tooling versions align with the repo’s global.json / SDK).
- Apply migrations against your local database URL (see **`many_faces_database`** compose + connection strings in appsettings / user secrets).

**Rule of thumb:** never hand-edit generated migration Designer files; add a new migration for model changes.

## Seeding and demo data

- Demo users, faces, and grid content are created via **`DatabaseSeeder`** (and related startup hooks). Passwords and roles for local dev are listed in [`local-dev-accounts.md`](./local-dev-accounts.md).

## Database container

- Reset / volume strategy is documented in [`many_faces_database/README.md`](../../many_faces_database/README.md).

## Related

- [`docker-and-compose.md`](./docker-and-compose.md)
- [`database-repo-sql-seeds-backend-split-agent-prompt.md`](../prompts/database-repo-sql-seeds-backend-split-agent-prompt.md) — if you split SQL seeds into a dedicated repo (agent spec).
