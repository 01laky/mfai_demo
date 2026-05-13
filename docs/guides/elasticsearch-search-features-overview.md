# Elasticsearch search stack — platform features (overview)

This guide summarizes **what the optional Elasticsearch + Go search-worker stack provides** in the Many Faces monorepo today: architecture, transport security, automated verification, and where to read next. **PostgreSQL remains the system of record**; Elasticsearch is a **read-optimized projection** for future full-text and faceted search.

## What ships in `many_faces_elastic`

| Piece | Responsibility |
| ----- | ---------------- |
| **Elasticsearch** (official Elastic image) | Stores the search index; HTTP API on port `9200` inside the compose project. |
| **search-worker** (Go, `cmd/search-worker`) | The **only** supported path for application Elasticsearch HTTP calls from Many Faces; exposes **gRPC** on `50052` inside the container. |
| **`proto/manyfaces/search/v1/search.proto`** | Canonical gRPC contract; C# client is generated in **`many_faces_backend`** at build time; Go stubs live under `gen/`. |

Clients (portal, admin, mobile) **never** talk to Elasticsearch or the worker; they call **`many_faces_backend`** REST APIs only.

## Local development defaults

- **Bring up the stack:** `ENABLE_ELASTICSEARCH=1 ./scripts/start-all-dev.sh` (from the monorepo root) or standalone scripts under **`many_faces_elastic/scripts/`**.
- **Host ports (typical):** Elasticsearch HTTP **`localhost:59200`**, worker gRPC **`localhost:59202`** (mapped to container `9200` / `50052`).
- **Backend → worker on Docker DNS:** e.g. `Search__WorkerGrpcUrl=http://search-worker-dev:50052` from **`be-demo-dev`** on **`many_faces_main_dev-network`**.
- **Optional shared secret:** `SEARCH_WORKER_EXPECTED_TOKEN` on the worker and matching **`Search__WorkerAuthToken`** on the API (metadata `x-search-worker-token` on application RPCs; gRPC health is exempt).

Step-by-step: [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md).

## Transport security (TLS / mTLS)

Production-style deployments can terminate **TLS** on the worker gRPC listener and optionally require **mutual TLS**:

- **Worker:** `SEARCH_WORKER_GRPC_TLS_CERT_FILE`, `SEARCH_WORKER_GRPC_TLS_KEY_FILE`, optional `SEARCH_WORKER_GRPC_MTLS_CLIENT_CA_FILE`.
- **API:** `Search__WorkerGrpcUrl=https://…` plus optional `Search__WorkerTlsServerCaPath`, `Search__WorkerTlsClientCertPath`, `Search__WorkerTlsClientKeyPath`, `Search__WorkerGrpcTlsServerName`.

Cleartext **`http://`** remains the default for trusted local Docker networks; **`Program.cs`** enables `Http2UnencryptedSupport` only when the configured URL uses `http://`.

Full matrix, `openssl` example, and **grpcurl** snippets: [`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md).

## Automated verification

| Layer | What runs |
| ----- | --------- |
| **Go** (`many_faces_elastic`) | `go test ./...` — includes `internal/grpccreds` (TLS credential loading, generated cert fixtures) and server tests. |
| **.NET** (`many_faces_backend`) | `SearchWorkerGrpcProbeOptionsTests` — fast validation of TLS option combinations and certificate callback edge cases. |
| **Optional Docker TLS smoke** | **`many_faces_elastic/scripts/smoke-grpc-tls.sh`** — OpenSSL demo CA + server + client PEMs, **`docker-compose.tls-smoke.yml`** (host ports **59210** / **59211**), **grpcurl** `Ping`, then **`SearchWorkerTlsEndToEndSmokeTests`** when `SEARCH_TLS_SMOKE=1`. |
| **CI (monorepo)** | **`.github/workflows/ci.yml`**: `infra_many_faces_elastic` validates both **`docker-compose.yml`** and **`docker-compose.tls-smoke.yml`** (`SEARCH_TLS_SMOKE_CERT_DIR=/tmp` for compose config only); job **`smoke_search_worker_grpc_tls`** runs the smoke script (Docker + grpcurl + .NET). |
| **Aggregate local tests** | Root **`scripts/test-all.sh`**: set **`RUN_SEARCH_TLS_SMOKE=1`** after `go test` to run the same smoke (requires Docker, OpenSSL, grpcurl, dotnet on `PATH`). |

## Health and observability

- **Backend REST probe:** `GET /{face-prefix}/api/search/health` (e.g. public face) reports whether search is configured and whether the worker’s **`Ping`** RPC saw Elasticsearch succeed **inside the worker** network namespace.
- **Worker logs:** JSON to stdout (Docker-friendly); startup logs **gRPC** mode as `plaintext`, `tls`, or `mtls`.

## Submodule and code layout

- **Submodule path:** `many_faces_elastic/` — canonical remote **`many_faces_elastic`** on GitHub.
- **Key paths:** `docker-compose.yml`, **`docker-compose.tls-smoke.yml`**, `Dockerfile.search-worker`, `cmd/search-worker`, `internal/grpccreds`, `internal/server`, `proto/`, `scripts/smoke-grpc-tls.sh`, `.env.example`.

Submodule README: [`many_faces_elastic/README.md`](../../many_faces_elastic/README.md).

## Related documentation

- [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md) — ports, `ENABLE_ELASTICSEARCH`, env vars, grpcurl plaintext smoke.
- [`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md) — TLS/mTLS operator reference.
- [`docker-and-compose.md`](./docker-and-compose.md) — how the elastic stack attaches to the root dev network.
- [`testing-and-ci-matrix.md`](./testing-and-ci-matrix.md) — commands and CI job names.
- [`docs/prompts/elasticsearch-search-infra-agent-prompt.md`](../prompts/elasticsearch-search-infra-agent-prompt.md) — agent-facing roadmap and scope.
