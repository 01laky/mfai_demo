# Redis workers and queues

Redis is optional at runtime for **`many_faces_backend`**, but several features assume a **queue** when enabled.

## Components (conceptual)

- **`RedisJobQueue`** — enqueue background work (job type + payload).
- **`RedisJobWorkerService`** — consumes jobs and runs domain handlers (logging, retries depend on implementation).

## Known job families (high level)

- **Content AI review** — e.g. `content.ai-review` pipeline tied to user-generated albums/blogs/reels (`ReviewContent` gRPC). Deep dive: [`ai-assisted-content-approval.md`](./ai-assisted-content-approval.md).
- **Story publish scheduling** — deferred publish at `scheduledPublishAt` (see [`api-oauth-stories-curl.md`](./api-oauth-stories-curl.md) + [`STORIES_API.md`](../../many_faces_backend/STORIES_API.md)).
- **Wall tickets** — see [`wall-tickets.md`](./wall-tickets.md).

## Local infra

- **`many_faces_redis/`** submodule — compose + README.
- Extended narrative: [`redis-subrepo.md`](../readmes/redis-subrepo.md).

## Related

- [`docker-and-compose.md`](./docker-and-compose.md)
- [`observability-seq-and-logs.md`](./observability-seq-and-logs.md) — correlate worker logs with Seq.
