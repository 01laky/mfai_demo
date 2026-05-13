# Submodule bump and release checklist

Use this when a change **crosses repositories** (API + clients + optional AI proto).

## Order of work

1. **`many_faces_backend`** — merge API + EF + OpenAPI surface changes; ensure migrations and tests green.
2. **Regenerate OpenAPI clients** in **`many_faces_portal`** and **`many_faces_admin`** (`yarn generate:api`) — see [`openapi-client-generation.md`](./openapi-client-generation.md).
3. **`many_faces_ai`** — if `health.proto` / gRPC contracts changed: mirror proto, run `./scripts/generate_proto.sh`, update Python + tests.
4. **`many_faces_mobile`** — update REST clients / config parity as needed; see [`many_faces_mobile/docs/rest-parity-matrix.md`](../../many_faces_mobile/docs/rest-parity-matrix.md).
5. **Monorepo parent** — bump submodule SHAs in one commit (or stacked PRs), run `./scripts/ci-local.sh` or CI equivalent.

## Version and contract hygiene

- Prefer **additive** DTO fields first; breaking renames need coordinated major bumps across all clients.
- Document **feature flags** or config keys in backend `appsettings` + relevant SPA env samples.

## Related

- [`git-submodules.md`](./git-submodules.md)
- [`development.md`](./development.md)
