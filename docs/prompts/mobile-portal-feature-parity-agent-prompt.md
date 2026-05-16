# Many Faces Mobile — Portal Feature Parity (Phase 2+) — Agent Prompt

**Language:** All **new** technical prose you add to the repository because of this engagement—**code comments**, **`many_faces_mobile/README.md`**, **`docs/guides/mobile-expo-development.md`**, other touched guides, **commit messages**, and **PR descriptions**—must be **English**. This specification file is English by design.

**Mission:** After **Phase 1** ([`mobile-phase1-foundation-agent-prompt.md`](./mobile-phase1-foundation-agent-prompt.md)), evolve **`many_faces_mobile`** so it can **execute the same product contract** as **`many_faces_portal`**, including everything the portal exposes to **end users** through its SPA shell—not only **`PageGridLayout`**. Concretely, parity work **must** cover:

1. **Face page shell** — `FacePageView` composition: page title, optional **wall** section (`WallTicketsSection`) when `pageType.index === 'wall'`, optional **`gridSchema`** grid, and empty-state copy when there is no grid.
2. **Dynamic grid** — All `GridComponentType` blocks (§5), **`ComponentBlock`**-equivalent chrome (header / actions / footer / pagination / autoplay policy), **`CreatorModerationBadge`**, and forms (`*Form.tsx`) where the portal allows create/edit—subject to **native** editor policy for rich text (§2.3).
3. **Non-grid routes** — Profile directory and **face profile detail** (social: likes, comments, reviews), **stories** list route, **My submissions**, **global Users** list/detail (if product requires on mobile), **Component list/detail** browser, **ProfilePage** (“me”), **`ChatPage`** (AI hub), **`ChatRoomDetailPage`** (face chat room), and any other **declared** routes in `languageRouteElements.tsx` / `AppRoutes.tsx` unless explicitly **waived in writing** with ticket IDs.
4. **Shell and global UX** — `Header` / `Footer` / `LanguageSwitcher`, **settings** side panel (`features/settings`), **`MessengerTab`**, **`NotificationsTab`**, **`StoriesCreateTopPanel`**, **`WallTicketCreateTopPanel`**, **`FaceRoleSelectPanel`** / first-visit private-face flows—either implemented or a **documented minimal subset** approved by product.
5. **Data and auth plumbing** — **`ApiClient` + `faceApiRouting`** semantics without `window` (pure port + tests), **TanStack Query**, **`useMeCapabilities`**, and **logout** that clears Query cache and tears down SignalR.
6. **Realtime** — All hub products the portal uses: **`/hubs/messenger`**, **`/hubs/chatroom`**, **`/hubs/chat`** (§10.1.1)—each tracked separately; no silent merging.
7. **REST surface** — Every `many_faces_portal/src/api/services/*.ts` module must appear in a **parity matrix** (ported / not applicable / deferred + reason)—see §3.8.

**Non-goals remain:** DOM **`react-grid-layout`** / **Quill** inside RN; **`many_faces_admin`** operator UI; **new** backend resources without coordinated API work.

**Primary success criterion:** A user with the same account and face selection can **complete the same high-value journeys** on mobile as on web: open a face home page (including **wall** pages), consume **grid** and **non-grid** routes, use **shell affordances** at least at the agreed minimal subset, open **detail** screens with correct **moderation** / **owner-edit** gates, create content where capabilities allow, receive **realtime** updates where hubs apply, and see **My submissions** state—subject to **documented** platform deltas (URL shape, toast library, optional deep links, admin-only grid authoring).

**Automated quality bar:** No feature increment is **complete** until **all** repository-required checks for `many_faces_mobile` pass locally the same way CI runs them (**§13.0**). New or ported logic must ship with **tests** that cover **normal paths plus the edge cases in §13.1** relevant to that change—**not** only the happy path. Agents must **run** `yarn test` (and the full §13.0 command block) after each substantive edit and **fix** failures before requesting review.

**Canonical human guide:** Keep [`docs/guides/mobile-expo-development.md`](../guides/mobile-expo-development.md) accurate whenever commands, env vars, native capabilities, or CI steps change.

---

## 1. Relationship to Phase 1 and to the web portal

