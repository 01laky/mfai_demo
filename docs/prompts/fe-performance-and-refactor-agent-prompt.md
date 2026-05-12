# `many_faces_portal` — performance audit and refactor (agent prompt)

**Purpose:** Single agent brief to **measure**, **prioritize**, and **implement** frontend performance work and **structural refactors** in **`many_faces_portal` only** (Vite + React 19 + TanStack Query + React Router + SignalR + i18n). Use this as a copy-paste spec; tick evidence in a PR or issue, not by default in this canonical file (see [docs/prompts/README.md](./README.md)).

**Out of scope unless explicitly added:** `many_faces_admin`, `many_faces_backend`, Docker, CDN, HTTP/2 tuning, Lighthouse budgets as CI gates (recommend documenting thresholds first).

---

### Engagement exit rule (NON-NEGOTIABLE)

- **English:** Every `- [ ]` item in **§0 through §6** is **mandatory**. The agent **MUST NOT** stop, hand off, declare success, close the task, or end the engagement until **every** such item is **DONE**: implemented in `many_faces_portal` **and** verified (commands, tests, metrics as specified), **or** explicitly **waived in the PR** with measurement evidence where a code change is intentionally skipped. Sub-bullets labelled **Action** belong to the parent `- [ ]` — they inherit the same rule until that parent is satisfied.

- **Slovak:** **Agent nesmie skončiť**, kým **nie je hotové všetko povinné** podľa `- [ ]` v **§0 až §6** — buď je to **dorobené v `many_faces_portal` a overené**, alebo je v **PR výslovne odmietnuté** (waiver) **s dátami z meraní**. Kým to nie je splnené, **žiadne ukončenie úlohy** (žiadny „hotovo“, žiadny predčasný handoff).

**§1 inventory table** (each *Area* row) and the **Quick wins** table below: **same rule** — no exit until that row is **closed in code** or **waived with proof in the PR**.

**Not governed by this exit rule:** **§7 Non-goals** (intentional exclusions from implementation), **§8 Related documentation** (references only), **§9 Prompt maintenance** (meta-instructions for editing this file).

---

### Quick wins the inventory already implies (do not skip)

| Signal | Why it matters | **Exit gate** |
| ------ | -------------- | ------------- |
| **`logger.info` inside `AppRoutes` render path** | Runs **on every React commit** that touches `AppRoutes` — sync serialization + console I/O; skews Profiler and fills Seq/browser logs in prod if left enabled. **Guard** with `env.debugMode`, **sample**, or **remove** from render; keep navigation/face changes in **`useEffect`** with explicit deps if telemetry is required. | **REQUIRED.** Agent MUST NOT finish until addressed in `many_faces_portal` or waived with Profiler/network proof in PR. |
| **`AppContext` provider value** | Inline `value={{ currentLanguage, changeLanguage, t }}` and **`changeLanguage` not wrapped in `useCallback`** → **new function identity every render** → every `useApp()` consumer re-renders. Same class of bug as unstable context objects (§2.3). | **REQUIRED.** Agent MUST NOT finish until addressed in `many_faces_portal` or waived with Profiler proof in PR. |
| **`ApiContext` wrapper object** | `api` is correctly `useMemo`’d, but **`{ api }` context model is reallocated every render** before passing to `Provider` — subscribers still see a **new `value` reference**. Memoize the model object or pass `api` directly if the context type allows. | **REQUIRED.** Agent MUST NOT finish until addressed in `many_faces_portal` or waived with Profiler proof in PR. |

---

## 0. Preconditions (read before coding)

- [ ] **[REQUIRED — no agent exit until done]** Baseline branch clean; `yarn install --immutable` succeeds.
- [ ] **[REQUIRED — no agent exit until done]** Know **prod vs dev**: `StrictMode` doubles effects in development — profile **production build** (`yarn build && yarn preview`) for meaningful timings.
- [ ] **[REQUIRED — no agent exit until done]** Security and auth flows must stay correct after refactors (SignalR JWT, axios face prefix, `auth:unauthorized`).

---

## 1. Repository inventory (evidence snapshot)

Use this section as a **checklist of files/areas** the agent must re-open; line counts drift — re-run `wc -l` when starting work.

**Each table row is REQUIRED** under the **Engagement exit rule** (see above): close it in `many_faces_portal` **with verification**, or **waive in the PR with measurement evidence**.

