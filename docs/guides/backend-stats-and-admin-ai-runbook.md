# Backend stats and admin AI — operator runbook

Short checklist for **platform operators** using **`many_faces_admin`**. Architecture and diagrams: **[`admin-dashboard-metrics.md`](./admin-dashboard-metrics.md)** (canonical deep doc).

## Dashboard numbers

- Full KPIs: **`GET /api/Stats`** and **`GET /api/Stats/timeseries`** under the **admin** face prefix with an operator JWT.

## Public aggregate (anonymous-safe)

- **`GET /api/Stats/public`** — counts only; **`[AllowAnonymous]`** but must be called on the **`public`** face URL prefix (not the admin prefix).

## AI chat context modes (`localStorage`)

| Mode | Behaviour |
| ---- | ---------- |
| `off` | No stats JSON attached to admin AI chat. |
| `inline` | API embeds **public snapshot** JSON into gRPC **`Generate`** (`stats_context_json`). |
| `live` | Python service **HTTP GETs** `AiStats:PublicSnapshotAbsoluteUrl` (must be a **`/public/...`** URL), then generates. |

## Config keys (backend)

- **`AiStats:PublicSnapshotAbsoluteUrl`** — required for **live** mode (absolute URL to public stats JSON).

## SignalR

- Hub method **`SendToAiWithOperatorStats`** (operator-only; rate limited) — see `ChatHub` + [`signalr-hub-security-matrix.md`](./signalr-hub-security-matrix.md).

## Related

- [`admin-ai-public-stats-operator-chat-agent-prompt.md`](../prompts/admin-ai-public-stats-operator-chat-agent-prompt.md)
- [`many_faces_ai/README.md`](../../many_faces_ai/README.md) — gRPC RPCs.