| Layer | Phase 1 (`many_faces_mobile`) | This prompt (Phase 2+) |
| ----- | ----------------------------- | ------------------------ |
| Config | `GET /api/faces/config`, `FaceConfigProvider`, face storage | Reuse; extend with **page-level** navigation targets and invalidation rules when config reloads |
| Auth | Password + refresh, `rememberMe`, SecureStore | Reuse; align **logout** with Query cache clears and SignalR teardown |
| Capabilities | TanStack Query + **`useMeCapabilities`** / **`meCapabilitiesClient`** (portal: `MeCapabilitiesWarmup` + same hooks) | Extend **UI gating** aligned with portal helpers where new surfaces need ACL |
| Pages / grid | Placeholder list → `PlaceholderScreen` | **`FacePageScreen`** mirroring **`FacePageView`** (wall + grid + empty) + **`MobilePageLayout`** for `gridSchema` |
| **Shell + chrome** | Minimal `AppShell` | **`Header` / `Footer` / language / settings / messenger / notifications` parity** (full or documented subset) |
| **HTTP client** | `httpClient` only | **`ApiClient` + face prefix** parity with `faceApiRouting` (no `window`) |
| Realtime | None | **Three** hubs: `/hubs/messenger`, `/hubs/chatroom`, `/hubs/chat` — tracked separately (§10) |
| Moderation UX | Documented as out of scope | **My submissions**, badges, detail **edit/delete/resubmit** gates |

The portal remains the **reference implementation** for ambiguous behaviour. Before inventing a new rule, **read the portal source** listed in **§3**.

---

## 2. Hard scope boundaries

### 2.1 In scope

- **Submodule:** `many_faces_mobile/` only for application code; **monorepo glue** (`many_faces_main/.github/workflows/ci.yml`, `scripts/*.sh`, `docs/guides/*`) may be updated when required for CI/docs parity.
- **Backend contract:** HTTP **only** to `many_faces_backend` (same origins and paths as portal). **No** direct gRPC from the handset to `many_faces_ai`.
- **Parity targets:** User-facing **`many_faces_portal`** routes, contexts, hooks, and grid components—not **`many_faces_admin`** (no admin grid editor on mobile unless product explicitly expands scope later).

### 2.2 Explicitly out of scope (unless product re-opens)

- **Pixel-perfect** reproduction of **CSS breakpoint drag** from `react-grid-layout` admin previews.
- **Replacing** backend moderation policy or adding new REST resources without a coordinated **`many_faces_backend`** change (mobile may **consume** existing APIs only).
- **Expo Router** migration (Phase 1 forbade it; this prompt **does not** require reversing that decision—stay on **React Navigation** unless a separate ADR approves Router).

### 2.3 Platform deltas (allowed, must be documented)

- **URL vs stack:** Browser uses `/:lang/:faceIndex/...`; mobile uses **navigation state**. Document the mapping table in `many_faces_mobile/README.md` when shipping Phase 2+.
- **localStorage-only features:** Portal `PageGridLayout` reads **`component-settings-*`** autoplay from `localStorage`. On mobile, use **`@react-native-async-storage/async-storage`** (or SecureStore for non-sensitive prefs) with **the same key prefix** only if product requires cross-platform continuity; otherwise implement **mobile-local** persistence and document the divergence.
- **Rich text:** Portal uses **`react-quill-new`**. On mobile, prefer **native-friendly** editing (plain text / Markdown / future native editor)—**do not** bundle Quill inside RN. If parity demands rich text, specify a **native** editor dependency in a dedicated PR with bundle-size evidence.

---

## 3. Authoritative references (read before coding)

### 3.1 Portal — routing and shell

- `many_faces_portal/src/App.tsx` — thin shell; providers.
- `many_faces_portal/src/routes/AppRoutes.tsx` — chrome, settings side panel, grid top panels.
- `many_faces_portal/src/routes/languageRouteElements.tsx` — guest vs protected, lazy page imports.
- `many_faces_portal/src/routes/lazyPages.tsx` — code-splitting entry points.
- `many_faces_portal/src/contexts/FaceConfigContext.tsx` — `getFaceHomePath`, `availableFaces`, selection persistence semantics.
- `many_faces_portal/src/contexts/AuthContext.tsx` — token lifecycle, `MeCapabilitiesWarmup`.
- `many_faces_portal/src/contexts/MessengerContext.tsx` — SignalR messenger hub.
- `many_faces_portal/src/contexts/GridTopPanelContext.tsx` — create flows from grid header.

### 3.2 Portal — grid system

- `many_faces_portal/src/components/PageGridLayout.tsx` — **parses `gridSchema` JSON**, maps `componentType` → React component, wires pagination + autoplay orchestration.
- `many_faces_portal/src/components/ComponentBlock.tsx` — shared header, actions, footer, settings persistence hooks.
- `many_faces_portal/src/components/grid/*` — concrete block implementations (fetch hooks, empty states, create entry points).

### 3.3 Portal — API and ACL

- `many_faces_portal/src/contexts/ApiContext.tsx` + `many_faces_portal/src/api/ApiClient.ts` — **typed** client instance; recreates when token changes.
- `many_faces_portal/src/api/faceApiRouting.ts` — **authoritative** face-prefix / exempt-path rules (`applyFacePrefixToRequestUrl`, `scopePathForCurrentFace`, `absoluteScopedUrl`, `isApiPathExemptFromFacePrefix`). Mobile must port **pure** subsets + tests; **do not** depend on `window` in those pure modules.
- `many_faces_portal/src/api/services/*.ts` — domain REST wrappers (`AlbumsService`, `BlogsService`, `ReelsService`, `storiesApi`, `wallTicketsApi`, `faceProfilesApi`, `ChatRoomsService`, `MessagesService`, `NotificationsService`, social graph services, …). Use this folder as the **checklist** when arguing API parity.
- `many_faces_portal/src/hooks/api/*` — TanStack Query usage; stale times; `enabled` guards (`useAuthApi`, `useProfileApi`, …).
- `many_faces_portal/src/hooks/api/useMeCapabilities.ts`, `many_faces_portal/src/api/meCapabilitiesClient.ts`.
- `many_faces_portal/src/acl/permissions.ts` — capability keys; align naming with backend `AclPermissionKeys`.

### 3.4 Portal — moderation / submissions

- `many_faces_portal/src/pages/MySubmissionsPage.tsx` (and `.scss`).
- `many_faces_portal/src/hooks/api/useMyContentSubmissionsApi.ts`.
- `many_faces_portal/src/utils/contentModeration.ts` + tests.

### 3.5 Backend and product docs

- OpenAPI / Swagger from `many_faces_backend` for codegen or manual client maintenance.
- [`docs/guides/ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md) — workflow, statuses, public filtering rules.
- [`APP_CONTEXT.md`](../../APP_CONTEXT.md) — product north star, placeholder policy §8.4.

### 3.6 Mobile — current baseline

- `many_faces_mobile/src/navigation/RootNavigator.tsx` — guest vs auth stacks.
- `many_faces_mobile/src/contexts/FaceConfigContext.tsx`, `AuthContext.tsx`.
- `many_faces_mobile/src/api/httpClient.ts`, `many_faces_mobile/src/api/getFacesConfig.ts`, `many_faces_mobile/src/api/meCapabilitiesClient.ts`, `many_faces_mobile/src/hooks/api/useMeCapabilities.ts` (TanStack Query).
- `many_faces_mobile/src/api/types/facesConfig.ts` — must stay aligned when backend extends `PageConfig`.

### 3.7 Portal inventory — surfaces easy to miss when only `PageGridLayout` is studied

Agents often anchor on `PageGridLayout.tsx` + `components/grid/*`. The portal also ships the following **first-class** behaviours; parity work must account for them explicitly:

| Area | Primary files | Parity hint for mobile |
| ---- | --------------- | ---------------------- |
| **Face page shell** | `components/FacePageView.tsx` | When `page.pageType.index === 'wall'`, the portal renders **`WallTicketsSection`** **above** the optional `gridSchema` grid (`PageGridLayout`). Mobile must implement the same **conditional**: wall list is **not** only the `ad` grid block—treat **`wall` page type** as a dedicated composition path. |
| **Wall tickets** | `components/WallTicketsSection.tsx`, `components/WallTicketDetailPanel.tsx`, `api/services/wallTicketsApi.ts` | Full wall UX (pagination, selection, refresh key from `AppRoutes` when a ticket is created) is separate from **`Ad`** tiles that also hit wall-ticket APIs inside grid blocks. |
| **API client + face prefix** | `contexts/ApiContext.tsx`, `api/ApiClient.ts`, `api/faceApiRouting.ts` | Portal requests use **`ApiClient`** + **`applyFacePrefixToRequestUrl`** / **`scopePathForCurrentFace`** derived from **`window.location`**. Mobile has **no pathname**; you must re-derive the **effective face segment** from navigation state + `selectedFace.index` and feed it into the same logical rules (see `facePathRouting` / `isApiPathExemptFromFacePrefix` tests in `api/__tests__/facePathRouting.test.ts`). |
| **SignalR hub builder** | `api/signalr/buildAuthenticatedHubConnection.ts` | Chat rooms reuse this helper; **align mobile** hub construction with it (URL via `absoluteScopedUrl` equivalent). |
| **Third hub — AI chat page** | `pages/ChatPage.tsx` | Uses **`HubConnectionBuilder`** directly on **`/hubs/chat`** with `ReceiveAiMessage` — **not** the same protocol as **`MessengerContext`** or **`ChatRoomDetailPage`**. Full portal parity may require **three** distinct realtime integrations unless product explicitly drops AI chat on mobile. |
| **Chat room detail route** | `pages/ChatRoomDetailPage.tsx`, `api/services/ChatRoomsService.ts` | REST load + join flows + SignalR message stream; parity is more than `chatRoom` grid tile. |
| **Dynamic component type browser** | `pages/ComponentListPage.tsx`, `pages/ComponentDetailPage.tsx`, `components/ComponentListView.tsx` | Routes `list/:componentTypeId` and `detail/:componentTypeId/:entityId` under `/:lang` — **not** represented in `gridSchema` alone. |
| **Global users directory** | `pages/UsersPage.tsx`, `pages/UserDetailPage.tsx` | Cross-face user admin-style lists (distinct from **face profile directory** under `/:faceIndex/profiles`). |
| **Own profile (auth user)** | `pages/ProfilePage.tsx` | Simple “me” profile from `AuthContext.user` — separate from **`FaceProfileDetailPage`**. |
| **Face profile social** | `pages/FaceProfileDetailPage.tsx`, `api/services/faceProfilesApi.ts` | Likes, comments, reviews (and `allowRecensions` / face rules) — much richer than “open profile card”. |
| **Stories composer** | `components/StoriesCreateTopPanel.tsx`, routes in `routes/AppRoutes.tsx` | Top-level create UI for stories with `wallRefreshKey` coupling — not only inside grid footers. |
| **Wall ticket composer** | `components/WallTicketCreateTopPanel.tsx` | Same pattern for wall tickets + refresh semantics. |
| **First-visit / role UX** | `components/FaceRoleSelectPanel.tsx`, `api/services/FaceRolesService.ts` | `AppRoutes` gates behaviour when user enters a private face (`isFirstVisitToFace`, `myFaceRoleIntroCompleted`) — mobile needs an equivalent flow or a documented waiver. |
| **Settings side panel** | `features/settings/*`, `routes/AppRoutes.tsx` | Messenger settings, notifications settings, tabs—large surface; either **phase** into parity or document **subset** with product sign-off. |
| **Messenger + notifications tabs** | `components/MessengerTab.tsx`, `components/NotificationsTab.tsx`, `api/services/MessagesService.ts`, `NotificationsService.ts` | Even if grid omits chat tiles, users may still expect **inbox / notifications** entry points from shell parity. |
| **Social graph APIs** | `FriendsService.ts`, `FriendRequestsService.ts`, `UserFollowsService.ts`, `UserBlocksService.ts` | Used from profile / social tabs—omit only with explicit product deferral. |
| **Language + deep links** | `components/LanguageRouter.tsx`, `components/LanguageSwitcher.tsx`, `hooks/useLocalizedLink.ts`, `routes/useFaceRouteEntries.ts` | Web derives locale + face from URL; mobile must decide where **`i18n.language`** lives vs navigator and how **`routeTranslations`** from `PageConfig` map to future deep links. |
| **Toasts** | `react-toastify` in `AppRoutes` / pages | Mobile should use a **single** non-blocking feedback primitive (`react-native-toast-message` or similar)—document mapping from portal `toast.*` call sites during port work. |
| **Moderation badge UI** | `components/grid/CreatorModerationBadge.tsx` | Grid blocks show creator-safe moderation badges—mirror helpers from `contentModeration.ts`, not ad-hoc strings. |

### 3.8 Exhaustive REST service modules (`many_faces_portal/src/api/services/`)

Use this checklist when building the **parity matrix** (§7 / Appendix L). File names are **canonical** as of the prompt authoring date; if the portal adds services, extend this list in the same PR that introduces the new API consumer.

| Module | Typical domain | Mobile parity notes |
| ------ | ---------------- | ------------------- |
| `AlbumsService.ts` | Albums CRUD + list | Face-scoped URLs; moderation fields on create/read. |
| `AuthService.ts` | Auth helpers if present | Align with mobile `AuthContext` / token storage. |
| `BlogsService.ts` | Blogs | Rich text policy §2.3. |
| `ChatRoomsService.ts` | Rooms, join, messages | Pairs with **`/hubs/chatroom`**. |
| `FaceRolesService.ts` | Role intro / selection | Pairs with **`FaceRoleSelectPanel`**. |
| `FacesService.ts` | Face metadata | Rarely called from grid; config already loads faces. |
| `FriendRequestsService.ts` | Incoming/outgoing requests | Social shell / profile. |
| `FriendsService.ts` | Friends list | Social shell / profile. |
| `MessagesService.ts` | Messenger REST (if any) + fetch | Pairs with **`MessengerContext`**. |
| `NotificationsService.ts` | Notifications feed | Pairs with **`NotificationsTab`**. |
| `OAuth2Service.ts` | Token (if used directly) | Mobile already uses password/refresh; verify no duplicate divergent paths. |
| `PageTypesService.ts` | Page types | `ComponentListView` / admin-driven discovery. |
| `PagesService.ts` | Pages | If mobile ever fetches single page JSON beyond config. |
| `ReelsService.ts` | Reels + media | `faceId` query semantics. |
| `UserBlocksService.ts` | Block user | Profile / safety flows. |
| `UserFollowsService.ts` | Follow/unfollow | Profile / social. |
| `UsersListService.ts` / `UsersService.ts` | Global users | `UsersPage` / `UserDetailPage`. |
| `faceProfilesApi.ts` | Face-scoped profiles | Directory + **`FaceProfileDetailPage`** depth. |
| `storiesApi.ts` | Stories | List + create flows. |
| `wallTicketsApi.ts` | Wall tickets | **`WallTicketsSection`** + **`Ad`** blocks. |

Also scan **`many_faces_portal/src/api/services/__tests__/`** for behavioural edge cases to port into mobile Jest tests when logic is duplicated.

### 3.9 Shell and workspace files (portal `AppRoutes` + `shell/` + `components/` chrome)

When auditing parity, open these **in addition** to grid files:

- `many_faces_portal/src/routes/AppRoutes.tsx` — provider stack order, `wallRefreshKey`, settings open state, grid top panel, `MessengerProvider`, `FaceConfigProvider` boundaries.
- `many_faces_portal/src/shell/AppWorkspace.tsx`, `many_faces_portal/src/shell/AppContentArea.tsx` — layout composition.
- `many_faces_portal/src/components/Header.tsx`, `Footer.tsx`, `LanguageSwitcher.tsx`, `MainLogo.tsx`.
- `many_faces_portal/src/components/StoriesCreateTopPanel.tsx`, `WallTicketCreateTopPanel.tsx`, `GridTopPanelContent.tsx`.
- `many_faces_portal/src/components/FaceRoleSelectPanel.tsx`, `GuestRedirects.tsx`, `SyncFaceFromProfileRoutes.tsx`.
- `many_faces_portal/src/hooks/useWallHostViewer.ts` — wall host create gate.

---

## 4. Architecture — `gridSchema` on React Native (mandatory design)

### 4.1 Why `react-grid-layout` is not portable

The portal imports:

- `ResponsiveGridLayout`, `useContainerWidth`, `verticalCompactor` from **`react-grid-layout`** (`PageGridLayout.tsx`).
- CSS assets: `react-grid-layout/css/styles.css`, `react-resizable/css/styles.css`.

These libraries assume a **DOM**, **mouse-driven resize**, and **CSS layout** primitives that **do not exist** in React Native. **Do not** attempt to run them inside a **`WebView`** for the whole app as a default strategy—that path creates accessibility, performance, and bridge maintenance debt.

### 4.2 Required approach — Schema-driven **native** layout engine

Implement a **first-party** module (suggested path: `many_faces_mobile/src/grid/`—exact tree is up to the implementer) that:

1. **Parses** `PageConfig.gridSchema` **identically** to the portal’s JSON contract (see §5). Invalid JSON → user-visible error component + dev-only `logger` detail.
2. **Normalizes** items into a **sort order** for mobile v1: sort by **`y`**, then **`x`** (same reading order as compact top-left grid). Document that **admin free-form positioning** on web may not visually match mobile v1; mobile v1 prioritises **stable order** and **correct face scoping** over pixel alignment.
3. **Maps breakpoints:** Portal uses `breakpoints` + `cols` per breakpoint key (`lg`, `md`, …). On RN, derive an **active breakpoint key** from `Dimensions.get('window').width` using the same numeric thresholds as `schema.breakpoints`. If width falls between definitions, pick the **largest breakpoint whose min width ≤ current width** (document tie-breaking).
4. **Maps layout modes:**
   - `componentType` ending with **`Carousel`** → horizontal **`FlatList`** (or `FlashList` if adopted) with snap or paging; respect `HAS_FOOTER` parity from portal for footer visibility rules.
   - `componentType` ending with **`Grid`** → **virtualized** two-dimensional feel: pragmatic mobile v1 is often **vertical list of rows** where each row is a horizontal list; if complexity is too high for first PR, **collapse to single-column vertical list** of cards with documented waiver in PR **and** a ticket reference for true grid parity.
   - **Single** variants (`album`, `blog`, …) → one primary card/tile region using the same data hooks as portal.
5. **Passes props** into native **`Block`** components mirroring `ComponentBlock` responsibilities: **`title`**, **`icon`**, **`boundChatRoomId`**, **`item.i`** as stable React `key`, pagination callbacks, autoplay policy (see §2.3 for persistence divergence).

### 4.3 Performance guardrails

- Lists beyond trivial length **must** use **`FlatList`** (or **`FlashList`** if the team standardizes it) with **`keyExtractor`** stable ids, **`memo`** row components, and **`onEndReached`** only where product requires infinite scroll.
- Images: use **`expo-image`** (or React Native `Image`) with explicit **width/height** or aspect-ratio to control CLS-like jumps; prefer **`contentFit`** semantics documented per block.
- Avoid **synchronous logging** in render paths (mirror portal performance prompts).

### 4.4 Testing the layout engine in isolation

Extract **pure functions**: `parseGridSchema(json: string)`, `sortGridItems(items)`, `selectActiveBreakpoint(width, breakpoints)`, `mobileLayoutPlan(schema, width)` returning a deterministic ordered list of `{ item, layoutMode }`. Cover with **Jest** in `many_faces_mobile` without device snapshots—edge vectors are listed in **§13.1** (`parseGridSchema` / layout / breakpoint rows).

### 4.5 Note on `verticalCompactor` (portal) vs mobile sort

The portal passes layouts through **`verticalCompactor`** from `react-grid-layout` before rendering. Mobile **v1** uses deterministic **`y` then `x`** sorting (§4.2). If product later demands closer visual parity, document a **v2** plan (e.g. pack rows using `rowHeight` + `h` math) rather than blocking v1 on pixel-perfect compaction.

---

## 5. `gridSchema` JSON contract (mirror of portal behaviour)

The portal defines (see `PageGridLayout.tsx`):

```typescript
// Reference copy — keep in sync with many_faces_portal/src/components/PageGridLayout.tsx
export type GridComponentType =
  | 'album'
  | 'albumGrid'
  | 'albumCarousel'
  | 'ad'
  | 'adGrid'
  | 'adCarousel'
  | 'blog'
  | 'blogGrid'
  | 'blogCarousel'
  | 'chatRoom'
  | 'chatRoomGrid'
  | 'chatRoomCarousel'
  | 'userProfile'
  | 'userProfileGrid'
  | 'userProfileCarousel'
  | 'reel'
  | 'reelGrid'
  | 'reelCarousel'
  | 'story'
  | 'storyGrid'
  | 'storyCarousel';

interface GridItem {
  i: string;
  x: number;
  y: number;
  w: number;
  h: number;
  minW?: number;
  minH?: number;
  label?: string;
  componentType?: GridComponentType;
  title?: string | null;
  icon?: string | null;
  boundChatRoomId?: number;
}

interface GridSchema {
  items: GridItem[];
  breakpoints: Record<string, number>;
  cols: Record<string, number>;
  rowHeight: number;
}
```

**Unknown `componentType`:** Render a **non-crashing** fallback panel showing `item.i`, raw type string, and a link to open an issue template in dev builds; in production builds, show a neutral “Unsupported block” string from i18n.

**Missing `componentType` on an item:** Treat as **unsupported** with telemetry (`logger.warn`) including `faceId` / `pageId` if available.

---

## 6. Navigation model — mapping web routes to React Navigation

### 6.1 Typed routes

Extend `many_faces_mobile/src/navigation/types.ts` beyond `Home | Login | Register | Placeholder` to include at minimum:

- **`FaceHome`** — same semantics as portal authenticated home for selected face’s `pageType.index === 'home'`.
- **`FacePage`** — params: `{ pageId: number }` or `{ pageTypeIndex: string }` **plus** `faceIndex: string` if multi-face navigation requires explicit params (prefer **numeric `page.id`** as stable where duplicates exist).
- **Detail routes** mirroring portal: `AlbumDetail`, `BlogDetail`, `ReelDetail`, `Story…`, `Profile…`, `ChatRoom`, `MySubmissions`, etc.

**Rule:** Every new screen **must** read **`selectedFace` from `FaceConfigProvider`** and refuse to fetch when `selectedFace` is null (mirror portal transition guards).

### 6.2 Guest vs authenticated

Mirror `GuestRoute` / `ProtectedRoute` semantics from the portal:

- **Public face pages** may render for guests when `page` is public in config.
- **Private faces** require auth before showing non-login/register content.

### 6.3 Optional later: deep linking

Universal Links / App Links are **not required** for first merge, but the navigation types and path builders should be structured so **`linking` config** can be added without renaming every route param.

### 6.4 Web-to-mobile route parity (documentation template)

> **Status (2026-05-16):** Shipped routes + deferred portal targets documented in [`many_faces_mobile/docs/portal-route-parity.md`](../../many_faces_mobile/docs/portal-route-parity.md) (README links there). Extend that file for every new route; do not duplicate a second canonical table in README.

Maintain a table (README or `many_faces_mobile/docs/portal-route-parity.md`) with **at least** these rows; extend for every new portal route:

| Portal (conceptual) | Web path pattern | Mobile screen / params | Auth | Notes |
| ------------------- | ---------------- | ------------------------ | ---- | ----- |
| Guest index | `/:lang/` → redirect | `GuestNavigator` home | Guest | Match `GuestRedirectToFaceHome`. |
| Login / Register | `/:lang/:face/...` public pages | `Login` / `Register` | Guest | `GuestRedirectToFacePath` fallback semantics. |
| Face home | `/:lang/:face/home` | `FaceHome` | Auth (private face) | From `HomePageProtected` + `FacePageView` for home `PageConfig`. |
| Arbitrary face page | `/:lang/:face/:pagePath` | `FacePage` `{ pageId }` | Mixed | `FacePageView` + wall branch. |
| Profiles list | `/:lang/:faceIndex/profiles` | e.g. `FaceProfilesList` | Auth | Web wraps `SyncFaceFromProfileRoutes`—replicate **face index sync** when adding deep links. |
| Profile detail | `/:lang/:faceIndex/profile/:userId` | `FaceProfileDetail` | Auth | URL-decode `userId` as portal does. |
| Stories list | `/:lang/:faceIndex/stories` | `StoriesList` | Auth | |
| My submissions | under `/:lang/...` (see `useLocalizedLink` / route translations) | `MySubmissions` | Auth | Confirm exact path segments per locale. |
| Component list/detail | `/:lang/list/:id`, `/:lang/detail/...` | `ComponentList`, `ComponentDetail` | Auth | |
| Users | `/:lang/users`, `/:lang/users/:id` | `Users`, `UserDetail` | Auth | |
| Profile (me) | `/:lang/profile` | `Profile` | Auth | JWT user only. |
| AI chat | route from portal route map | `Chat` | Auth | Hub `/hubs/chat`. |
| Chat room | from grid / in-app navigation | `ChatRoom` `{ roomId: number }` | Auth | Hub `/hubs/chatroom`; methods `JoinRoom`, `LeaveRoom`, `SendRoomMessage`. |

### 6.5 Language, `routeTranslations`, and static route segments

- Portal **`LanguageRouter`** sets locale from URL segment; mobile must keep **`i18n.changeLanguage`** in sync with user choice (see `many_faces_portal/src/contexts/AppContext.tsx` for `changeLanguage` patterns) and persist preference if the portal does.
- **`ROUTES_WHERE_SECOND_SEGMENT_IS_NOT_FACE`** in `faceApiRouting.ts` (`login`, `register`, `homepage`, `profile`, `users`, `chat`) interacts with **`getAllRouteTranslations`**. When porting face-prefix resolution, inject **explicit navigation state** (`{ language, faceIndex, isStaticLangLevelRoute }`) into pure helpers—**never** read `window` inside shared modules.
- `PageConfig.routeTranslations` must be preserved for **future** deep links even if v1 mobile uses fixed internal route names.

---

## 7. Data layer — TanStack Query + HTTP client

### 7.1 Install and wire TanStack Query v5

- Add `@tanstack/react-query` to `many_faces_mobile`.
- Create a **`QueryClientProvider`** at the root (inside `App.tsx` or a thin `Providers.tsx`), with defaults **documented** in README (staleTime, gcTime, retry policy). Align philosophy with `many_faces_portal/src/.../QueryProvider.tsx` but tune for mobile (e.g. focus refetch behaviour on app foreground—use `AppState`).

### 7.2 Query key conventions

Use **hierarchical keys** including:

- `['faces', 'config']` — invalidated on logout / base URL change / manual refresh.
- `['face', faceId, 'page', pageId]` — page-specific queries where applicable.
- `['face', faceId, 'albums']`, `['face', faceId, 'blogs']`, … — list endpoints mirroring portal hooks.

### 7.3 API surface strategy (pick one per PR series, document choice)

- **Option A — OpenAPI codegen:** Reuse the same `openapi-typescript-codegen` output style as the portal **or** generate into `many_faces_mobile/src/api/generated/` from the same `swagger.json`. Pros: DTO parity. Cons: bundle size; needs axios/fetch adapter decision.
- **Option B — Thin typed wrappers:** Hand-written functions per domain using `httpClient.ts`. Pros: smaller initial diff. Cons: drift risk—**must** add Vitest/Jest contract tests comparing sample responses to portal types.

Either way, **every** request that is face-scoped in the portal **must** apply the same **URL prefix** rules (`/:lang/:faceIndex` on web translates to **client-side path prefixing** on mobile—mirror `faceApiRouting` logic in a shared pure module `many_faces_mobile/src/api/faceScope.ts` with unit tests).

### 7.4 Error and offline integration

- Reuse `OfflineError` semantics from Phase 1.
- Map HTTP **401** to refresh flow; if refresh fails, **clear Query cache** and navigate to Login (same UX spirit as portal).

### 7.5 `ApiClient` and face-prefix rules (must match `faceApiRouting.ts`)

Port the following **pure** behaviours into mobile with Jest coverage (vectors from `facePathRouting.test.ts`):

- **`isApiPathExemptFromFacePrefix`**: `/api/oauth2/*`, `/api/auth/*` must **not** receive a face prefix.
- **`prependFaceBeforeApi`**: `/api/foo` → `/{face}/api/foo`; idempotent when path already has `/{segment}/api/`.
- **`prependFaceBeforeHubs`**: `/hubs/foo` → `/{face}/hubs/foo`; idempotent when already prefixed.
- **`applyFacePrefixToRequestUrl`**: absolute URLs whose host matches API base should rewrite path portion only.

Mobile must supply **`facePrefix`** from `selectedFace.index` (or `public` / default rules matching portal `getEffectiveFacePrefix` semantics for unscoped routes). Document the **public face** / `defaultFacePrefix` handling copied from `env.defaultFacePrefix` portal usage.

### 7.6 Query invalidation matrix (mandatory design)

| Event | Invalidate / reset |
| ----- | ------------------- |
| Logout | All user-scoped queries + messenger/chat caches + cancel in-flight requests where applicable. |
| `selectedFace` change | All `['face', previousFaceId, ...]` keys; refetch `faces` config if needed. |
| Successful wall ticket create | Whatever keys power **`WallTicketsSection`** and **`Ad`** lists for that face + bump `wallRefreshKey` equivalent. |
| Successful story create | Stories list queries + any home grid queries showing stories. |
| Moderation state transition | `MySubmissions`, affected entity detail, public list queries for that content type. |

---

## 8. Capabilities and ACL

### 8.1 Fetch model

- On session bootstrap and after login, ensure **`GET /api/me/capabilities`** runs (Phase 1 warm-up already exists—extend to **cached query**).
- Expose **`useMeCapabilities()`** returning `{ data, isLoading, error, refetch }` aligned with portal consumer expectations.

### 8.2 UI gating

- Port or re-implement the **pure** parts of `many_faces_portal/src/acl/permissions.ts` (no DOM imports). **Unit-test** capability matrix tables mirroring portal tests where feasible.
- **Do not** mount heavy editors when capability denies—prefer **omitting** the subtree (performance prompt alignment).

### 8.3 `GridTopPanelContext` on mobile

On web, `AppRoutes.tsx` wires **`GridTopPanelProvider`** and top panels (**`StoriesCreateTopPanel`**, **`WallTicketCreateTopPanel`**, settings) with `gridTopPanel` state. Mobile must choose **one** equivalent pattern:

- **Option A — React Context** mirroring `GridTopPanelContext.tsx` (modal sheets / full-screen forms).
- **Option B — Navigation** to dedicated `CreateStory`, `CreateWallTicket` screens with params.

Either way, preserve: **capability checks** before opening, **dismiss** behaviour, and **refresh** contracts (`wallRefreshKey`, story list invalidation) documented in PR.

---

## 9. Block-by-block implementation notes (portal parity)

For each `GridComponentType`, open the portal’s `many_faces_portal/src/components/grid/<Name>.tsx` (or folder) and mirror:

- **Which REST endpoints** are called, with which **query params** (`faceId`, pagination, filters).
- **Guest vs auth** visibility rules (sign-in gates, empty copy).
- **Create** entry points (`GridTopPanelContext` on web → mobile: FAB, header button, or inline—pick one pattern per block and document).

| `componentType` family | Portal starting points | Mobile notes |
| ---------------------- | ------------------------ | ------------ |
| `ad` / `adGrid` / `adCarousel` | Wall tickets APIs | Horizontal list for carousel; watch image URL nullability |
| `album*` | Albums list + detail routes | Create flow + pending approval copy |
| `blog*` | Blogs + rich text | No Quill—use staged native editor approach |
| `reel*` | Reels + media | Respect `faceId` query parity; video player choice (`expo-av`) |
| `story*` | Stories list | Expiry / published filters as portal |
| `chatRoom*` | Chat rooms + SignalR | **Requires** §10 before claiming parity |
| `userProfile*` | Profiles directory | Pagination; role subtitles; deep links to **`FaceProfileDetailPage`** social features (likes/comments/reviews), not only directory cards |

### 9.1 Non-grid pages and shell actions (must appear in navigation / parity docs)

These routes exist in `languageRouteElements.tsx` / `AppRoutes.tsx` and are **not** implied by implementing `gridSchema` alone:

- **`/:lang/:faceIndex/profiles`** and **`/:faceIndex/profile/:userId`** — face-scoped profile directory + detail (see §3.7).
- **`/:lang/:faceIndex/stories`** — stories list route (`StoriesListPage`).
- **`/my-submissions`** — creator moderation hub (already in §11).
- **`list/:componentTypeId`**, **`detail/:componentTypeId/:entityId`** — dynamic component listings.
- **`UsersPage` / `UserDetailPage`** — global user admin-style views under translated paths.
- **`ProfilePage`** — authenticated “my account” summary from JWT user claims.
- **`ChatPage`** — AI SignalR chat (§10.1.1).
- **Shell:** `Header`, `Footer`, `LanguageSwitcher`, **settings side panel** (`features/settings`), **`MessengerTab`**, **`NotificationsTab`**, **`StoriesCreateTopPanel`**, **`WallTicketCreateTopPanel`**, **`FaceRoleSelectPanel`** flows driven from `AppRoutes.tsx`.

### 9.2 Grid forms, editors, and shared UI (`components/grid/*`)

Beyond presentational `*.tsx` tiles, the portal ships **forms** and **editors** that mobile must track explicitly:

| File / area | Parity approach on mobile |
| ----------- | --------------------------- |
| `AlbumForm.tsx`, `BlogForm.tsx`, `ReelForm.tsx`, `ChatRoomForm.tsx` | Rebuild with **`react-hook-form` + `yup`** (already in mobile stack). Map every field to the same OpenAPI payload shape as portal submits. |
| `BlogQuillEditor.tsx` | **No Quill** — use plain `TextInput` v1, or a native markdown field; document delta. |
| `ChatRoomCard.tsx`, grid `*Carousel.tsx` / `*Grid.tsx` | Shared styling rules (pagination footer, `ComponentBlock` header actions). |
| `CreatorModerationBadge.tsx` | Import parity via shared **`contentModeration`** helpers + identical safe strings. |

When porting a form, **grep** the portal file for `toast.`, `useMutation`, `queryClient.invalidateQueries`, and **`useMeCapabilities`** gates—replicate the same sequence on mobile.

---

## 10. Realtime — SignalR (`@microsoft/signalr`)

### 10.1 Feasibility

The portal uses **`@microsoft/signalr`**. The same package can run in React Native **if** the JS runtime exposes WebSocket APIs compatible with the client’s transport defaults. Validate on **iOS simulator** and **Android emulator** early.

### 10.1.1 Three distinct hub products in the portal (do not merge blindly)

| Hub / feature | Entry | Relative path (illustrative) | Notes |
| ------------- | ----- | ---------------------------- | ----- |
| **Messenger** | `MessengerContext.tsx` | `/hubs/messenger` | Conversation list, typing, async message fan-out. |
| **Face chat room** | `ChatRoomDetailPage.tsx` via `buildAuthenticatedHubConnection` | `/hubs/chatroom` | Join / send / history; ties to `ChatRoomsService`. |
| **AI assistant chat** | `ChatPage.tsx` (manual `HubConnectionBuilder`) | `/hubs/chat` | `ReceiveAiMessage` events; separate UX from messenger. |

Mobile parity PRs should **name which hub** they implement; copying only `MessengerContext` is **insufficient** if product expects **ChatPage** and **chat rooms** too.

### 10.2 Implementation checklist (technical)

- **Hub URL:** Build from the same origin rules as portal (`absoluteScopedUrl` equivalent)—likely `EXPO_PUBLIC_API_BASE_URL` + hub path; respect HTTPS.
- **Prefer** `buildAuthenticatedHubConnection`-equivalent helper for hubs that already use it on web; **refactor web `ChatPage` to the shared helper** only if doing so is in-scope for the same PR and covered by tests (otherwise reproduce behaviour carefully on mobile).
- **Access token factory:** Async factory returning current bearer token; refresh on **401** from hub handshake if supported.
- **Lifecycle:** `AppState` transitions → reconnect policy; **logout** must **stop** all connections and clear handlers.
- **Duplication guard:** Ensure messenger vs chat room hubs do not double-subscribe after fast navigation (mirror portal deduping intent).

### 10.3 Tests

- Prefer **integration tests** behind mocked WebSocket if flaky; otherwise document **manual** hub smoke steps in `mobile-expo-development.md`.
- **Mandatory:** Still satisfy **§13.0** (full lint/typecheck/test/expo-doctor) and the **SignalR** row in **§13.1** for everything mockable (URL builder, token factory, teardown on logout).

### 10.4 Hub methods and events (verify against server when in doubt)

When implementing each hub, **re-read** the portal client and the **C# hub** in `many_faces_backend` if server method names differ.

| Hub | URL | Client `invoke` / `send` (from portal TS) | Client `connection.on` events (from portal TS) |
| --- | --- | ------------------------------------------ | ------------------------------------------------ |
| Messenger | `/hubs/messenger` | `SendChatMessage`, `AcceptMessageRequest`, `RejectMessageRequest` (see `MessengerContext.tsx`) | `ReceiveChatMessage`, `ReceiveMessageRequest`, `ReceiveFriendRequest`, `MessageRequestAccepted`, `MessageRequestRejected`, `ReceiveNotification` |
| Chat room | `/hubs/chatroom` | `JoinRoom`, `LeaveRoom`, `SendRoomMessage` | Inspect `ChatRoomDetailPage.tsx` for all `connection.on` handlers. |
| AI chat | `/hubs/chat` | `SendToAi` | `ReceiveAiMessage` |

**Reconnect:** All three builders use `withAutomaticReconnect()` in portal today—mirror and test **token refresh mid-session** (disconnect old connection with new token when refresh completes if required).

---

## 11. User content moderation parity (`My submissions`, detail gates)

- Port **`contentModeration.ts`** logic into `many_faces_mobile/src/utils/` (copy + adapt imports) or extract a future shared package—**do not** silently diverge label mappings.
- Implement **`MySubmissions`** screen consuming the same API as portal (`useMyContentSubmissionsApi` parity).
- Album/Blog/Reel **detail** screens: owner **edit/delete/resubmit** gates must match backend rules; never show raw AI diagnostics.

### 11.1 Detail pages — field-level parity checklist

For **`AlbumDetailPage`**, **`BlogDetailPage`**, **`ReelDetailPage`** (portal):

- Read **`approvalStatus`**, **`aiReviewStatus`**, rejection / resubmit reasons using **`contentModeration`** helpers only.
- **`?edit=1`** query on web → mobile **`route.params`** or screen options flag; same gate as portal before opening editor.
- **Delete** and **resubmit** actions: confirm portal’s **mutation + invalidation** targets (`MySubmissions`, lists, detail).

### 11.2 Public vs owner views

- **Owner** sees pending / rejected states where API allows; **other users** see **`Approved`-only** presentation on lists and grids—match portal defensive rendering even if backend is authoritative.

---

## 12. Internationalisation and accessibility

- Add `sk` / `cs` namespaces when the portal has equivalent keys for user-visible grid strings—start by mirroring **English** keys used in portal `common.json` where blocks already read `t(...)`.
- **Accessibility:** React Navigation headers, **`accessibilityRole`**, large hit targets (min 44pt), screen reader labels for carousel controls.

### 12.1 i18n key parity strategy

- Maintain a **key manifest** (spreadsheet or markdown in `many_faces_mobile/docs/`) listing portal `t('namespace:key')` usages per screen and the mobile JSON key adopted.
- For **new** mobile-only strings, use **`common:`** namespace consistently to avoid fragmentation.

### 12.2 RN-specific a11y

- **Focus order:** modals and side sheets must trap focus where platform supports it; document known gaps on Android.
- **Motion:** respect system **reduce motion** setting when implementing carousel autoplay or shell gradients (parity with portal `prefers-reduced-motion` goals).

---

## 13. Engineering quality gates

### 13.0 Definition of done — run the full suite (non-negotiable)

Treat **“implemented”** and **“merge-ready”** as distinct until automation is green.

**After each feature slice (or before every PR push), from `many_faces_mobile/` run the same checks CI enforces** (adjust if `package.json` scripts differ—verify against `many_faces_main/.github/workflows/ci.yml`):

```bash
corepack enable
yarn install --immutable
yarn lint
yarn typecheck
yarn test
npx expo-doctor
```

**Rules for agents:**

- **Do not** open a PR or hand off work as “done” if **any** of the above fails. **Diagnose, fix, re-run** until the full block passes.
- If a failure is **environmental** (e.g. local Node mismatch), fix `engines` / lockfile / docs—or document the **exact** CI image behaviour in `mobile-expo-development.md`—**do not** waive tests without written product + tech lead approval.
- **Prefer one final full run** after the last commit in a batch, not only after the first file edit.
- For changes that touch **monorepo scripts** or **CI**, also run the parent repo’s **`scripts/test-all.sh`** (or the documented subset) when reviewers expect cross-package green.
- **Never** commit secrets; env samples belong in **`.env.example`** only.

**PR hygiene:** In the PR description, state **which commands were run** and their outcome (or paste a short log tail). If a test is intentionally skipped, cite **ticket ID** and the **follow-up** that re-enables it.

### 13.1 Edge-case and regression tests (layered expectations)

**General:** When porting logic that already exists on the portal, **mine** `many_faces_portal/src/**/__tests__/**`, `*.test.ts`, `*.test.tsx`, and Vitest specs for **vectors** (inputs + expected outputs). Reuse the same cases in `many_faces_mobile` **Jest** where the behaviour is duplicated (especially `faceApiRouting`, ACL, `contentModeration`).

**Coverage principle:** For every **new pure function** or **state machine** (prefix rules, layout plan, moderation labels, invalidation map), add tests for **at least**: null/undefined inputs, empty collections, malformed payloads, boundary widths (breakpoint edges), and **idempotency** (calling twice does not double-prefix URLs).

| Layer | Minimum edge cases to cover with automated tests (unit or RTL) |
| ----- | ---------------------------------------------------------------- |
| **`parseGridSchema` / layout** | Invalid JSON / non-object root; `items` missing or not an array; **empty** `items`; item missing `i`, `x`, `y`, `w`, `h` (define safe defaults or reject—match portal tolerance); **duplicate `i`**; **unknown `componentType`**; schema with **no `breakpoints`**; width **exactly** on breakpoint boundary (both sides); **single item**; **very large** `y`/`x` sort stability (`y` then `x`). |
| **Breakpoint selection** | No matching breakpoint (fallback rule); unsorted breakpoint keys; zero/negative width clamping if applicable. |
| **Grid composition** | `gridSchema` **null/empty** with wall page vs non-wall; page with **wall + grid** vs **grid only**; `boundChatRoomId` present vs absent for `chatRoom*` types. |
| **`httpClient` / auth** | **401** with successful refresh + **single retry**; refresh **fails** → logout / cleared session; **concurrent** 401s (no refresh storm); request **without** token on public path; **logout** clears in-flight behaviour as defined. |
| **Face prefix (`faceScope` / routing)** | Paths in **`ROUTES_WHERE_SECOND_SEGMENT_IS_NOT_FACE`**; **`isApiPathExemptFromFacePrefix`** true/false matrix; `/api` and **`/hubs`** prefix behaviour; **double-apply** guard; missing **`faceIndex`** when face-scoped route expected; **language-only** static segments. |
| **TanStack Query** | `enabled: false` when guest/unauthenticated (mirror portal hooks); **stale** cache after mutation—assert **invalidation** keys from §7.6; **error** and **empty** query states for list screens (no infinite spinner). |
| **Capabilities / ACL** | Each **gate** used by the feature: capability **off** hides control; **on** shows it; **unknown** capability key defaults safely (match portal). |
| **`contentModeration` / submissions** | Every **status** combination the portal maps to copy/badge; **owner** vs **non-owner** branch; **missing** optional fields from API; `Approved` public vs pending **defensive** UI. |
| **Forms / mutations** | **Validation** errors from API; **network** failure; **optimistic** rollback if portal rolls back; submit **disabled** while pending. |
| **SignalR (where not E2E)** | **Pure helpers** (URL build, token attach) unit-tested; **connection state** reducer or hook: disconnected → connecting → connected; **reconnect**; **logout** closes connection (mock transport). Document **manual** hub smoke only where automation is flaky—and still run **unit** coverage for everything mockable. |
| **Navigation** | Missing/invalid route params → **fallback** screen or error UI (no red screen); **back** preserves expected stack; deep link params **sanitized** (`NaN` ids). |
| **i18n** | **Missing key** does not crash (fallback behaviour); interpolation with **empty** optional param if used. |

**React Native Testing Library (`@testing-library/react-native`):** Use for **stable leaf UI** (badges, empty states, primary buttons) when assertions add confidence without flaking on timers. **Mock** navigation (`NavigationContainer` test harness or mock `useNavigation`), **QueryClientProvider** with controlled `client`, and **network** via `msw` or `fetch` mocks consistent with the rest of the repo.

**Anti-patterns:** Skipping tests “because UI only” when the change introduces **branching logic**; snapshot-only tests for large screens (prefer targeted `getByRole` / `getByText` on critical strings); relying on **manual** checks alone for **pure** modules.

### 13.2 Per-feature checklist (tie tests to delivery)

When closing a phase row from **§15** or a checklist block in **Appendix A**, explicitly verify:

- [ ] New **pure** code has new **`*.test.ts`** (or co-located tests) with §13.1-relevant cases.
- [ ] Mutations have tests or RTL coverage for **invalidation** / UI feedback (or a documented exception with ticket).
- [ ] **No new** `console.log` of tokens or PII; logger redaction covered if new fields exist.
- [ ] **§13.0** command block run end-to-end **green** on the final commit.

### 13.3 Optional higher layers (document if adopted)

- **Maestro** / **Detox** E2E for critical flows (login → face home → open album) — not required for first grid PR, but **recommended** once core flows stabilise; add to CI only after flake control.
- **Storybook** for RN grid tiles — optional; prefer **component tests** with `@testing-library/react-native` for stable leaf components only.

### 13.4 Logging and PII

- Extend mobile **`logger.ts`** redaction rules if new headers or fields appear (e.g. hub payloads). Never log **message bodies** or **tokens**.

---

## 14. Documentation deliverables

Update as features land:

- `many_faces_mobile/README.md` — Roadmap section must shrink; **“What ships”** must grow with accurate bullets.
- `docs/guides/mobile-expo-development.md` — new env vars, native modules (e.g. `expo-image`, `expo-av`), SignalR smoke steps.
- Optionally add `many_faces_mobile/docs/portal-route-parity.md` if the route mapping table becomes large.

---

## 15. Suggested phased delivery (non-binding but ordered)

Phases are **sequential recommendations**; parallel work is allowed only when **merge conflicts** are controlled (e.g. one PR owns `navigation/types.ts`).

| Phase | Goal | Exit signal |
| ----- | ---- | ------------- |
| **2A** | **TanStack Query** + root provider; **`useMeCapabilities`**; **pure `faceApiRouting` port** + Jest (exempt paths, `/api` + `/hubs` prefix, idempotency); document §7.5 / §7.6 | **§13.0** fully green; **§13.1** face-prefix + auth rows for new code |
| **2B** | **`FacePageView` parity** component: title, **wall branch** (`pageType.index === 'wall'`) + **`WallTicketsSection`** equivalent + optional grid below; **empty state** when no `gridSchema` and not wall | **§13.0** green; Jest/RTL for wall vs non-wall composition if logic is non-trivial; manual smoke on wall + non-wall face |
| **2C** | **`MobilePageLayout`** + `parseGridSchema` pipeline; **read-only** `ad` + `userProfile` blocks end-to-end | **§13.0** green; **§13.1** layout + query empty/error cases; two faces, guest + auth smoke |
| **2D** | Remaining **grid read** blocks: `album*`, `blog*` (read), `reel*` (read), `story*`, `chatRoom*` list tiles | **§13.0** green; list **pagination/end** tests or RTL where applicable |
| **2E** | **Detail screens**: `AlbumDetail`, `BlogDetail`, `ReelDetail` (read-only first) | **§13.0** green; invalid `id` param handling (**§13.1** navigation row) |
| **2F** | **Face profile directory + `FaceProfileDetail`** (likes/comments/reviews) + **`ProfilePage` (me)** | **§13.0** green; social + ACL gates covered per **§13.1** |
| **2G** | **Stories list route** + **`StoriesCreateTopPanel`** parity (or deferred with ticket) | **§13.0** green; create → invalidation tested |
| **2H** | **Wall ticket top panel** + **`wallRefreshKey`** parity with grid/wall lists | **§13.0** green; refresh contract unit-tested or RTL |
| **2I** | **Forms + create** for album/blog/reel + **pending approval** copy + **`CreatorModerationBadge`** | **§13.0** green; **§13.1** forms + moderation rows |
| **2J** | **`MySubmissions`** + grouping + navigation to detail + **`?edit=1`** equivalent | **§13.0** green; **§13.1** moderation matrix |
| **2K** | **SignalR** — implement hubs in order: **`/hubs/chatroom`** (smallest UX surface) → **`/hubs/messenger`** → **`/hubs/chat`** (AI) unless product reorders | **§13.0** green; **§10.4** + mockable **§13.1** SignalR row; manual hub smoke doc if needed |
| **2L** | **Shell** — `Header`/`Footer`, `LanguageSwitcher`, **settings subset**, **MessengerTab**, **NotificationsTab** as per product minimal spec | **§13.0** green; RTL on shell leaf widgets where stable |
| **2M** | **Non-grid extras** — `UsersPage`/`UserDetail`, `ComponentList`/`ComponentDetail`, **`FaceRoleSelectPanel`** / first visit, **`ChatPage`** if deferred from 2K | **§13.0** green; matrix closed |
| **2N** | **i18n SK/CZ**, **reduce motion**, **FlashList**/**memo** pass, **toast** mapping complete | **§13.0** green; performance notes + **§13.1** i18n row |

