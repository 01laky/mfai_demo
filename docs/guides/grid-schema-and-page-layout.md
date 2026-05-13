# Grid schema and page layout

## Data model

- Each **page** stores a JSON **`gridSchema`** string (managed from **`many_faces_admin`**, consumed by **`many_faces_portal`** / mobile).
- Backend persists via **`PagesController`**; admin UI edits routes + schema; user app **parses** schema into responsive layouts.

## JSON shape (conceptual)

The schema references **component types** (album, blog, reel, story, chat, profile, …), **breakpoints**, **columns**, **row heights**, and item positioning. Exact keys evolve — treat **`many_faces_portal`** `PageGridLayout` / `ComponentBlock` parsers as the live contract and snapshot examples from seeded pages.

## Lifecycle diagram

See the **Page Grid Schema Lifecycle** Mermaid diagram in [`many_faces_backend/README.md`](../../many_faces_backend/README.md).

## Related

- [`fe-grid-face-scope-rollout-agent-prompt.md`](../prompts/fe-grid-face-scope-rollout-agent-prompt.md) — agent checklist for face-scoped grid work.
- [`readmes/fe-portal-overview.md`](../readmes/fe-portal-overview.md)