| Area | Path(s) | Notes |
| ---- | ------- | ----- |
| **God module / routing shell** | `src/App.tsx` | **~1000 lines**: static imports of **all** pages, dynamic face routes, settings side panel, grid top panel, lucide icon batch import, `getRoutePaths` / `buildFacePagePaths` helpers live here. Primary **refactor** and **code-splitting** target. Contains **`AppRoutes`** with **many hooks + `useLocation`** — any expensive work here runs on **navigation**. |
| **Render-path logging** | `src/App.tsx` (`AppRoutes`) | **`logger.info('AppRoutes render', …)`** is invoked during render (not inside `useEffect`). Treat as **P0** noise + cost (§ Quick wins table). |
| **Positive pattern** | `src/App.tsx` | **`gridTopPanelApi`** is built with **`useMemo`** around stable callbacks — keep this pattern when extracting settings/grid code. |
| **App shell context** | `src/contexts/AppContext.tsx` | **`changeLanguage`** recreated each render; context **`value`** object recreated — broad **re-render fan-out** for `useApp()` (language + `t` reference). |
| **API context model** | `src/contexts/ApiContext.tsx` | **`useMemo` on `ApiClient`** but **`apiContextModel = { api }` rebuilt every render** — undermines memoization benefits for context consumers. |
| **Capabilities warmup** | `src/contexts/AuthContext.tsx` (`MeCapabilitiesWarmup`) | Renders **`useMeCapabilities(token)`** whenever `token` is set (`staleTime` **60s** in `useMeCapabilities.ts`). Ensures ACL data early but adds **mandatory** `/me/capabilities` fetch on top of pages that may also touch capabilities — verify **no duplicate fetches** and that **`enabled`** gates match product (guest vs authed). |
| **React Query defaults** | `src/providers/QueryProvider.tsx` | Module-level `QueryClient`: `refetchOnWindowFocus: false`, `retry: 1`, default `staleTime: 5 * 60 * 1000`. **No `gcTime`** set explicitly (library defaults apply). Individual hooks (e.g. `useAuthToken`) may use different `staleTime` — audit **per-query** alignment with product freshness. |
| **Auth + polling** | `src/contexts/AuthContext.tsx` | **~330 lines**: `window` listener for `auth:unauthorized`; **`setInterval(checkExpiry, 30_000)`** — fixed cadence work on the main thread for every logged-in session. Candidate for **debounce**, **Page Visibility API**, or **delegation to React Query** token query only. |
| **Face config** | `src/contexts/FaceConfigContext.tsx` | Loads full faces list on auth/token changes; uses generation ref to drop stale responses. Reasonable pattern — still **network cost** on every login/logout; consider **caching** or **ETag** if API supports it. |
| **Messenger / SignalR** | `src/contexts/MessengerContext.tsx` | **~220 lines**: builds hub when `token` present; `forEach` over `Set` callbacks on every server event. **Provider `value`** is a **fresh object every render** (see §2.3 / §3.2) — can force broad subtree re-renders. |
| **Provider tree** | `src/App.tsx` (`App` component) | Order: `BrowserRouter` → `AppProvider` → `AuthProvider` → `ApiContextProviderWithToken` → `MessengerProviderWithToken` → `FaceConfigProvider` → `AppRoutes`. **Messenger** wraps entire app (connection no-ops without token, but context still runs). |
| **API interceptors** | `src/api/config.ts` | Global axios interceptors: **every request** runs `getEffectiveFacePrefix(window.location.pathname, …)` and URL rewrite logic. Hot path for high-churn UIs (grids, polling). |
| **i18n bundle** | `src/i18n/config.ts` | **Static JSON imports** for `en`, `sk`, `cz` into one namespace `common` — **full locale payloads in initial JS** (no lazy namespaces). `useSuspense: false`. Trade-off: simplicity vs. **TTI** on slow networks. |
| **Rich text** | `src/components/grid/BlogForm.tsx` | **`react-quill-new`** + **global Quill Snow CSS** import — heavy chunk; only routes that need editor should load it (**lazy** + dynamic import). |
| **Icons** | Many `src/**/*.tsx` | Widespread **`lucide-react`** named imports — generally tree-shakeable, but **`App.tsx` imports many icons at once** for the settings shell; worth verifying bundle output (`rollup-plugin-visualizer` or Vite analyze). |
| **Realtime (non-messenger)** | `src/pages/ChatRoomDetailPage.tsx` | Separate **SignalR** hub connection for chat room detail — pattern duplication vs `MessengerContext` (maintenance + double connection risk if user opens both). |
| **Wall / grid** | `src/hooks/useWallHostViewer.ts`, `src/components/grid/*` | Multiple carousels/grids with **`useEffect`** chains (fetch, subscriptions). Good candidates for **React Profiler** and **memoization** of row/item components. |

