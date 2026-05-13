# Content moderation — operations

This page is the **short operator runbook**. Full architecture, data model, and security notes: **[`ai-assisted-content-approval.md`](./ai-assisted-content-approval.md)**.

## Roles

- **`SUPER_ADMIN`** — approve / reject / remove / bulk / requeue; sees metrics and alerts.
- **Creators** — **`GET /api/my/content-submissions`** + **My submissions** UI (portal + mobile read path where implemented).

## Admin UI surfaces

- Queue with **filters**, **metrics + alerts**, **bulk actions**, per-item **audit** trail.
- Optional **retention** worker redacts internal AI fields after policy delay.

## Backend levers (names only)

- **`ContentModerationController`** — queue + actions.
- **`ContentAiReviewService`** — Redis worker path to **`ReviewContent`** gRPC + sanitization.
- **`ContentModeration:`** configuration — e.g. instruction heuristic toggle.

## When things look “stuck”

- Check **Redis** worker health and **Seq** logs ([`redis-workers-and-queues.md`](./redis-workers-and-queues.md), [`observability-seq-and-logs.md`](./observability-seq-and-logs.md)).
- Verify content is not **`PendingApproval`** with failed AI retries (see full guide).

## Related

- [`moderation-content-prompt-injection-defense-agent-prompt.md`](../prompts/moderation-content-prompt-injection-defense-agent-prompt.md)
