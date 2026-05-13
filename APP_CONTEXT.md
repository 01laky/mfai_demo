# Many Faces — application context

Single place to answer **what this system is**, **who uses which surface**, and **how the pieces hang together**. GitHub monorepo: **`many_faces_main`** (submodules `many_faces_portal`, `many_faces_backend`, …; working-tree paths `many_faces_portal/`, `many_faces_backend/`, …). For deep mechanics, use [`docs/README.md`](./docs/README.md). Submodules retain their own READMEs.

---

## 1. What the product is

**Many Faces AI** is a **multi-tenant web platform** built around **faces** — each face is its own branded space (URL prefix + config + pages), like a lightweight **site-within-an-app**.

- End users browse and interact inside a chosen face: **dynamic pages**, **social** (friends, messenger, notifications), optional **Stories**, **Wall**, **profiles**, **chat + AI hooks**, and UI composed from **configurable grids** (“blocks” backed by typed components: albums, blogs, reels, chat rooms, etc.).
- Operators use a separate **Admin** app with **elevated/global or scoped roles** to **shape** those tenants: faces, users, pages, layouts, moderation — without redeploying the frontend.

So in one sentence: **one shared platform, many branded “sites” (faces), one API spine, two SPAs — public/social Frontend + operational Admin.**

---

## 2. How it should work — mental model

| Concept | Meaning |
|--------|---------|
| **Face** | Tenant anchor: slug (`index`), title, gradient/branding knobs, visibility (public vs private), seeded/default pages (`home`, maybe `wall`), optional profile directory visibility. Middleware rewrites requests so `/api/{face}/...` resolves in the backend. |
| **Page** | A route segment under that face (`/home`, `/lab`, …) with a **page type** (`home`, `static`, `wall`, …). **Static** pages carry an optional **`gridSchema`**: responsive layout + **typed component placeholders** rendered on the Frontend. Translations define localized path aliases. |
| **User / roles** | **Global roles** (`SUPER_ADMIN`, `ADMIN`, `USER`, …) and **per-face roles** (`FACE_ADMIN`, `FACE_HOST`, …). Capability checks drive what API and hubs allow. Seed data provides known accounts (`docs/guides/local-dev-accounts.md`). |
| **Realtime + AI** | SignalR hubs (chat, messenger, notifications, …); optional **SendToAi** flows through **`many_faces_ai`** (`many_faces_ai/`) over gRPC. |

The Frontend’s job is **not** to redefine business rules: it reflects **backend config + auth + realtime**. The Admin’s job is to **safely mutate** that config and moderation state.

---

## 3. Frontend (`many_faces_portal` / path `many_faces_portal/`) — what it’s for

