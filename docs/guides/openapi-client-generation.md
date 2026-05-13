# OpenAPI client generation (portal + admin)

Typed HTTP clients for **`many_faces_portal`** and **`many_faces_admin`** are generated from the backend **Swagger** document.

## Prerequisite

Run **`many_faces_backend`** so **`http://localhost:8000/swagger/v1/swagger.json`** is reachable (or adjust the URL in `package.json` to match your port / HTTPS setup — see [`dev-https.md`](./dev-https.md)).

## Commands

From each SPA root:

```bash
yarn generate:api
```

Implementation (pinned in each repo’s `package.json`): downloads `swagger.json`, then runs **`openapi-typescript-codegen`** into `src/api/` (axios client, options, union types).

## When to regenerate

- After **controller / DTO** changes that affect the public HTTP contract.
- After bumping the backend submodule in the monorepo **before** merging FE changes that depend on new operations.

## Verification

- `yarn tsc --noEmit` / `yarn validate` in the SPA.
- Prefer small, reviewable diffs in `src/api/` (regenerate in isolation when possible).

## Related

- [`submodule-bump-and-release-checklist.md`](./submodule-bump-and-release-checklist.md)
- Backend [`README.md`](../../many_faces_backend/README.md) (OpenAPI / Swagger mentions).