---

## 2. Performance analysis (what to fix and why)

### 2.1 Initial load / JavaScript payload (TTI, FCP, LCP)

- [ ] **[REQUIRED — no agent exit until done]** **No route-level code splitting today:** `App.tsx` statically imports every page (`HomePage`, `AlbumDetailPage`, `MessengerTab`, …). Initial bundle pays for **routes the user may never visit**.
  - **Action:** Introduce `React.lazy` + `Suspense` (with minimal fallback) per **route segment** or per **feature island** (e.g. settings tabs, admin-like grids). Keep **critical path** (home, login) eager if needed for UX.
- [ ] **[REQUIRED — no agent exit until done]** **Quill + CSS:** defer editor chunk until first visit to blog compose / rich-text surfaces.
- [ ] **[REQUIRED — no agent exit until done]** **i18n:** evaluate **`i18next` lazy loading** (`backend` HTTP loader or `import()` per language) vs. current static JSON. Measure gzip size of `locales/*.json` in rollup output before deciding.

### 2.2 Network and caching (TanStack Query)

- [ ] **[REQUIRED — no agent exit until done]** **Default `staleTime` (5 min)** vs hooks with **custom** `staleTime` (e.g. auth token polling semantics) — document a **matrix**: which data is **stale-ok** vs **must refetch** on focus/mount.
- [ ] **[REQUIRED — no agent exit until done]** Consider **`gcTime`** for large list queries (albums, stories) to cap memory on long sessions.
- [ ] **[REQUIRED — no agent exit until done]** Audit **`enabled`** flags so disabled queries do not fire during wizard steps or when `token` is null.

### 2.3 Main thread and re-renders

- [ ] **[REQUIRED — no agent exit until done]** **Context provider values:** `MessengerContext` builds `value = { … }` inline each render; **`AuthContext.Provider value={{ … }}`** same pattern. Any child using `useMessenger()` / `useAuth()` **re-renders** when parent re-renders even if primitives unchanged (new object identity).
  - **Action:** `useMemo` the context value with correct dependency lists, or **split contexts** (state vs actions), or **Zustand**/`useSyncExternalStore` for high-frequency subsets — pick the smallest change that removes Profiler hotspots.
- [ ] **[REQUIRED — no agent exit until done]** **`AppRoutes` / settings panel:** large inline JSX and **many `useState`** toggles; opening settings may rerender wide subtrees. Extract **presentational** pieces and **`memo`** list rows where Profiler shows waste.
- [ ] **[REQUIRED — no agent exit until done]** **Axios request interceptor:** avoid repeated `window.location.pathname` parsing if the app can subscribe to **router location** once and pass a **memoized face prefix** into a slimmer interceptor (requires care not to break `faceApiRouting` contract).

### 2.4 Realtime (SignalR)

- [ ] **[REQUIRED — no agent exit until done]** **Two hub stacks:** `MessengerContext` (messenger hub) + `ChatRoomDetailPage` (chat room hub). Consider a **shared connection manager** (single place for reconnect, logging, token refresh) to reduce duplicated logic and accidental **double connections**.
- [ ] **[REQUIRED — no agent exit until done]** **Server → client fan-out:** `callbacksRef.current.*.forEach` — fine for small sets; ensure tabs **unregister** on unmount (memory + CPU).

### 2.5 Timers and background work

- [ ] **[REQUIRED — no agent exit until done]** **`AuthContext` `setInterval` every 30s:** overlaps with React Query `useAuthToken` **staleTime 60s** — risk of **redundant work** and wakeups on background tabs.
  - **Action:** consolidate expiry handling (either interval **or** query-driven), and **pause** when `document.visibilityState === 'hidden'` unless product requires otherwise.

### 2.6 Assets and CSS

