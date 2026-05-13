# Elasticsearch and Go search-worker — local development

This guide explains how the **optional** search stack fits the Many Faces monorepo: **Elasticsearch** for a read-optimized index and a colocated **Go gRPC search-worker** in `many_faces_elastic/`. **PostgreSQL** remains authoritative; browsers and mobile apps never talk to Elasticsearch or the worker directly.

## Ports and DNS

| Surface | Host (your laptop) | Inside `many_faces_main_dev-network` | Notes |
| ------- | ------------------- | ------------------------------------ | ----- |
| Elasticsearch HTTP | `localhost:59200` → container `9200` | `elasticsearch-dev:9200` (after `docker network connect`) | Official Elastic image; dev disables security — **not** a production pattern. |
| Search worker gRPC | `localhost:59202` → container `50052` | `search-worker-dev:50052` | Plaintext HTTP/2 (h2c) for v1 dev only. |

Compose project in `many_faces_elastic/docker-compose.yml` uses the **service** hostname `elasticsearch` for sibling containers; the **container_name** `elasticsearch-dev` is what you see in `docker ps` and what the root dev script attaches to the monorepo network.

## Enabling the stack

1. From the monorepo root, run with the flag so both Elasticsearch and the worker start:

   ```bash
   ENABLE_ELASTICSEARCH=1 ./scripts/start-all-dev.sh
   ```

2. The script starts `many_faces_elastic` via `./many_faces_elastic/scripts/start-elasticsearch.sh` (which runs `docker compose up -d`), then attaches **`elasticsearch-dev`** and **`search-worker-dev`** to **`many_faces_main_dev-network`** so the backend container can resolve them by name.

3. Configure the API (environment variables use double underscore for nested `Search` options):

   - `Search__Enabled=true`
   - `Search__WorkerGrpcUrl=http://search-worker-dev:50052`
   - `Search__WorkerAuthToken=<optional shared secret>` — must match `SEARCH_WORKER_EXPECTED_TOKEN` on the worker when that variable is set in `many_faces_elastic/.env` or compose.

When `Search__Enabled` is **false** (default in `appsettings.json`), **`dotnet test`** and local API runs do **not** require Docker search infra.

## Proto sync (single source of truth)

Canonical RPC definitions live under:

```text
many_faces_elastic/proto/manyfaces/search/v1/search.proto
```

- **Go worker:** generated stubs are committed under `many_faces_elastic/gen/manyfaces/search/v1/` (regenerate with `protoc` when the proto changes; Docker one-liner is documented in `many_faces_elastic/README.md`).
- **C# backend:** `Grpc.Tools` generates clients at build time from the same file via `BeDemo.Api.csproj` `<Protobuf Include="...many_faces_elastic/proto/...">`.

If you change the proto, update **both** outputs (Go files and any C# expectations) in the same change set so CI stays green.

## grpcurl smoke (optional)

With the worker published on `localhost:59202` and **no** token on the worker:

```bash
grpcurl -plaintext localhost:59202 list
grpcurl -plaintext localhost:59202 grpc.health.v1.Health/Check
grpcurl -plaintext -d '{"correlation_id":"smoke"}' localhost:59202 manyfaces.search.v1.SearchService/Ping
```

If `SEARCH_WORKER_EXPECTED_TOKEN` is set, add metadata:

```bash
grpcurl -plaintext -H "x-search-worker-token: YOUR_TOKEN" -d '{}' localhost:59202 manyfaces.search.v1.SearchService/Ping
```

## REST health check

From the **public** face prefix (no JWT), the backend exposes:

```http
GET /public/api/search/health
```

The JSON reports whether search is configured and whether the worker’s `Ping` saw Elasticsearch HTTP succeed **inside the worker network namespace** (not from the API process).

## Troubleshooting

- **`Unavailable` / connection refused from the API:** ensure `search-worker-dev` is on `many_faces_main_dev-network` (`docker network inspect many_faces_main_dev-network`) and that `Search__WorkerGrpcUrl` uses the Docker DNS name, not `localhost`, **from inside** `be-demo-dev`.
- **Unauthenticated from worker:** token mismatch — align `Search__WorkerAuthToken` and `SEARCH_WORKER_EXPECTED_TOKEN`, or clear both for trusted dev-only networks.
- **Elasticsearch yellow/red:** single-node dev is normal for a one-node cluster; see Elastic docs for production sizing and security.

## Related docs

- Submodule overview: [`many_faces_elastic/README.md`](../../many_faces_elastic/README.md)
- Compose orchestration: [`docker-and-compose.md`](./docker-and-compose.md)
- Agent checklist (scope / non-goals): [`docs/prompts/elasticsearch-search-infra-agent-prompt.md`](../prompts/elasticsearch-search-infra-agent-prompt.md)
- AI service and future gRPC client: [`many_faces_ai/docs/grpc-search-worker.md`](../../many_faces_ai/docs/grpc-search-worker.md)
