# Testing and CI matrix

## Monorepo CI (parent repo)

- Workflow: **`.github/workflows/ci.yml`** at `many_faces_main` root.
- Submodule-only commits still trigger validation when the parent pipeline is configured to test the checked-in tree (see [`development.md`](./development.md)).

## Local aggregate scripts

| Script | Role |
| ------ | ---- |
| `scripts/ci-local.sh` | Lint → build → test (optional Cypress skip). |
| `scripts/lint-all.sh` | Cross-repo lint/format gates. |
| `scripts/test-all.sh` | Backend + SPA tests + mobile + AI checks. |

Details and edge cases: [`development.md`](./development.md) (*Monorepo scripts*).

## Per technology

| Stack | Location | Typical commands |
| ----- | -------- | ------------------ |
| .NET | `many_faces_backend/` | `dotnet test`, `dotnet format` |
| Go (search-worker) | `many_faces_elastic/` | `go test ./...`, `go vet ./...` (also run from root `scripts/test-all.sh` when `go` is on `PATH`) |
| React | `many_faces_portal/`, `many_faces_admin/` | `yarn test`, `yarn validate`, `yarn lint` |
| Expo | `many_faces_mobile/` | `yarn test`, `./scripts/test.sh` (see mobile guide) |
| Python AI | `many_faces_ai/` | `pytest`, Ruff (`./scripts/lint.sh`) |

## Related

- [`mobile-expo-development.md`](./mobile-expo-development.md)
- [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md)
- [`unit-test-gap-fill-agent-prompt.md`](../prompts/unit-test-gap-fill-agent-prompt.md)