- [ ] **[REQUIRED — no agent exit until done]** **Sass pipeline:** `main.scss` and partials — ensure no **accidental `@import` of huge unused** partials in the critical path.
- [ ] **[REQUIRED — no agent exit until done]** **Images / media in grids:** verify **lazy loading**, dimensions to reduce CLS, and avoid decoding huge images on the main thread (use `loading="lazy"` / responsive sources where applicable).

### 2.7 Logging, telemetry, and dev-only work

- [ ] **[REQUIRED — no agent exit until done]** **Never call `logger.*` synchronously in render** unless guarded (see `AppRoutes`). Prefer **`useEffect`** keyed by meaningful deps, or a **sampling** helper for high-frequency state.
- [ ] **[REQUIRED — no agent exit until done]** **`src/utils/logger.ts`** uses a **flush interval** — confirm interval **pauses** or **backs off** when `document.hidden` if Seq forwarding is enabled (battery + main-thread wakeups on mobile).

### 2.8 Duplicate auth / session work (conceptual consolidation)

Today multiple layers touch “is the session alive?”:

- [ ] **[REQUIRED — no agent exit until done]** **React Query** `useAuthToken` (`staleTime` **60s**) + **`readAuthTokenQueryValue`** clearing storage.
- [ ] **[REQUIRED — no agent exit until done]** **`AuthContext` localStorage bootstrap** on mount + **sync `useEffect`** from `tokenData`.
- [ ] **[REQUIRED — no agent exit until done]** **`setInterval` expiry check** every **30s** (§2.5).
- [ ] **[REQUIRED — no agent exit until done]** **Axios `401` → `auth:unauthorized`** listener.

**Goal:** one **authoritative** story for “token invalid → logout UI” where possible, without removing safety nets. Document the **intended redundancy** (which layer is source of truth) after refactor.

- [ ] **[REQUIRED — no agent exit until done]** In the **PR body**, document the **intended redundancy** / single source of truth for session expiry and logout UX after any consolidation work in §2.8 (even if the architecture stays multi-layered on purpose).

### 2.9 Route generation cost (`getRoutePaths` / `i18n.t`)

- [ ] **[REQUIRED — no agent exit until done]** `App.tsx` maps **many** `<Route>` entries using **`getRoutePaths(...)`** which calls into **`getAllRouteTranslations`** / **`i18n.t`**. If this runs **unmemoized** inside render, language switches or parent re-renders may **rebuild large string arrays**.
  - **Action:** memoize per-language route tables once (`useMemo` keyed by `i18n.language` / `currentLanguage`) or **precompute** static route tables in a pure module.

### 2.10 Vite / Rollup build tuning (after bundle analyze)

- [ ] **[REQUIRED — no agent exit until done]** Evaluate **`build.rollupOptions.output.manualChunks`** to isolate **stable** vendors (`react`, `react-dom`, `react-router`, `@tanstack/react-query`, `@microsoft/signalr`) — measure **cache hit rate** on repeat deploys vs **HTTP/2 multiplexing** behavior. If you ship **no** `manualChunks` change, the PR **must** state why (e.g. measured regression or policy) and cite bundle output.
- [ ] **[REQUIRED — no agent exit until done]** Decide on **`modulePreload`** / **`link rel=preload`** for critical chunks only with **evidence**; if omitted, document why (e.g. mobile over-preload risk) in the PR.

---

## 3. Refactor inventory (structural debt)

These are **maintainability** items that also unlock performance work.

### 3.1 Split `App.tsx` into cohesive modules

Target structure (example — adjust names to taste):

- [ ] **[REQUIRED — no agent exit until done]** `src/routes/` — `LanguageLayout`, `GuestRoutes`, `ProtectedRoutes`, `faceRoutes.tsx`, `staticRoutePaths.ts`.
- [ ] **[REQUIRED — no agent exit until done]** `src/shell/` or `src/layout/` — header/footer/settings **composition** only; no data fetching.
- [ ] **[REQUIRED — no agent exit until done]** `src/features/settings/` — settings tabs (messenger, notifications, …) as lazy-loaded chunks.
- [ ] **[REQUIRED — no agent exit until done]** Keep **`getRoutePaths` / `buildFacePagePaths`** in a **pure** module with unit tests (already partially tested elsewhere — extend).

### 3.2 Context hygiene

