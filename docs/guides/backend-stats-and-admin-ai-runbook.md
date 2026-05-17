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

## AI chat message history (admin UI)

- **Shipped:** [admin-operator-ai-chat-threads.md](./admin-operator-ai-chat-threads.md) — PostgreSQL `OperatorAiConversations` / `OperatorAiMessages`, two-pane **`ChatPage`**, deep link **`/chat?c={id}`**, SignalR live sync, retention max **1000** threads.
- **SHV2 FE-A3 waived:** history is **not** cleared on logout (shared support tool for platform operators).
- Hub: `SendToAiWithOperatorStats(conversationId, message, statsMode)` — server loads history from DB; `OperatorAi:MaxNewTokens` default **2048**.

## Related

- [`admin-ai-public-stats-operator-chat-agent-prompt.md`](../prompts/admin-ai-public-stats-operator-chat-agent-prompt.md)
- [`many_faces_ai/README.md`](../../many_faces_ai/README.md) — gRPC RPCs.