---

## 16. Engagement rules for agents

- **Run tests before hand-off:** After implementing or refactoring a feature, execute the **§13.0** command block (and **§13.2** checklist). Treat failing **lint**, **typecheck**, or **Jest** as blocking—**fix first**, then continue feature work.
- **Do not** mark canonical `[ ]` items in **this** file as `[x]` unless the parent repo policy explicitly records a completed one-off engagement (see [`docs/prompts/README.md`](./README.md) checklist conventions). Instead, tick copies inside PR descriptions.
- **Stop and ask** only for product decisions that change security or moderation semantics; otherwise follow portal behaviour.
- Prefer **small PRs** per phase row in §15.

---

## Appendix A — Master task checklist (canonical unchecked)

**Convention:** Leave boxes **`[ ]`** in this file. Track completion in PRs/issues. Group headings are informational only.

### A — Foundation: Query, API scope, capabilities

- [ ] Add `@tanstack/react-query` and root `QueryClientProvider` wiring in `many_faces_mobile`.
- [ ] Document Query defaults (staleTime, gcTime, retry, refetch-on-app-foreground) in `many_faces_mobile/README.md`.
- [ ] Implement `QueryClient` **cache clear** on logout paths (auth + forced logout).
- [ ] Promote `GET /api/me/capabilities` from one-shot warm-up to a **`useMeCapabilities`** hook with stable query key.
- [ ] Port pure ACL helpers from `many_faces_portal/src/acl/permissions.ts` into mobile-safe modules (no browser APIs).
- [ ] Add Jest tests for ACL pure functions (vectors copied or mirrored from portal tests).
- [ ] Implement **`faceApiRouting` parity** as a pure module + unit tests (`many_faces_mobile/src/api/faceScope.ts` or equivalent).
- [ ] Ensure **every authenticated API call** uses the face-scoped prefix rules consistent with portal axios interceptor.
- [ ] Add `httpClient` integration tests (mock `fetch`) for 401 → refresh → retry once → logout on failure.

