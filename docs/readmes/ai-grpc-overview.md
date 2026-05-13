# AI gRPC service — overview (`many_faces_ai`)

Narrative companion to **[`many_faces_ai/README.md`](../../many_faces_ai/README.md)**. Use the submodule README for **run commands**, **proto regeneration**, and **CI**; use **[`many_faces_ai/AI_INTEGRATION.md`](../../many_faces_ai/AI_INTEGRATION.md)** for integration notes when present.

## Implemented RPCs (high level)

- **`Health`** — liveness for orchestration.
- **`Generate`** — optional local Qwen generation; supports **`stats_context_json`** for admin operator chat context.
- **`FetchPublicStats`** / **`OperatorStatsChat`** — **live** public aggregate mode (HTTP fetch + generate).
- **`ReviewContent`** — structured moderation recommendation consumed by **`many_faces_backend`**.

## Platform context

- Backend sanitizes untrusted payloads before gRPC; see [`moderation-content-prompt-injection-defense-agent-prompt.md`](../prompts/moderation-content-prompt-injection-defense-agent-prompt.md) and [`ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md).

## Related

- [`admin-dashboard-metrics.md`](../guides/admin-dashboard-metrics.md) — end-to-end stats + AI flow.
- [`redis-workers-and-queues.md`](../guides/redis-workers-and-queues.md) — where AI jobs sit in the worker story.
