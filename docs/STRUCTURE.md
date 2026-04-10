# Layout of `docs/` (why these folders)

| Folder | Role |
|--------|------|
| **`guides/`** | Long-form reference: CI, auth, ACL, APIs, security design, submodules. Default language **English**; Slovak app narratives that are not “prompts” live under **`readmes/`**. |
| **`components/`** | Short **catalog** of implemented building blocks (where they live in the repo + link to the full guide). Not a duplicate of `guides/`. |
| **`prompts/`** | Copy-paste **specs for AI agents** (implementation prompts, not user docs). |
| **`readmes/`** | **Index** of submodule READMEs plus Slovak **overview** pages (`*-sk.md`) that read like extended READMEs. |

The hub for humans is **[README.md](./README.md)**. Root **[`../README.md`](../README.md)** stays a short monorepo entry and points here.
