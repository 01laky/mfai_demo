# Frontend grid — face-scoped data & rollout agent prompt

**Language:** English  
**Scope:** `many_faces_portal` page grid (`PageGridLayout`, `many_faces_portal/src/components/grid/*`) and related API services.  
**North star:** Root [`APP_CONTEXT.md`](../../APP_CONTEXT.md) sections 8–9 (face-scoped reads, grid contracts, responsiveness, placeholder and seed-data policy).

**How to use:** Paste this file (or sections 2–5 plus **section 7** below) into an AI agent chat. Leave `[ ]` checklists **unchecked** in the canonical file; tick copies in PR/issue. Re-run when APIs or components change. **Section 7** is the single flat list of **all remaining work** — use it for sprint planning and PR descriptions.

---

## 1. Mission

- Every grid block **reads and displays data for the currently selected face** (`useFaceConfig()` → `selectedFace.id`, URL `/:lang/:faceIndex/...` in sync per `FaceConfigContext`).
- Blocks **must not** spoof another face or show cross-tenant mock data.
- **Inside-block** layout must stay **responsive to cell width** (`ResizeObserver`, `useFillGridPagination`, carousel `visibleCount`), not only CSS breakpoints; page canvas uses `react-grid-layout` from `gridSchema`.
- **Placeholder / sample UI** policy: strip **FE picsum / fake thumbs** when API returns real media URLs; keep **DB seed data** until product removes them (coordinate with docs and seeders).
- **Writes** (create, edit, upload images) go through **scoped APIs** + **capability-gated** UI (patterns: `*Form.tsx` + settings / grid top panel).

---

## 2. What we have now (audit snapshot)

Shared infrastructure:

- [x] **`PageGridLayout`** ([`many_faces_portal/src/components/PageGridLayout.tsx`](../../many_faces_portal/src/components/PageGridLayout.tsx)) — parses `gridSchema` JSON, renders `ResponsiveGridLayout`, maps `componentType` → React component, carousel/grid **pagination sync** with footer, **only `chatRoom` supports `boundChatRoomId`** in schema today.
- [x] **`FacePageView`** mounts grid when `page.gridSchema` exists.
- [x] **`ComponentBlock`** wraps each item (header, footer, autoplay localStorage).
- [x] **`gridDisplayHelpers.ts`** — centralized **neutral SVG fallbacks** (`albumCoverPlaceholderUrl`, `albumThumbnailPlaceholderUrl`, `blogCoverPlaceholderUrl`, `wallTicketListingImageUrl`, `storyRingImageUrl`, `profileAvatarUrl`); external `picsum.photos` placeholders have been removed from FE runtime code.
- [x] **List pages** — [`ComponentListView`](../../many_faces_portal/src/components/ComponentListView.tsx) reuses grids by numeric `componentTypeId` for `/list/:id` style routes.
- [x] **`FaceConfigContext`** — logged-in users see **public + private** faces; pathname can **select face** (deep links).
- [ ] **TanStack Query** — most grid components still use **manual `useEffect` + fetch**; optional future unification (see performance prompt).
- [x] **i18n** — grid block guest/empty/load/profile/wall copy uses **`gridBlockI18n.ts`** + **`PortalResources`** (`gridBlocks.*`, en/sk/cs). _Out of scope here: full form label/placeholder sweep (`AlbumForm`, `BlogForm`, …)._

Face-scoped reads (high level):

| Area | Service / API (representative) |
|------|--------------------------------|
| Albums | `AlbumsService.getAlbums(token, faceId)` |
| Blogs | `BlogsService.getBlogs(token, faceId)` |
| Reels | `ReelsService.getReels(token, faceId)` |
| Stories | `storiesApi.fetchStoriesForFace(token, faceId)` |
| Wall / “Ad” | `wallTicketsApi.fetchAllWallTicketsForFace(token, faceId)` |
| Chat rooms | `ChatRoomsService.listChatRooms` / `getChatRoom(faceId, …)` |
| Profiles | `faceProfilesApi.fetchAllFaceProfilesForFace(faceId, token)` |

Forms (create flows exist in repo; wire to capabilities & face scope when extending):

