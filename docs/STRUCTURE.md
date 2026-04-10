# Layout of `docs/` (why these folders)

| Folder            | Role                                                                                                                                            |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **`guides/`**     | Long-form reference: CI, auth, ACL, APIs, security design, submodules. Language: **English**.                                                   |
| **`components/`** | Short **catalog** of implemented building blocks (where they live in the repo + link to the full guide). Not a duplicate of `guides/`.          |
| **`prompts/`**    | Copy-paste **specs for AI agents** (implementation prompts, not end-user docs).                                                                 |
| **`readmes/`**    | **Index** of per-submodule README files plus **extended overview** pages for apps (`fe_demo`, `admin_demo`, Redis) that read like long READMEs. |

The hub for humans is **[README.md](./README.md)**. Root **[`../README.md`](../README.md)** stays a short monorepo entry and points here.

### Diagram: docs folder layout

```mermaid
flowchart TB
  subgraph docs["docs/"]
    guides[guides long-form reference]
    components[components building blocks catalog]
    prompts[prompts AI agent specs]
    readmes[readmes README index overviews]
    hub["README.md hub"]
  end
  root_readme["Root ../README.md short entry"]
  root_readme --> hub
  hub --> guides
  hub --> components
  hub --> prompts
  hub --> readmes

  classDef clientFill fill:#e3f2fd,stroke:#1565c0
  classDef folderFill fill:#e8f5e9,stroke:#2e7d32
  class hub,root_readme clientFill
  class guides,components,prompts,readmes folderFill
```
