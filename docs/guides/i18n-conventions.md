# Internationalization (i18n) conventions

## Canonical guide

Full architecture (static `.resx` + API, CMS `PageRouteTranslations`, Mermaid diagrams, dev workflow):

**[`static-localization-and-i18n.md`](./static-localization-and-i18n.md)**

Implementation checklist: [`docs/prompts/centralized-static-i18n-resx-backend-agent-prompt.md`](../prompts/centralized-static-i18n-resx-backend-agent-prompt.md)

## Languages

- **`many_faces_portal`**, **`many_faces_admin`**, and **`many_faces_mobile`** ship **`en`**, **`sk`**, **`cz`** (same codes in DB for CMS page slugs).

## Key structure (static UI)

- Prefer **namespaced** keys: `routes.*`, `pages.*`, `components.*`, `errors.*`.
- Keep **parity** across `en` / `sk` / `cz` in backend `.resx` (CI enforces key sets).
- **No** shared `SharedResources.resx` — duplicate keys across apps are allowed; keep login/register wording aligned manually when it matters.

## Where static copy lives

| Phase | Location |
| ----- | -------- |
| **Target** | `many_faces_backend/BeDemo.Api/Localization/{Portal,Admin,Mobile}/*.resx` |
| **Transitional** | `src/i18n/locales/` in each frontend until rollout completes |

Clients load static bundles via **`GET /api/localization/{app}`** at startup (see canonical guide).

## CMS page URL slugs (dynamic)

- Still edited in admin **Create/Edit Page** → stored in **`PageRouteTranslations`** — not in `.resx`.
- Documented in [`static-localization-and-i18n.md`](./static-localization-and-i18n.md#cms-dynamic-page-routes-unchanged-by-static-i18n-rollout).

## Related

- [`mobile-expo-development.md`](./mobile-expo-development.md) — mobile env and quality gates