- [`AlbumForm.tsx`](../../many_faces_portal/src/components/grid/AlbumForm.tsx), [`BlogForm.tsx`](../../many_faces_portal/src/components/grid/BlogForm.tsx), [`ChatRoomForm.tsx`](../../many_faces_portal/src/components/grid/ChatRoomForm.tsx), [`ReelForm.tsx`](../../many_faces_portal/src/components/grid/ReelForm.tsx) (+ Quill for blog).
- [`GridTopPanelContent.tsx`](../../many_faces_portal/src/components/GridTopPanelContent.tsx) opens real forms for **album / blog / reel / chat rooms**. Today **`ad` / `story` / `userProfile` fall through to a generic placeholder create panel**, so the `+` action is not product-complete for those types. Existing dedicated panels — [`WallTicketCreateTopPanel.tsx`](../../many_faces_portal/src/components/WallTicketCreateTopPanel.tsx) and [`StoriesCreateTopPanel.tsx`](../../many_faces_portal/src/components/StoriesCreateTopPanel.tsx) — are likely reuse candidates for `ad` and `story`.
- Current forms are not uniformly “current-face only”: **album** defaults to all faces, **blog** defaults to the first face in `allFaces`, **reel** can mean all faces when none are selected, while **chat room** uses `selectedFace.id`. This must be a deliberate product decision, not an accidental cross-face write.
- [`ComponentBlock.tsx`](../../many_faces_portal/src/components/ComponentBlock.tsx) still has placeholder header actions (**report**, **favorite**, **sort/filter rank**) and local-only block settings (**autoplay**). Treat these as UX/API integration backlog, not finished capability-backed behavior.
- Admin grid types mirror the same `componentType` union, but [`GridLayoutEditor.tsx`](../../many_faces_admin/src/components/GridLayoutEditor.tsx) currently keeps only layout coordinates, `label`, and `componentType`. It does **not** model/preserve FE-only fields such as `boundChatRoomId`, `title`, or `icon`; any binding/header metadata added to `gridSchema` must be represented and preserved in Admin too.

---

## 3. Per `componentType` — current state & remaining work

Legend: **Face** = uses `selectedFace` / `faceId` correctly; **API** = backed by REST; **Guest** = behaves without token where product allows; **PH** = FE placeholder (picsum etc.); **R** = responsive inner layout.

**Display i18n (2026-05-16):** guest gates, empty/load errors, profile role fallbacks, wall label, loading aria, and shared form face legend/no-faces use **`gridBlockI18n`** + **`PortalResources`** (en/sk/cs). Remaining **`[ ] i18n`** rows below = form field labels/placeholders, `ChatRoomCard` copy, or a11y polish unless marked done inline.

### `album`

- [x] Face + API (first album); **Guest** no (sign-in message).
- [x] PH: main image and thumbnails use neutral local SVG fallbacks — replace with real cover/thumbnail URLs from album payload when API provides them.
- [ ] Optional: **bound album id** in grid JSON (like `boundChatRoomId`) for curated pages.
- [ ] i18n + empty/loading a11y polish.

### `albumGrid`

- [x] Face + API + `useFillGridPagination` (**R**).
- [x] PH: check cover rendering — align with `albumCoverPlaceholderUrl` / real URLs.
- [ ] Create/edit entry from block (if product wants) vs global “+” panel only.
- [ ] i18n.

### `albumCarousel`

- [x] Face + API + **ResizeObserver** visible count (**R**).
- [x] Same PH / media URL cleanup as album family.
- [ ] i18n.

### `ad` (wall ticket card)

- [x] Face + API (first ticket); **Guest** no.
- [x] PH: `wallTicketListingImageUrl` now returns a neutral local SVG — replace with **ticket image URL** when BE exposes it.
- [ ] Link / detail UX for listing (beyond static card).

### `adGrid` / `adCarousel`

- [x] Face + API list + pagination / carousel patterns (**R** for grid).
- [ ] Same image URL reality as `ad`.

### `blog`

- [x] Face + API (latest post).
- [x] PH: `blogCover()` uses first API image or a neutral local SVG placeholder.
- [ ] i18n.

### `blogGrid` / `blogCarousel`

- [x] Face + API + **R** patterns (carousel uses ResizeObserver).
- [ ] i18n; optional inline create where allowed.

### `chatRoom`