- [ ] **[REQUIRED — no agent exit until done]** **Memoize** or **split** `AuthContext` and `MessengerContext` values (§2.3).
- [ ] **[REQUIRED — no agent exit until done]** **Stabilize `AppContext`:** `useCallback` for `changeLanguage`, `useMemo` for provider `value` (or split **language** vs **i18n `t`** if `t` identity is unstable across i18n events — verify with Profiler).
- [ ] **[REQUIRED — no agent exit until done]** **Fix `ApiContext` value allocation** (§ Quick wins / inventory).
- [ ] **[REQUIRED — no agent exit until done]** Re-evaluate **`MessengerProvider`** placement: consider rendering **only under authenticated layout** to avoid mounting messenger logic for anonymous users (micro-optimization; measure first; **waive in PR** if Profiler shows no gain).

### 3.3 Duplicated realtime and API patterns

- [ ] **[REQUIRED — no agent exit until done]** Abstract **SignalR hub builder** (URL from `absoluteScopedUrl`, token factory, reconnect policy, logging).
- [ ] **[REQUIRED — no agent exit until done]** Align **ChatRoom** and **Messenger** error handling (token expiry, `401` → logout) with a single policy.

### 3.4 Type safety and boundaries

- [ ] **[REQUIRED — no agent exit until done]** Reduce `any` in routing tests / window mocks where it obscures refactors (`facePathRouting` tests already careful — extend pattern).

---

## 4. Measurement protocol (required before large changes)

Record numbers in the PR description (table: before → after).

- [ ] **[REQUIRED — no agent exit until done]** **Bundle:** `yarn build` and analyze output (`vite-bundle-visualizer` or `rollup-plugin-visualizer` — add **devDependency** only if team accepts). Capture **total JS**, **largest chunks**, **node_modules** share.
- [ ] **[REQUIRED — no agent exit until done]** **Lighthouse** (Chrome) on **preview** URL: Performance + **TBT** + **LCP** for `/en` (or default lang) **guest** and **authenticated** home.
- [ ] **[REQUIRED — no agent exit until done]** **React Profiler** (production build): record **commit duration** opening settings, switching faces, opening messenger tab, scrolling album grid.
- [ ] **[REQUIRED — no agent exit until done]** **Network:** DevTools **disable cache** — count duplicate **faces config** / **capabilities** fetches on cold load and after login.
- [ ] **[REQUIRED — no agent exit until done]** **Chrome Performance** recording: capture at least one **5–10s** interaction trace while opening settings + switching tabs — watch **Scripting** and **Layout** blocks (not only React). If tooling is unavailable, **waive in PR** with screenshot of the failed attempt and substitute evidence (e.g. extended Profiler export).

---

## 5. Phased implementation plan (suggested order)

**Phase A — Quick wins (low risk)**  
- [ ] **[REQUIRED — no agent exit until done]** Profiler + bundle baseline (§4).  
- [ ] **[REQUIRED — no agent exit until done]** Remove or guard **render-path `logger.info`** in `AppRoutes` (§ Quick wins).  
- [ ] **[REQUIRED — no agent exit until done]** `useMemo` / `useCallback` fixes for **`AppContext`** and **`ApiContext`** provider models.  
- [ ] **[REQUIRED — no agent exit until done]** `useMemo` context values where safe (`MessengerContext`, `AuthContext`).  
- [ ] **[REQUIRED — no agent exit until done]** Memoize **route path lists** if Profiler shows `getRoutePaths` cost (§2.9).  
- [ ] **[REQUIRED — no agent exit until done]** Auth interval vs visibility / Query consolidation (§2.5).  
- [ ] **[REQUIRED — no agent exit until done]** Lazy-load **Quill** (and any other **>100KB** feature libraries found in analyze).

**Phase B — Route splitting**  
- [ ] **[REQUIRED — no agent exit until done]** `React.lazy` for **protected** and **infrequent** routes first (admin-like lists, detail pages).  
- [ ] **[REQUIRED — no agent exit until done]** Suspense fallbacks consistent with design system (skeleton, not spinners everywhere).

**Phase C — `App.tsx` decomposition**  
- [ ] **[REQUIRED — no agent exit until done]** Extract route modules; reduce `App.tsx` to **layout + provider wiring** only (< ~200 lines goal).  
- [ ] **[REQUIRED — no agent exit until done]** Move settings shell to feature folder with lazy tabs.