### B — Navigation and screen inventory

- [ ] Extend `AppStackParamList` (or modular navigators) with `FaceHome`, `FacePage`, and primary detail routes.
- [ ] Replace “all non-system pages → `Placeholder`” with **`FacePage` screen** that receives `pageId` / `pageTypeIndex`.
- [ ] Implement **guest/public** vs **private** page access mirroring portal guards.
- [ ] Wire `HomePlaceholderScreen` into real **`FaceHome`** when `pageType.index === 'home'` for selected face.
- [ ] Add navigation from grid blocks to **detail** routes with correct params (`albumId`, `blogId`, `reelId`, …).
- [ ] Add **back stack** behaviour consistent with Android/iOS expectations (headers, gestures).
- [x] Document **web route ↔ mobile route** mapping in [`many_faces_mobile/docs/portal-route-parity.md`](../../many_faces_mobile/docs/portal-route-parity.md) (§6.4).
- [ ] **`SyncFaceFromProfileRoutes` parity**: when navigating to profile/story routes, ensure **`selectedFace`** matches route `faceIndex` (or document divergent mobile model).
- [ ] **`useWallHostViewer`** (or equivalent): portal uses this for wall create affordance on wall pages—mirror capability gating or document waiver.

### C — `gridSchema` engine (native)

