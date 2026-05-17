# Admin operator AI chat — threaded conversations

Shared **support inbox** for platform operators (`CanManageAllFaces` on the **admin** face scope). Conversations and messages live in PostgreSQL; the admin SPA uses REST for list/history and SignalR for sends and live sync.

**Related:** [backend-stats-and-admin-ai-runbook.md](./backend-stats-and-admin-ai-runbook.md), [signalr-hub-security-matrix.md](./signalr-hub-security-matrix.md), [admin-operator-ai-chat-threads-agent-prompt.md](../prompts/admin-operator-ai-chat-threads-agent-prompt.md).

## API

| Method | Path | Notes |
|--------|------|--------|
| `GET` | `/admin/api/operator-ai/conversations?limit=50` | All threads, `UpdatedAt` desc |
| `POST` | `/admin/api/operator-ai/conversations` | Body `{ "title": null }` optional |
| `GET` | `/admin/api/operator-ai/conversations/{id}` | Metadata |
| `PATCH` | `/admin/api/operator-ai/conversations/{id}` | Rename |
| `DELETE` | `/admin/api/operator-ai/conversations/{id}` | Hard delete + cascade messages |
| `GET` | `/admin/api/operator-ai/conversations/{id}/messages?limit=40&beforeId=` | Newest page; `beforeId` loads older |

## SignalR (`/admin/hubs/chat`)

| Client → server | Args | Notes |
|-----------------|------|--------|
| `SendToAiWithOperatorStats` | `conversationId`, `message`, `statsMode` | History from DB; `MaxNewTokens` from config |

| Server → client | Purpose |
|-----------------|--------|
| `ReceiveAiMessage` | Caller-only AI reply (unchanged) |
| `OperatorAiMessageAppended` | All operators — new user+assistant rows |
| `OperatorAiConversationListChanged` | Sidebar refresh |
| `OperatorAiConversationDeleted` | Thread removed |

Group: `operator_ai_operators` (joined on connect when `CanManageAllFaces`).

## Configuration (`OperatorAi` in `appsettings.json`)

| Key | Default | Purpose |
|-----|---------|---------|
| `MaxHistoryPairs` | 5 | AI context pairs from DB |
| `MaxMessageLength` | 16000 | User message cap |
| `MaxConversations` | 1000 | Retention trim |
| `MessagesPageSize` | 40 | REST page size |
| `MaxNewTokens` | 2048 | gRPC generation limit |

## Admin UI

- Route: `/chat?c={conversationId}`
- Left: conversation list, **New chat**, select thread
- Right: messages, scroll-up pagination, composer
- Stats mode: `admin_ai_public_stats_mode` in `localStorage` (unchanged)
- **No** `sessionStorage` chat history

---

### Diagram: D-OAI-01 — Send message

```mermaid
sequenceDiagram
  participant UI as Admin ChatPage
  participant API as REST conversations
  participant Hub as ChatHub
  participant DB as PostgreSQL
  participant AI as many_faces_ai gRPC

  UI->>API: GET messages(conversationId)
  API->>DB: load thread
  DB-->>UI: history
  UI->>Hub: SendToAiWithOperatorStats(id, text, statsMode)
  Hub->>DB: insert user message
  Hub->>DB: load last N pairs
  Hub->>AI: Generate / OperatorStatsChat
  AI-->>Hub: assistant text
  Hub->>DB: insert assistant message
  Hub-->>UI: ReceiveAiMessage
  Hub->>UI: OperatorAiMessageAppended broadcast
```

### Diagram: D-OAI-02 — Live sync between operators

```mermaid
sequenceDiagram
  participant A as Admin client A
  participant B as Admin client B
  participant Hub as ChatHub
  participant DB as PostgreSQL

  A->>Hub: SendToAiWithOperatorStats(convId, text, statsMode)
  Hub->>DB: insert user + assistant rows
  Hub-->>A: ReceiveAiMessage
  Hub-->>A: OperatorAiMessageAppended (echo)
  Hub-->>B: OperatorAiMessageAppended
  Hub-->>B: OperatorAiConversationListChanged
  Note over B: append bubble if convId matches ?c=
```

### Diagram: D-OAI-03 — Data model

```mermaid
erDiagram
  OperatorAiConversations ||--o{ OperatorAiMessages : contains
  AspNetUsers ||--o{ OperatorAiConversations : created_by
  OperatorAiConversations {
    int Id PK
    string Title
    string CreatedByUserId FK
    datetime CreatedAt
    datetime UpdatedAt
  }
  OperatorAiMessages {
    int Id PK
    int ConversationId FK
    string Role
    text Content
    string StatsMode
    datetime CreatedAt
  }
```

### Diagram: D-OAI-04 — Admin UI layout

```mermaid
flowchart LR
  subgraph url [Route]
    Q["?c=conversationId"]
  end
  subgraph sidebar [Sidebar]
    New["New chat"]
    List["Conversation list"]
    Del["Delete thread"]
  end
  subgraph main [Chat pane]
    Status["Connection status"]
    Scroll["Messages + load older"]
    Input["Composer + Send"]
  end
  Q --> main
  sidebar --> main
```

### Diagram: D-OAI-05 — Message pagination scroll-up

```mermaid
sequenceDiagram
  participant UI as Chat pane
  participant API as REST messages
  participant DB as PostgreSQL

  UI->>UI: scrollTop near 0
  UI->>API: GET ?beforeId=oldestId&limit=40
  API->>DB: older page
  DB-->>API: items + hasMore
  API-->>UI: prepend DOM + fix scrollHeight
```

### Diagram: D-OAI-06 — Retention trim

```mermaid
flowchart TB
  Trigger["POST conversation or retention job"]
  Count{"count > MaxConversations (1000)?"}
  Pick["Select oldest UpdatedAt threads"]
  Del["DELETE threads + cascade messages"]
  Ok["Keep all"]
  Trigger --> Count
  Count -->|yes| Pick --> Del
  Count -->|no| Ok
```

### Diagram: D-OAI-07 — Auth and face prefix

```mermaid
flowchart TB
  Req["Request /admin/api/... or /admin/hubs/chat"]
  JWT{"Valid JWT?"}
  Face{"Admin face scope?"}
  Op{"CanManageAllFaces?"}
  Allow["200 / hub invoke"]
  Deny["401 / 403"]
  Req --> JWT
  JWT -->|no| Deny
  JWT -->|yes| Face
  Face -->|no| Deny
  Face -->|yes| Op
  Op -->|no| Deny
  Op -->|yes| Allow
```

### Diagram: D-OAI-08 — Config to AI token limit

```mermaid
flowchart LR
  CFG["OperatorAi:MaxNewTokens = 2048"]
  Hub["ChatHub"]
  GRPC["IAiGrpcService"]
  AI["many_faces_ai Generate"]
  CFG --> Hub --> GRPC --> AI
```