**Phase D — Deeper optimizations (REQUIRED: decide + implement or waive)**  
After Phases A–C, **re-measure**. Each item below is **still mandatory** — either land the change in `many_faces_portal`, or **explicitly waive in the PR** with before/after metrics showing no benefit or product rejection.

- [ ] **[REQUIRED — no agent exit until done]** i18n lazy loading **or** documented waiver (e.g. locale JSON size below threshold with bundle table).  
- [ ] **[REQUIRED — no agent exit until done]** Interceptor / face-prefix memoization **or** documented waiver with request-count / CPU evidence.  
- [ ] **[REQUIRED — no agent exit until done]** Virtualized lists for very long grids **or** documented waiver (e.g. max list size contract from product + Profiler proof that lists are cold).

---

## 6. Acceptance criteria (definition of done)

- [ ] **[REQUIRED — no agent exit until done]** PR lists **bundle stats** before/after and **Profiler** screenshots or exported traces for at least **two** user flows (e.g. cold load guest, login + open settings).  
- [ ] **[REQUIRED — no agent exit until done]** No regression in **auth**, **SignalR**, **face-prefixed API** routing (existing tests + manual smoke).  
- [ ] **[REQUIRED — no agent exit until done]** `yarn validate` and `yarn test` green; **`yarn build`** green.  
- [ ] **[REQUIRED — no agent exit until done]** If new lazy routes: document **fallback UX** in PR and ensure **SEO** constraints unchanged (SPA already).  
- [ ] **[REQUIRED — no agent exit until done]** **`yarn test:e2e:ci`** (or documented manual substitute) still passes if Cypress specs touch navigation shell.

---

## 7. Non-goals (avoid rabbit holes)

These bullets are **not** deliverables and **do not** use the `[ ]` / exit rule — **do not** “complete” them as tasks; they forbid scope creep.

- Rewriting **OpenAPI generated** `src/api/**` (except thin wrappers).  
- Replacing **React Router** with another router without explicit product approval.  
- Micro-optimizing **premature `useCallback`** everywhere without Profiler proof.

---

## 8. Related documentation

- [docs/guides/development.md](../guides/development.md) — CI and local scripts (`yarn validate`, Cypress smoke).  
- [docs/readmes/fe-portal-overview.md](../readmes/fe-portal-overview.md) — high-level `many_faces_portal` architecture (keep in sync if routing shell moves).  
- [docs/prompts/react-hooks-compiler-rules-rollout-agent-prompt.md](./react-hooks-compiler-rules-rollout-agent-prompt.md) — compiler / hook lint alignment after refactors.  
- [docs/prompts/unit-test-gap-fill-agent-prompt.md](./unit-test-gap-fill-agent-prompt.md) — tests for extracted pure modules.

---

## 9. Prompt maintenance (for future passes)

When code moves (line counts, new providers, new hubs), update **§1** paths and re-verify **§ Quick wins**. If a hotspot is **fixed in repo**, add a one-line **“Resolved in PR #…”** note in the PR checklist rather than ticking this file’s `[ ]` rows globally (per [prompts/README.md](./README.md) retention rules).

---

## 10. Master checklist (all bodies — final pass)

Use this as a **single closing pass** over the entire prompt. **Same rules as above:** each `- [ ]` is **mandatory** under the **Engagement exit rule** unless the row is explicitly **out of scope** (§7) or **reference-only** (§8). **Do not tick this canonical file in git** — mirror ticks in the **PR / issue** ([prompts/README.md](./README.md)).

### 10.0 Read first

- [ ] **Engagement exit rule** (EN + SK): understood; agent will not exit until §0–§6 + tables below are satisfied or waived with PR evidence.
- [ ] **Out of scope** (Purpose paragraph): no unscoped work in `many_faces_admin` / `many_faces_backend` / etc. unless explicitly added to the task.

### 10.1 Quick wins table (three signals)

- [ ] **`logger.info` in `AppRoutes` render path** — guard, sample, remove, or move to `useEffect`; or PR waiver with Profiler/network proof.
- [ ] **`AppContext` provider** — stable `changeLanguage` + stable `value` (or split contexts); or PR waiver with Profiler proof.
- [ ] **`ApiContext` `{ api }` wrapper** — memoize model or pass `api` directly; or PR waiver with Profiler proof.

### 10.2 §1 Repository inventory (every *Area* row)

