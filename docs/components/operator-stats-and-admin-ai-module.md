# Component: operator statistics + admin AI context

**Purpose:** Dashboard KPIs, anonymous public aggregate snapshot, optional attachment of counts to admin AI chat (**off / inline / live**).

**Primary code:** `many_faces_backend` — `StatsController`, `IPlatformStatsQueryService`, `ChatHub.SendToAiWithOperatorStats`, `AiGrpcService`; `many_faces_admin` — settings + dashboard strip + chat invoke; `many_faces_ai` — `stats_context_json`, `FetchPublicStats`, `OperatorStatsChat`.

**Guides:** [`admin-dashboard-metrics.md`](../guides/admin-dashboard-metrics.md), [`backend-stats-and-admin-ai-runbook.md`](../guides/backend-stats-and-admin-ai-runbook.md).

**Prompts:** [`admin-ai-public-stats-operator-chat-agent-prompt.md`](../prompts/admin-ai-public-stats-operator-chat-agent-prompt.md).