- [x] Face + API; **`boundChatRoomId`** optional on grid item.
- [x] **Guest** no.
- [ ] Extend **binding model** docs in Admin (`gridSchema` field) so editors know semantics.

### `chatRoomGrid` / `chatRoomCarousel`

- [x] Face + API patterns (parity with sibling grids — verify **faceId null** guards match `BlogGrid`).
- [ ] Disabled create button copy when face disallows (“Chat room creation is disabled for this face”) — align with capability API if not already.

### `userProfile` / `userProfileGrid` / `userProfileCarousel`

- [x] Face + API directory; **Guest** mostly no (`UserProfile` sign-in gate).
- [x] PH: `profileAvatarUrl` now falls back to a neutral initials/label SVG when **no `avatarUrl`**.
- [ ] i18n; role/subtitle (“Face member”) from API if available.

### `reel` (**single-tile caveat**)

- [~] Face: **calls `getReels(token, faceId)` but does not bail early when `faceId == null`** (unlike `BlogGrid`) — **harden** to same pattern as other components.
- [x] Uses **real `videoUrl`** when row exists — good.
- [ ] Guest policy: today sign-in required — confirm vs product for public reels.

### `reelGrid` / `reelCarousel`

- [x] Face + API + **R** patterns (`ReelGrid` uses fill pagination).
- [ ] Align **null faceId** handling with hardened `Reel`.

### `story` / `storyGrid` / `storyCarousel`

- [x] Face + API + `storyRingImageUrl` (neutral local SVG fallback).
- [x] `StoryGrid` uses **advanced layout math** (`computeStoryGridLayout`, slideshow hook).
- [ ] Reduce picsum reliance when cover URLs mandatory; **i18n**.

### Unknown / missing `componentType` in schema

- [x] Renders fallback label (`item.label || item.i`).

---

## 4. Cross-cutting tasks (priority order suggestion)

1. [x] **Hardening pass:** every fetch path **`faceId`** + **`token`** guards consistent (`Reel` first).
2. [ ] **Placeholder purge / design system:** replace picsum with **neutral SVG/CSS** or **only API media** per [`APP_CONTEXT.md`](../../APP_CONTEXT.md) section 8.4.
3. [ ] **Binding IDs:** evaluate `boundAlbumId`, `boundBlogId`, … in `GridItem` + Admin editor + BE validation (mirrors `boundChatRoomId`).
4. [ ] **Capabilities:** gate “Create” buttons in **`ComponentBlock`** using `GET …/capabilities` or existing ACL hooks — no create UI without permission.
5. [ ] **Uploads:** wire image/video upload endpoints (if BE ready) through forms; never cross face.
6. [x] **i18n** — grid display strings in `common` via API bundle (`gridBlockI18n` + `PortalResources` en/sk/cs). _Forms/ChatRoomCard copy still English._
7. [x] **Top-panel create parity:** replace generic `+` fallback for `ad`, `story`, and `userProfile` with product-approved flows or explicitly disable/hide create for those types.
8. [x] **Scoped write defaults:** make form defaults match current face unless product intentionally allows multi-face / all-face writes (album, blog, reel need review).
9. [x] **Admin schema preservation:** add/preserve `boundChatRoomId`, `title`, `icon`, and any future `bound*` fields in Admin `GridItem` editing/saving; do not drop metadata during drag/resize.
10. [x] **Header actions:** wire Report, Favorite, and Sort/filter rank to real APIs or remove/disable them until supported.
11. [ ] **Tests** — pure helpers (`gridDisplayHelpers`, layout math) and **fetch mocks** face-scoped; follow `unit-test-gap-fill-agent-prompt.md` policy.

---

## 5. Verification checklist (agent / PR)

- [ ] Navigate `/:lang/:faceIndex/page-with-grid`; switch faces; confirm **lists refetch** and **never** show previous face IDs in network payloads.
- [ ] Resize viewport and grid cells; carousel/grid **tile counts** change without overflow glitches.
- [ ] Guest vs authenticated: messages match policy; no crash when `selectedFace` null during transition.
- [ ] Click `+` on every `componentType`; each either opens a real, scoped create flow or is intentionally disabled with clear copy.
- [ ] Create album/blog/reel/chat-room from a face page; resulting entity belongs to the intended face(s), with no accidental all-face or first-face default.
- [ ] In Admin, edit and save a page grid containing `boundChatRoomId` / header metadata; verify drag/resize does **not** drop those fields from `gridSchema`.
- [ ] Click header actions (List, Report, Favorite, Sort/filter, Block settings); unsupported actions are not presented as working product features.
- [x] `./scripts/ci-local.sh` (or `many_faces_portal` lint + test subset) passes.
- [ ] Update this prompt’s section 2 snapshot **only after** a deliberate re-audit (optional line in PR: “audit ref: yyyy-mm-dd”).