- [ ] **God module / routing shell** (`App.tsx`) — addressed or waived (refactor / split / metrics).
- [ ] **Render-path logging** (`AppRoutes`) — aligned with Quick wins row.
- [ ] **Positive pattern** (`gridTopPanelApi` `useMemo`) — preserved or intentionally changed with note in PR.
- [ ] **App shell context** (`AppContext.tsx`) — aligned with Quick wins / §3.2.
- [ ] **API context model** (`ApiContext.tsx`) — aligned with Quick wins / §3.2.
- [ ] **Capabilities warmup** (`MeCapabilitiesWarmup` / `useMeCapabilities`) — duplicate fetch / `enabled` gates verified or waived.
- [ ] **React Query defaults** (`QueryProvider.tsx`) — defaults vs per-hook behavior documented in matrix (§2.2) or waived.
- [ ] **Auth + polling** (`AuthContext.tsx` interval / listeners) — §2.5 / Phase A overlap closed or waived.
- [ ] **Face config** (`FaceConfigContext.tsx`) — network / cache trade-offs evaluated or waived with evidence.
- [ ] **Messenger / SignalR** (`MessengerContext.tsx`) — context value + hub pattern; §2.4 / §3.3 overlap closed or waived.
- [ ] **Provider tree** (`App.tsx` order, `MessengerProvider` scope) — §3.2 / Messenger placement evaluated or waived.
- [ ] **API interceptors** (`api/config.ts` face prefix hot path) — §2.3 / Phase D overlap closed or waived.
- [ ] **i18n bundle** (`i18n/config.ts` static JSON) — lazy-load decision (§2.1 / Phase D) closed or waived.
- [ ] **Rich text** (`BlogForm.tsx` / Quill) — lazy chunk strategy (§2.1 / Phase A) closed or waived.
- [ ] **Icons** (`lucide-react` / `App.tsx` batch) — bundle impact checked or waived with analyze output.
- [ ] **Realtime (non-messenger)** (`ChatRoomDetailPage.tsx` hub vs messenger) — duplication / double connection risk closed or waived.
- [ ] **Wall / grid** (`useWallHostViewer`, `components/grid/*`) — Profiler / memo follow-ups closed or waived.

### 10.3 §0 Preconditions

- [ ] Baseline clean; `yarn install --immutable` succeeds.
- [ ] Prod vs dev / `StrictMode` — meaningful profiling uses **production build** (`yarn build && yarn preview`).
- [ ] Security / auth invariant: SignalR JWT, axios face prefix, `auth:unauthorized` still correct after changes.

### 10.4 §2 Performance analysis

**§2.1 Initial load / payload**

- [ ] Route-level code splitting evaluated (`React.lazy` + `Suspense` plan or waiver).
- [ ] Quill + CSS deferred to first need (or waiver).
- [ ] i18n lazy loading evaluated vs static JSON (measure gzip / rollup; or waiver).

**§2.2 Network / TanStack Query**

- [ ] `staleTime` matrix (default vs custom hooks) documented or waived.
- [ ] `gcTime` for large lists considered / documented or waived.
- [ ] `enabled` flags audited (wizard steps, `token` null).

**§2.3 Main thread / re-renders**

- [ ] `MessengerContext` + `AuthContext` provider values stabilized (`useMemo` / split / alternative).
- [ ] `AppRoutes` / settings panel extraction + `memo` where Profiler shows waste (or waiver).
- [ ] Axios interceptor / face prefix — router-driven memoized prefix or waiver (contract-safe).

**§2.4 SignalR**

- [ ] Two hub stacks — shared manager or documented duplication policy + metrics.
- [ ] Messenger callbacks / tab unregister on unmount verified.

**§2.5 Timers / background**

- [ ] `AuthContext` 30s interval vs `useAuthToken` 60s — consolidated and/or visibility-aware (or product-documented exception).

**§2.6 Assets / CSS**

- [ ] Sass critical path — no accidental huge `@import` (or waiver).
- [ ] Grid images — lazy load, dimensions, decode strategy (or waiver).

**§2.7 Logging / telemetry**

- [ ] No unguarded `logger.*` in render paths (or waiver).
- [ ] `logger.ts` flush interval pauses or backs off when `document.hidden` if Seq forwarding on (or waiver).

**§2.8 Duplicate auth / session**