- **Primary users:** Visitors and authenticated members of faces.
- **Responsibilities:** Auth (OAuth2 + JWT session), localized routing (`/:lang/...`), **face-aware navigation**, rendering **CMS-like pages from API** (`FacePageView`, grid system), social surfaces (friends, messenger, settings), **My submissions** for pending user-created albums/blogs/reels, and optional richer features (stories wall, reels, albums, profiles) backed by REST + hubs.
- **Design intent:** One shell (header/footer/settings panel) swapping **tenant context** (`FaceConfigProvider`) — users can operate in **their** tenant or land on **public** faces **without treating “public CMS” as second-class once logged in**.
- **Data & layout contract:** See **[§8 — Frontend architecture (face scope, grids, responsiveness)](#8-frontend-architecture--face-scoped-data-grid-specs-responsiveness)**.

---

## 4. Admin (`many_faces_admin` / path `many_faces_admin/`) — what it’s for

- **Primary users:** Super admins / admins managing the estate; tenant admins scoped to faces where policy allows.
- **Responsibilities:** OAuth login against the API (often **`admin` face prefix** in dev), dashboards, **Users** CRUD, **Faces** CRUD, **Pages** CRUD (+ **route translations**), **`Page Types`**, grid layout authoring (`GridLayoutEditor` + component picker), **user content moderation** (superadmin queue, metrics, bulk, audit) for albums/blogs/reels from the Frontend, wall ticket moderation hooks where enabled, optional AI Chat page depending on deployment.
- **Design intent:** **Structure and policy** precede polish: define **what routes exist**, **who can see whom**, **what grids host which component types**. Content can still live in-domain via APIs/UI the Frontend exposes once structure exists.

---

## 5. Backend & siblings (minimal context)

| Piece | Role |
|-------|------|
| **`many_faces_backend`** (`many_faces_backend/`) | Source of truth: Identity + EF Postgres, OAuth2 JWT, ACL/capabilities, REST, SignalR, gRPC client to AI. |
| **`many_faces_database`** (`many_faces_database/`) / **`many_faces_redis`** (`many_faces_redis/`) | Persistence + background/worker prerequisites (Redis for wall/async patterns per guides). |
| **`many_faces_ai`** (`many_faces_ai/`) | gRPC `Health`, local Qwen `Generate`, and **`ReviewContent`** — structured, advisory recommendations for user-created album/blog/reel moderation (`many_faces_backend` validates and `SUPER_ADMIN` finalizes). |

---

## 6. Typical flows (sanity checks)

1. **Operator** creates/edits face + adds **static pages** + drops **grid blocks** with component types → saves `gridSchema`.
2. **End user** (guest or logged-in, depending on face and page guards) visits `/:lang/:faceIndex/...`, loads config → sees composed page + social chrome.
3. **User-created content moderation:** pending albums/blogs/reels stay off public grids until **`Approved`**; Redis drives AI review; creators use **My submissions** on the Frontend; **`SUPER_ADMIN`** uses the Admin moderation screen (filters, metrics, bulk, audit). See [`docs/guides/ai-assisted-content-approval.md`](./docs/guides/ai-assisted-content-approval.md).
4. **Other moderation / escalation** (e.g. wall tickets) stays on Admin or guarded API routes; JWT + face scope prevent cross-tenant leaks (see ACL guides).

---

## 7. For AI agents editing this repo

- Prefer **focused changes** scoped to FE, Admin, or API contracts; historical inventory snapshot: [`docs/guides/archive/proposal-many-faces-state.md`](./docs/guides/archive/proposal-many-faces-state.md).
- Respect **OAuth2**, **face-prefixed API paths**, and **React Router v6 route rules** (no custom wrappers where `<Routes>` insist on literal `<Route>` children).
- When changing face visibility or **`availableFaces` semantics**, revisit **logged-in UX** — public showcase faces must remain reachable unless product explicitly restricts them.
- For **grid components and face-scoped API reads**, follow **[§8](#8-frontend-architecture--face-scoped-data-grid-specs-responsiveness)** (patterns: `useFaceConfig` → `faceId`, TanStack + OpenAPI services, `useFillGridPagination`, `ResizeObserver`).

---

## 8. Frontend architecture — face-scoped data, grid specs, responsiveness

*(Working name only: nothing magic about “FA” — this section is what you meant.)*

### 8.1 Face scope (how data reads must behave)

Every **meaningful REST read/write** on **`many_faces_portal`** (`many_faces_portal/`) for tenant content MUST be coherent with **`FaceConfigProvider.selectedFace`**, which MUST stay aligned with the URL **`/:lang/:faceIndex/...`** whenever the segment is an actual face index (see hooks that sync pathname → face selection).

Practically:

- Grid components derive **`faceId = selectedFace?.id`** and pass **`faceId`** (and **`token`** when required) into **OpenAPI/generated service** calls (albums, blogs, reels, stories, profiles, ads, chat rooms — each service already mirrors face-scoped API routes).
- If **`token`** or **`faceId`** is missing, components show an honest **guest / unavailable** message — they MUST NOT silently fall back to another face’s dataset.
- The word you were looking for: **face-scoped (tenant-scoped) data loading** — all list/detail payloads are **implicitly filtered by backend** via face-prefixed API paths + JWT claims; the FE obligation is never to spoof `faceId` and to refetch when `selectedFace` changes.

Admin remains the place to **provision** structure (`gridSchema`) and moderation; Frontend is where **consumers** see consistent data for whatever face context they’re in — and increasingly where **eligible users create** albums/blogs/uploads **inside that same face**, governed by ACL (capability-backed UI).

### 8.2 Page grid ↔ component contract

`gridSchema.items[]` carries **`componentType`** (string enum mirrored in **`many_faces_admin`** / `many_faces_admin/` `GridComponentType`).

For EACH type the Frontend registers a **known implementation** (`PageGridLayout` router / grid index): it MUST

1. **Render** consistent with **`w`/`h`/breakpoints** on the outer **react-grid-layout** canvas (`FacePageView` / `ResponsiveGridLayout` — already in codebase).
2. **Load server state** matching that type’s REST contract under the **current `faceId`** (and auth rules for that endpoint).
3. **Support empty state** gracefully when PostgreSQL/EAV has zero rows → no stray mock cross-tenant leakage.
4. **Support create / media upload flows** wherever product says so — through the same scoped API (+ optional future presigned uploads); uploads are **never** anonymous cross-face.

Several grid variants are already **wired** (`AlbumGrid`, `BlogGrid`, `ReelGrid`, carousel siblings, pagination hooks **`useFillGridPagination`**, **`ResizeObserver`** for dynamic column counts — use them as canonical patterns when finishing missing types).

### 8.3 Responsiveness beyond “looks mobile”

Two layers collaborate:

| Layer | Behavior |
|-------|----------|
| **Page canvas** | `react-grid-layout` **cols / breakpoints / rowHeight** (`gridSchema` from Admin); blocks reflow across `lg/md/sm/xs/xxs`. |
| **Inside each block** | Components **observe their own container width** (`ResizeObserver`, `useFillGridPagination`, carousel `visibleCount` math — see `AlbumCarousel`, grids) so **tile counts, thumbnails, carousel windows** tighten/loosen dynamically with allocated cell size — NOT only `@media` breakpoints. |

When adding new grid types **copy patterns from finished siblings**: mount ref on scrollport, cancel async on unmount, debounce/observe politely.

### 8.4 Seed data & placeholders — explicit policy

| Source | Policy |
|--------|--------|
| **PostgreSQL seed / sample tenants** (`many_faces_backend` / `many_faces_backend/` seeders, seeded users/faces, `local-dev-accounts.md`) | **Keep** while we need scripted local setups until product says drop them. Coordinate removal with docs + teardown scripts. |
| **Hard-coded Frontend placeholders** (e.g. Lorem ipsum, **picsum.photos** stand-ins, fictitious carousel slides) | **Treat as transitional**: once real media URLs/API fields arrive, strip placeholders so empties reflect **truth** (“no uploads yet”). If a placeholder confuses testers, remove it outright. |

**Rule of thumb:** if there is **no persisted entity**, the UI shows **scoped empty/error** states — never fake sibling-face content.

---

## 9. Roadmap tone (Frontend)

We will iterate **per grid type** and **per write path** next: align API + capability gates + uploads + optimistic UX — using §8 rules as acceptance criteria.

## 10. Further reading (monorepo)

- [`docs/README.md`](./docs/README.md) — documentation hub (all `guides/`, `components/`, `prompts/`).
- [`docs/guides/development.md`](./docs/guides/development.md) — CI, scripts, hooks.
- [`docs/guides/troubleshooting-local-dev.md`](./docs/guides/troubleshooting-local-dev.md) — common local failures.

---

**Update:** when product intent shifts, edit this file — it is a short-lived north star, not release notes.