---

## 6. Related docs

- [`APP_CONTEXT.md`](../../APP_CONTEXT.md) sections 8–9  
- [`docs/readmes/fe-portal-overview.md`](../readmes/fe-portal-overview.md)  
- [`docs/guides/local-dev-accounts.md`](../guides/local-dev-accounts.md)

---

## 7. Master rollout checklist (everything still to do)

**Convention:** only **open** work is listed. Tick in a **PR or issue copy**; keep this file’s boxes **unchecked** unless you are recording a completed one-off pass (see [`prompts/README.md`](./README.md)). Grouping matches sections 2–5 above but is **one flat execution list**.

### Platform & infrastructure

- [ ] **TanStack Query (optional):** migrate grid fetchers from ad-hoc `useEffect` + fetch to Query keys scoped by `faceId` + auth (see [`fe-performance-and-refactor-agent-prompt.md`](./fe-performance-and-refactor-agent-prompt.md)).
- [x] **Global i18n sweep:** grid block guest/empty/load/profile/wall strings via **`gridBlockI18n`** + **`PortalResources`** (en/sk/cs). _Started earlier: grid action/create copy in locale JSON; forms/card activity strings still open._

### Hardening & security of reads

- [x] **Consistent guards:** every grid component bails before fetch when `faceId` or `token` is missing per that endpoint’s rules; **prioritize `Reel`**, then align `reelGrid` / `reelCarousel` with the same pattern.
- [x] **Verify** `chatRoomGrid` / `chatRoomCarousel` **`faceId === null`** behaviour matches strictest siblings (e.g. `BlogGrid`).

### Placeholders & media truth

- [x] **Placeholder purge (APP_CONTEXT 8.4):** replace picsum / fake thumbs with API media URLs or neutral empty UI (`gridDisplayHelpers` + inline album thumbs + blog cover + story rings + profile avatars).

### Bindings, Admin, capabilities, writes

- [ ] **Optional binding fields:** extend `GridItem` + Admin grid editor + BE validation with `boundAlbumId`, `boundBlogId`, etc., mirroring `boundChatRoomId` where product needs pinned tiles.
- [ ] **Admin / docs:** document `boundChatRoomId` (and any new `bound*`) so editors understand grid JSON semantics.
- [x] **Admin schema preservation:** update Admin `GridItem` types and layout mutation code so `boundChatRoomId`, `title`, `icon`, and future metadata survive drag/resize/save.
- [ ] **Capabilities:** hide or disable **Create** in `ComponentBlock` (and siblings) unless capability / ACL allows; align copy when creation is forbidden (e.g. chat rooms disabled for face).
- [x] **Top-panel create parity:** replace the generic `GridTopPanelContent` fallback for `ad`, `story`, and `userProfile` with real product flows, or explicitly disable/hide `+` for unsupported create types; evaluate reusing `WallTicketCreateTopPanel` for `ad` and `StoriesCreateTopPanel` for `story`.
- [x] **Scoped write defaults:** review `AlbumForm`, `BlogForm`, and `ReelForm` defaults so creating from a face page targets `selectedFace` by default; keep multi-face / all-face publishing only when product intentionally wants it.
- [ ] **Uploads:** wire image/video uploads through forms to BE when endpoints exist; never attach media to wrong `faceId`.
- [ ] **URL-only media fields:** replace manual image/video URL entry in forms with upload/media-picker UX when upload endpoints are ready; keep pasted URLs only if product explicitly supports external media.
- [ ] **Forms UX:** optionally expose create/edit **from within** specific blocks (`albumGrid`, `blogGrid` / carousel, …) if product wants more than global “+” panel only.
- [x] **Header actions:** wire `Report`, `Favorite`, and `Sort / filter rank` in `ComponentBlock` to real APIs, or remove/disable them until they have product-backed behavior.
- [ ] **Block settings persistence:** decide whether `component-settings-*` localStorage settings (currently autoplay only) are acceptable per browser, or need server-backed per-user/per-face settings.

