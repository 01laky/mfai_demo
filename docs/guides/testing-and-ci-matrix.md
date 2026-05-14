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
| Buf (shared `.proto`) | `many_faces_backend/many_faces_proto/proto/` (same tree in other consumers) | After full recursive submodule init: `cd many_faces_backend/many_faces_proto/proto && buf lint`. Breaking (PRs): same directory, `buf breaking --against "https://github.com/01laky/many_faces_proto.git#branch=main,subdir=proto"`. Parent CI job: **`many_faces_proto`** in **`.github/workflows/ci.yml`**. |
| .NET | `many_faces_backend/` | `dotnet test`, `dotnet format` |
| Go (search-worker) | `many_faces_elastic/` | `go test ./...`, `go vet ./...` (also from root `scripts/test-all.sh` when `go` is on `PATH`). TLS/mTLS transport helpers: `internal/grpccreds`. Optional Docker smoke: `many_faces_elastic/scripts/smoke-grpc-tls.sh` (see **`.github/workflows/ci.yml`** job `smoke_search_worker_grpc_tls` and [`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md), [`elasticsearch-search-features-overview.md`](./elasticsearch-search-features-overview.md)). |
| Go (`many_faces_push` push-worker) | `many_faces_push/` | `go test ./...`, `go vet ./...` (also from root `scripts/test-all.sh` when `go` is on `PATH`). TLS/mTLS: `internal/grpccreds`, optional Docker smoke `many_faces_push/scripts/smoke-grpc-tls.sh` (CI job `smoke_push_worker_grpc_tls`, [`push-grpc-tls-mtls.md`](./push-grpc-tls-mtls.md)). Local FCM: [`push-notifications-local-dev.md`](./push-notifications-local-dev.md); repo: [`many_faces_push/README.md`](../../many_faces_push/README.md). |
| Java (`many_faces_mailer` mailer-worker) | `many_faces_mailer/` | `./gradlew test` (CI job `java_many_faces_mailer`, compose checks `infra_many_faces_mailer`). Optional Docker TLS/mTLS smoke: `many_faces_mailer/scripts/smoke-grpc-tls.sh` (CI job `smoke_mailer_worker_grpc_tls`, [`mailer-grpc-tls-mtls.md`](./mailer-grpc-tls-mtls.md)). Dev + Mailpit: [`mailer-local-dev.md`](./mailer-local-dev.md); repo: [`many_faces_mailer/README.md`](../../many_faces_mailer/README.md). |
| React | `many_faces_portal/`, `many_faces_admin/` | `yarn test`, `yarn validate`, `yarn lint` |
| Expo | `many_faces_mobile/` | `yarn test`, `./scripts/test.sh` (see mobile guide) |
| Python AI | `many_faces_ai/` | `pytest`, Ruff (`./scripts/lint.sh`). gRPC stubs: `python -m grpc_tools.protoc -I many_faces_proto/proto --python_out=proto --grpc_python_out=proto health.proto` (from `many_faces_ai/` after `git submodule update --init --recursive`). |

## Related

- [`mobile-expo-development.md`](./mobile-expo-development.md)
- [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md)
- [`unit-test-gap-fill-agent-prompt.md`](../prompts/unit-test-gap-fill-agent-prompt.md)
