# Docker and Compose (local stack)

This guide ties together the **monorepo** compose file and per-service Docker READMEs. Commands assume repository root **`many_faces_main`**.

## Entry compose

- **`docker-compose.dev.yml`** (repo root) — primary local orchestration: API, SPAs, PostgreSQL, Redis, logger UI, AI, etc. Exact services and ports drift with commits; compare the file and [`dev-https.md`](./dev-https.md).

## Submodule stacks

| Area | Submodule | Typical role |
| ---- | --------- | ------------- |
| PostgreSQL | `many_faces_database/` | Dev database container(s); see [`many_faces_database/README.md`](../../many_faces_database/README.md). |
| Redis | `many_faces_redis/` | Cache / job queue infra; see [`many_faces_redis/README.md`](../../many_faces_redis/README.md) and [`redis-subrepo.md`](../readmes/redis-subrepo.md). |
| Search index (optional) | `many_faces_elastic/` | Elasticsearch + **Go search-worker** (gRPC); backend talks to the worker only — see [`elasticsearch-search-features-overview.md`](./elasticsearch-search-features-overview.md), [`many_faces_elastic/README.md`](../../many_faces_elastic/README.md), [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md), and [`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md). |
| Push / FCM (optional, skeleton) | `many_faces_push/` | Future **Go gRPC** FCM worker; submodule is a **shell** until wired — see [`many_faces_push/README.md`](../../many_faces_push/README.md) and [`push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md`](../prompts/push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md). |
| Logs UI | `many_faces_logger/` | Dozzle / log viewing; see [`many_faces_logger/README.md`](../../many_faces_logger/README.md). |

## Scripts

Aggregated lifecycle scripts (`ci-local.sh`, `build-all.sh`, …) are documented in [`development.md`](./development.md) (*Monorepo scripts*).

## Related

- [`dev-https.md`](./dev-https.md) — TLS, ports, macOS PFX notes.
- [`elasticsearch-search-features-overview.md`](./elasticsearch-search-features-overview.md) — optional search stack: capabilities, TLS/mTLS, smoke, CI, tests.
- [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md) — optional Elasticsearch + search-worker, `ENABLE_ELASTICSEARCH`, gRPC env for the API.
- [`troubleshooting-local-dev.md`](./troubleshooting-local-dev.md) — when containers fail health checks.