### Per `componentType` (remaining deltas)

- [ ] **`album`:** optional `boundAlbumId` (or equivalent); i18n; empty/loading **a11y** polish.
- [x] **`album` / `albumCarousel`:** finish **thumbnail / cover URL** cleanup once API provides real URLs (no inline picsum thumbs).
- [ ] **`albumGrid`:** i18n; product decision on create/edit entry point.
- [ ] **`albumCarousel`:** i18n.
- [ ] **`ad`:** use **real ticket listing image URL** from API when available; add **link / detail** UX beyond static card if required.
- [x] **`ad` / `adGrid` / `adCarousel`:** decide whether `+` creates wall tickets, then reuse/adapt `WallTicketCreateTopPanel` or disable create for ad tiles.
- [ ] **`adGrid` / `adCarousel`:** same real image behaviour as `ad`; add card navigation/detail parity if `ad` gets detail UX.
- [x] **`blog`:** i18n; prefer **neutral cover** when no images (reduce picsum).
- [ ] **`blogGrid` / `blogCarousel`:** i18n; optional inline create when allowed.
- [ ] **`chatRoom`:** Admin-side documentation for binding field(s).
- [ ] **`chatRoomGrid` / `chatRoomCarousel`:** capability-aligned disabled state + messaging for create when face disallows.
- [ ] **`userProfile` / `userProfileGrid` / `userProfileCarousel`:** replace picsum avatar fallback with **initials / gradient** (or equivalent); i18n; surface **role / subtitle** from API if present. _Started: avatar fallback no longer uses picsum._
- [x] **`userProfile` family:** decide what `+` means (invite member, edit own profile, create profile, or disabled) and implement/disable the top-panel action accordingly.
- [x] **`reel`:** **early return** when `faceId == null` before `getReels`; confirm **guest vs auth** policy with product and implement consistently.
- [x] **`reelGrid` / `reelCarousel`:** match hardened **`reel`** null-`faceId` / guest rules.
- [ ] **`story` / `storyGrid` / `storyCarousel`:** reduce picsum when covers are mandatory from API; i18n. _Started: story fallback no longer uses picsum._
- [x] **`story` family:** connect `+` to the existing `StoriesCreateTopPanel` / story creation UX/API (or disable it) instead of the generic placeholder create panel.

### Tests

- [ ] Unit tests for **pure helpers** (`gridDisplayHelpers`, story layout math, pagination helpers) and **face-scoped** fetch mocks per [`unit-test-gap-fill-agent-prompt.md`](./unit-test-gap-fill-agent-prompt.md). _Started: `gridDisplayHelpers` covered with neutral placeholder tests._

### Verification & process (ship gate)

- [ ] Manual: `/:lang/:faceIndex/…` — switch faces; **lists refetch**; network payloads show **correct `faceId`** (no leakage from previous selection).
- [ ] Manual: resize viewport / grid cells — carousel & grid **tile counts** sane, no clipped overflow regressions.
- [ ] Manual: guest vs authenticated — copy matches policy; **no crash** while `selectedFace` is transiently null during navigation.
- [ ] Manual: click `+` on every `componentType`; each either opens a real, scoped create flow or is intentionally disabled with clear copy.
- [ ] Manual: create album/blog/reel/chat-room from a face page; resulting entity belongs to the intended face(s), with no accidental all-face or first-face default.
- [ ] Manual: edit and save a page grid in Admin; verify existing `boundChatRoomId`, `title`, `icon`, and future metadata are not dropped by drag/resize/save.
- [ ] Manual: click header actions (List, Report, Favorite, Sort/filter, Block settings); unsupported actions are not presented as working product features.
- [x] CI: `./scripts/ci-local.sh` or **`many_faces_portal` lint + targeted tests** green for touched paths.
- [ ] After deliberate re-audit only: refresh **section 2** snapshot in this file; note optional PR line `audit ref: yyyy-mm-dd`.

---

_Version: grid face-scope prompt + section 7 master checklist._
