# Troubleshooting (local development)

## Submodule / clone issues

- **Empty submodule dirs** — run `git submodule update --init --recursive` (see [`git-submodules.md`](./git-submodules.md)).

## HTTPS and certificates

- **Browser blocks API** — trust dev CA / PFX; see [`dev-https.md`](./dev-https.md).
- **`dotnet dev-certs`** vs Docker TLS confusion — prefer the guide’s matrix for host vs container API.

## Database / Redis

- **Connection refused** — start `many_faces_database` / `many_faces_redis` compose stacks; verify connection strings.
- **Stale schema** — apply EF migrations ([`efcore-migrations-and-seeding.md`](./efcore-migrations-and-seeding.md)).

## Face prefix / 401 / 403

- **Wrong face in URL** — public vs private vs admin prefixes behave differently; re-read [`authentication-and-sessions.md`](./authentication-and-sessions.md) and backend routing sections in [`many_faces_backend/README.md`](../../many_faces_backend/README.md).

## OpenAPI / client drift

- **`generate:api` fails** — backend not running or wrong port; see [`openapi-client-generation.md`](./openapi-client-generation.md).

## AI / gRPC

- **Import errors in `many_faces_ai`** — regenerate protos (`./scripts/generate_proto.sh`); see [`many_faces_ai/README.md`](../../many_faces_ai/README.md).

## Optional Elasticsearch / search-worker (`many_faces_elastic`)

- **Nothing listening on `59200` / `59202`** — start the stack with `ENABLE_ELASTICSEARCH=1 ./scripts/start-all-dev.sh` (or `many_faces_elastic/scripts/start-elasticsearch.sh`) and wait until both `elasticsearch-dev` and `search-worker-dev` exist (`docker ps`).
- **Backend cannot reach the worker** — containers must be on `many_faces_main_dev-network`; use Docker DNS names `http://search-worker-dev:50052` from `be-demo-dev`, not `localhost`. Full checklist: [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md).

## Still stuck

- Capture **Seq** + **browser network** + **API logs** in one timeline ([`observability-seq-and-logs.md`](./observability-seq-and-logs.md)).