- [ ] Implement `parseGridSchema` pure function + Jest tests (valid JSON, invalid JSON, empty items).
- [ ] Implement `sortGridItems` (`y`, then `x`) + tests.
- [ ] Implement `selectActiveBreakpoint` using `schema.breakpoints` + tests.
- [ ] Implement `buildMobileLayoutPlan(schema, width)` returning ordered render plan + tests.
- [ ] Implement **`MobilePageLayout`** (name flexible) rendering a **ScrollView** or nested lists according to plan.
- [ ] Implement unknown `componentType` fallback UI + `logger.warn` diagnostics (no PII).
- [ ] Wire **`boundChatRoomId`** through to chat block props when `componentType` is `chatRoom*`.
- [ ] Implement carousel horizontal list variant with stable keys (`item.i`).
- [ ] Implement grid variant: choose **single-column collapse** or **row+column FlashList`**—document trade-off in PR if collapsing.
- [ ] Mirror **`ComponentBlock`** responsibilities: title, icon, optional footer for types where portal `HAS_FOOTER` is true.
- [ ] Implement autoplay orchestration parity **or** document intentional simplification + product approval reference.

### D — Grid blocks (read paths first, then writes)

- [ ] `ad` / `adGrid` / `adCarousel` — fetch wall tickets; guest gating; empty states; open detail/navigation parity.
- [ ] `userProfile` / `userProfileGrid` / `userProfileCarousel` — profiles API; pagination; navigate to profile detail.
- [ ] `album` / `albumGrid` / `albumCarousel` — albums API; cover images; navigate to album detail.
- [ ] `blog` / `blogGrid` / `blogCarousel` — blogs API; list/detail; **no Quill** on mobile v1 (document editor approach).
- [ ] `reel` / `reelGrid` / `reelCarousel` — reels API; media playback via chosen native module; faceId scoping parity.
- [ ] `story` / `storyGrid` / `storyCarousel` — stories API; published/expired rules parity.
- [ ] `chatRoom` / `chatRoomGrid` / `chatRoomCarousel` — read-only room list UI before realtime (if ordering demands).
- [ ] **`AlbumForm` / `BlogForm` / `ReelForm` / `ChatRoomForm`** — parity with portal submit payloads (after read path works).
- [ ] **`ChatRoomCard`** — navigate to `ChatRoom` detail with correct `roomId`.

### E — Grid blocks (create / write, capability gated)

- [ ] Align create entry UX with portal capabilities for albums/blogs/reels where product allows mobile creation.
- [ ] Implement **pending approval** success copy using shared moderation label helpers.
- [ ] Ensure **optimistic UI** only where portal does; otherwise stay conservative on mobile.
- [ ] Invalidate correct Query keys after mutations (lists + detail).

### F — SignalR realtime

- [ ] Spike: verify `@microsoft/signalr` connects from RN iOS + Android to dev backend hub URL.
- [ ] Implement shared **`buildAuthenticatedHubConnection`** equivalent (§3.7) for **prefixed** hub URLs.
- [ ] **`/hubs/chatroom`**: `JoinRoom`, `LeaveRoom`, `SendRoomMessage` + all `connection.on` handlers from `ChatRoomDetailPage.tsx`.
- [ ] **`/hubs/messenger`**: `SendChatMessage`, `AcceptMessageRequest`, `RejectMessageRequest` + all events in §10.4 table from `MessengerContext.tsx`.
- [ ] **`/hubs/chat`**: `SendToAi` + `ReceiveAiMessage`; align error UX with `ChatPage.tsx`.
- [ ] `AppState` backgrounding: pause pings / reconnect gracefully; document behaviour.
- [ ] Logout and token rotation: **no zombie connections**; add tests where mockable.
- [ ] **Token refresh while connected:** define whether to **restart** hub connection after new access token (document same-or-better security than portal).

### G — My submissions and moderation UX

- [ ] Implement `MySubmissions` list screen + grouping parity with portal (`contentModeration` helpers).
- [ ] Implement navigation from submission row to native detail screens with **`edit`** intent param when allowed.
- [ ] Gate owner edit/delete controls using the same rules as portal detail pages.
- [ ] Ensure **public** lists never show non-approved content for other users (trust backend but mirror portal defensive UI).

### H — i18n, accessibility, polish

- [ ] Move user-visible grid strings into i18n JSON; add **SK**/**CZ** keys where portal already has them (parity pass).
- [ ] Audit touch targets and `accessibilityLabel` for every new interactive grid control.
- [ ] Image loading: adopt `expo-image` (or justify alternative) + caching strategy documented.

### I — Performance and risk controls

- [ ] Replace long `ScrollView`-only lists with **`FlatList`/`FlashList`** for at least album/blog/reel/story directories.
- [ ] Add React `memo` to row/tile components where Profiler shows benefit (document in PR if skipped).
- [ ] Avoid render-path `logger.*` calls in high-frequency components.

### J — Documentation, CI, testing hygiene, and repo hygiene

- [ ] Update `many_faces_mobile/README.md` with Phase 2+ reality (grid, submissions, realtime as implemented).
- [ ] Update `docs/guides/mobile-expo-development.md` with any new env vars, native modules, SignalR smoke steps, and the **§13.0** verification commands if they differ from defaults.
- [ ] Ensure `many_faces_main` CI still runs mobile job green after dependency additions (`expo-doctor`).
- [ ] Update `scripts/test-all.sh` / `lint-all.sh` only if new commands are required—document why.
- [ ] **PR template / practice:** require **§13.0** command list + outcome in PR description for Phase 2+ mobile PRs.
- [ ] **Coverage growth:** each feature PR links new **`*.test.ts`** / RTL files to the **§15** phase or Appendix checklist items it satisfies.

### K — Optional / future (explicitly deferrable with ticket IDs only)

- [ ] Deep linking (`linking` config) parity with portal URLs.
- [ ] `component-settings-*` cross-platform persistence policy decision (AsyncStorage vs web localStorage).
- [ ] Rich text editor parity beyond plain text (native editor R&D).
- [ ] Push notifications for moderation events (out of core parity unless product demands).

### L — Portal shell, non-grid routes, and social depth (easy to skip accidentally)

- [ ] Implement **`FacePageView` composition parity**: page title header; when `pageType.index === 'wall'`, render **wall ticket section** + optional `gridSchema` (same ordering as `FacePageView.tsx`).
- [ ] Port or reimplement **`WallTicketsSection`** behaviour (pagination, detail panel, `refreshKey` invalidation contract with create flows).
- [ ] Add **`ApiContext` / `ApiClient` analogue** on mobile **or** document why `fetch` wrapper alone is sufficient—either way, **centralise** face-prefix application and token injection; add tests mirroring `facePathRouting.test.ts` critical cases without `window`.
- [ ] Inventory **`many_faces_portal/src/api/services/*.ts`**; create a tracking table in PR for each service: **ported / not needed on mobile / deferred** with reason.
- [ ] **`FaceProfileDetailPage` parity**: likes, comments, reviews, error toasts, `allowRecensions` / face gating — not only directory list tiles.
- [ ] **`ProfilePage` parity** (“me” from JWT) vs face profile detail (other user).
- [ ] **`UsersPage` / `UserDetailPage` parity** if product expects global directory on mobile.
- [ ] **`ComponentListPage` / `ComponentDetailPage` parity** (dynamic `componentTypeId` routes).
- [ ] **`StoriesListPage` route** + navigation from grid/story blocks.
- [ ] **`StoriesCreateTopPanel` / `WallTicketCreateTopPanel` parity** (entry point + refresh coupling) or explicit deferral with ticket.
- [ ] **`FaceRoleSelectPanel` / first private face visit` flows** — parity or documented waiver referencing portal `AppRoutes` logic.
- [ ] **`MessengerTab` + `NotificationsTab` + `features/settings`** — decide minimal viable shell (icons, unread counts) vs full port; document subset in README if deferred.
- [ ] **Social graph services** (`FriendsService`, `FriendRequestsService`, `UserFollowsService`, `UserBlocksService`) — wire where portal uses them or defer with ticket.
- [ ] **`ChatPage` AI hub** — third SignalR surface (§10.1.1); implement or explicitly **out-of-scope for mobile v1** with product sign-off.
- [ ] **Toast / snackbar** strategy mapping all `toast.*` call sites relevant to ported screens.
- [ ] **`CreatorModerationBadge`** (or equivalent) on mobile grid/detail surfaces for creator-visible moderation states.

### M — `AppRoutes` shell composition (portal `routes/AppRoutes.tsx` + `shell/*`)

- [ ] **`AppWorkspace` / `AppContentArea`** — decide mobile equivalent (single root `SafeAreaView` + content slot vs split panes); document vs web flex layout.
- [ ] **`Header`**: face/branding, auth chip, navigation entry points mirrored minimally.
- [ ] **`Footer`**: legal / links parity if portal exposes them.
- [ ] **`SettingsSidePanel`** + `features/settings` tabs: messenger settings, notification settings, account—**per-tab** parity matrix.
- [ ] **`GridTopPanelProvider`** wiring (§8.3) for any screen that opens create flows from chrome.
- [ ] **`useFaceRouteEntries`** / dynamic face routes: ensure mobile **page list** from config stays consistent when admin adds pages (reload config + navigate).

---

**End of prompt —** copy §16 engagement rules + Appendix A into PR bodies; implement phases incrementally.