- [ ] `useAuthToken` + `readAuthTokenQueryValue` story clear (or waiver).
- [ ] `AuthContext` localStorage bootstrap + sync `useEffect` reviewed (or waiver).
- [ ] `setInterval` expiry aligned with §2.5 outcome (or waiver).
- [ ] Axios `401` → `auth:unauthorized` policy clear (or waiver).
- [ ] **PR body:** intended redundancy / source of truth for session expiry + logout UX documented.

**§2.9 Route generation**

- [ ] `getRoutePaths` / `i18n.t` cost — memoized or precomputed if needed (or waiver with Profiler).

**§2.10 Vite / Rollup**

- [ ] `manualChunks` evaluated — change shipped **or** PR explains why not + cites bundle output.
- [ ] `modulePreload` / preload decision documented with evidence or waiver.

### 10.5 §3 Refactor inventory

**§3.1 Split `App.tsx`**

- [ ] `src/routes/` structure (layouts, `faceRoutes`, `staticRoutePaths`).
- [ ] `src/shell/` or `src/layout/` — composition only.
- [ ] `src/features/settings/` — lazy settings tabs.
- [ ] `getRoutePaths` / `buildFacePagePaths` pure module + tests extended.

**§3.2 Context hygiene**

- [ ] `AuthContext` + `MessengerContext` memoization / split (§2.3).
- [ ] `AppContext` stabilized (`useCallback` / `useMemo` / split + Profiler).
- [ ] `ApiContext` value allocation fixed (Quick wins).
- [ ] `MessengerProvider` placement re-evaluated (or waived with Profiler).

**§3.3 Realtime / API patterns**

- [ ] Shared SignalR hub builder (or waiver).
- [ ] ChatRoom vs Messenger error handling aligned (or waiver).

**§3.4 Types**

- [ ] Reduce `any` in routing tests / window mocks where it blocks refactors (or waiver).

### 10.6 §4 Measurement protocol

- [ ] Bundle: `yarn build` + analyze — totals, largest chunks, `node_modules` share recorded.
- [ ] Lighthouse on preview — guest + authed home (Performance, TBT, LCP).
- [ ] React Profiler — settings, faces, messenger, album grid commits recorded.
- [ ] Network — duplicate faces config / capabilities fetches counted (cache off).
- [ ] Chrome Performance trace **or** waiver + substitute evidence per prompt.

### 10.7 §5 Phased implementation

**Phase A**

- [ ] Profiler + bundle baseline (§4).
- [ ] Render-path `logger.info` in `AppRoutes` removed/guarded.
- [ ] `AppContext` + `ApiContext` provider fixes.
- [ ] `MessengerContext` + `AuthContext` `useMemo` where safe.
- [ ] Route path memoization if Profiler showed `getRoutePaths` cost.
- [ ] Auth interval / visibility / Query consolidation (§2.5).
- [ ] Quill (and other >100KB libs from analyze) lazy-loaded.

**Phase B**

- [ ] `React.lazy` for protected / infrequent routes first.
- [ ] Suspense fallbacks aligned with design system.

**Phase C**

- [ ] `App.tsx` reduced to layout + provider wiring (~200 lines goal or waiver).
- [ ] Settings shell in feature folder with lazy tabs.

**Phase D**

- [ ] i18n lazy loading **or** documented waiver + bundle table.
- [ ] Interceptor / face-prefix memoization **or** documented waiver + request/CPU evidence.
- [ ] Virtualized grids **or** documented waiver + product + Profiler evidence.

### 10.8 §6 Acceptance criteria

- [ ] PR: bundle stats before/after + Profiler/traces for **≥ two** flows.
- [ ] No regression: auth, SignalR, face-prefixed API (tests + smoke).
- [ ] `yarn validate`, `yarn test`, `yarn build` green.
- [ ] Lazy routes: fallback UX in PR; SEO constraints unchanged (SPA).
- [ ] `yarn test:e2e:ci` or documented manual substitute if Cypress touches shell.

### 10.9 Non-goals & references (sanity)

- [ ] **§7** respected — no scope creep into non-goals.
- [ ] **§8** links consulted as needed (`development.md`, `fe-portal-overview.md`, related prompts).

### 10.10 Prompt maintenance (optional meta)

- [ ] If **this prompt file** was edited for `many_faces_portal` paths: **§1** line counts / **§ Quick wins** text updated; PR references [prompts/README.md](./README.md) policy for canonical file ticks.
