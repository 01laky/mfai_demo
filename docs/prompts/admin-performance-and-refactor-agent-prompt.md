# `many_faces_admin` — performance audit and refactor (agent prompt)

**Purpose:** Single agent brief to **measure**, **prioritize**, and **implement** admin-panel performance work and **structural refactors** in **`many_faces_admin` only** (Vite + React 19 + TanStack Query + React Router + SignalR on chat + i18n + OpenAPI axios). Use this as a copy-paste spec; tick evidence in a PR or issue, not by default in this canonical file (see [docs/prompts/README.md](./README.md)).

**Pre AI:** Každý riadok začínajúci `- [ ]` a každý riadok tabuľky so stĺpcom **Pre AI** končí odkazom **[REQ · AI · no exit](#ai-req-exit)** — ten odkaz smeruje na [kotvu pravidla ukončenia](#ai-req-exit): ide o **povinnú implementáciu alebo waiver v PR**; **bez splnenia všetkých takýchto bodov v rozsahu úlohy agent nesmie úlohu ukončiť** (žiadny handoff, žiadne predčasné „hotovo“).

**Out of scope unless explicitly added:** `many_faces_portal`, `many_faces_backend`, Docker, CDN, HTTP/2 tuning, Lighthouse budgets as CI gates (recommend documenting thresholds first).

## Checklist

**Účel:** jeden prehľad **čo uzavrieť pred ukončením** úlohy. **Nezavádza nové deliverables** — všetky povinné úlohy sú už v `- [ ]` riadkoch nižšie (každý s **[REQ · AI · no exit](#ai-req-exit)** a [pravidlom ukončenia](#ai-req-exit)). Značky `[ ]` / `[x]` dávaj do **PR alebo issue**, nie do tohto súboru ([docs/prompts/README.md](./README.md)).

**Poradie kontroly (odporúčané):**

1. **Quick wins** — tabuľka pod nadpisom *Quick wins the inventory already implies*.
2. **§0** Preconditions.
3. **§1** Repository inventory — tabuľka *Area / Path(s) / Notes* (+ stĺpec **Pre AI**).
4. **§2** Performance analysis — všetky podsekcie až **§2.11**.
5. **§3** Refactor inventory — vrátane **§3.5**.
6. **§4** Measurement protocol — vrátane **§4.1** waiver blokov v PR pre každý výslovne vynechaný bod.
7. **§5** Phased plan — Phase A → D.
8. **§6** Acceptance criteria (`yarn validate`, `yarn test`, `yarn build`, dôkazy v PR).
9. **§10** Master checklist — finálny prechod celým promptom.

---

<a id="ai-req-exit"></a>

### Engagement exit rule (NON-NEGOTIABLE)

**Pre AI (povinná implementácia — bez ukončenia skôr):** Každý odkaz **[REQ · AI · no exit](#ai-req-exit)** v tomto dokumente znamená to isté ako *Engagement exit rule*: bod je **povinný** — treba ho **implementovať v `many_faces_admin` a overiť** (príkazy, testy, metriky podľa textu), alebo ho **výslovne waivernúť v PR s dôkazom z meraní**. Agent **nesmie** úlohu **ukončiť** (žiadny handoff, žiadne „hotovo“, žiadne uzavretie engagementu), kým **nie sú** všetky takéto body v zadanom rozsahu **splnené alebo waivernuté**. Riadky v tabuľkách (Quick wins, §1 inventár) majú rovnakú povinnosť.

- **English:** Every `- [ ]` item in **§0 through §6** is **mandatory**. The agent **MUST NOT** stop, hand off, declare success, close the task, or end the engagement until **every** such item is **DONE**: implemented in `many_faces_admin` **and** verified (commands, tests, metrics as specified), **or** explicitly **waived in the PR** with measurement evidence where a code change is intentionally skipped. Sub-bullets labelled **Action** belong to the parent `- [ ]` — they inherit the same rule until that parent is satisfied.

- **Slovak:** **Agent nesmie skončiť**, kým **nie je hotové všetko povinné** podľa `- [ ]` v **§0 až §6** — buď je to **dorobené v `many_faces_admin` a overené**, alebo je v **PR výslovne odmietnuté** (waiver) **s dátami z meraní**. Kým to nie je splnené, **žiadne ukončenie úlohy** (žiadny „hotovo“, žiadny predčasný handoff).

**§1 inventory table** (each *Area* row) and the **Quick wins** table below: **same rule** — no exit until that row is **closed in code** or **waived with proof in the PR**.

**Not governed by this exit rule:** **§7 Non-goals** (intentional exclusions from implementation), **§8 Related documentation** (references only), **§9 Prompt maintenance** (meta-instructions for editing this file).

---

### Quick wins the inventory already implies (do not skip)

| Signal | Why it matters | **Exit gate** | **Pre AI** |
| ------ | -------------- | ------------- | --- |
| **`logger.info` at start of `AppContent` render** | Runs on **every React commit** that re-renders `AppContent` — sync serialization + console I/O; skews Profiler and fills Seq/browser logs. **Guard** with `env.debugMode`, **sample**, **move to `useEffect` once** on mount, or **remove**. | **REQUIRED.** Agent MUST NOT finish until addressed in `many_faces_admin` or waived with Profiler/network proof in PR. | [REQ · AI · no exit](#ai-req-exit) |
| **`AppContext` provider value** | Inline `value={{ currentLanguage, changeLanguage, t }}` and **`changeLanguage` not wrapped in `useCallback`** → **new function identity every render** → every `useApp()` consumer re-renders. | **REQUIRED.** Agent MUST NOT finish until addressed in `many_faces_admin` or waived with Profiler proof in PR. | [REQ · AI · no exit](#ai-req-exit) |
| **`getRoutePaths` / route maps in `AppContent` render** | Multiple **`getRoutePaths(...)`** calls each render rebuild translated path arrays via **`i18n.t`** — redundant work on language switches and unrelated parent re-renders. | **REQUIRED.** Agent MUST NOT finish until memoized / precomputed (e.g. `useMemo` keyed by `i18n.language`) or waived with Profiler proof in PR. | [REQ · AI · no exit](#ai-req-exit) |
| **`withLayout` inside `AppContent`** | If **`withLayout`** is an **inline function** recreated every render, every `element={…}` branch allocates a **new function identity** each commit (usually reconciled, but unnecessary). **Hoist** to module scope, wrap in **`useCallback`** with stable deps, or replace with static element factories if Profiler shows cost. | **REQUIRED.** Stabilize or waive with Profiler proof in PR. | [REQ · AI · no exit](#ai-req-exit) |

---

## 0. Preconditions (read before coding)

- [ ] **[REQUIRED — no agent exit until done]** Baseline branch clean; `yarn install --immutable` succeeds in `many_faces_admin`. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Know **prod vs dev**: `StrictMode` doubles effects in development — profile **production build** (`yarn build && yarn preview`) for meaningful timings. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Security and auth flows must stay correct after refactors: **OAuth2** token refresh, **`setupAxiosInterceptors`** (**401** queue, **`forceLogout`**, redirect to login), and **`setAuthToken`**. **Do not assume** a **`window` `auth:unauthorized` CustomEvent** — that pattern is common in **`many_faces_portal`** but **`many_faces_admin`** today routes session loss primarily through **axios interceptors** (verify the repo; if a CustomEvent is added later, document it in the PR). [REQ · AI · no exit](#ai-req-exit)

---

## 1. Repository inventory (evidence snapshot)

Use this section as a **checklist of files/areas** the agent must re-open; line counts drift — re-run `wc -l` when starting work.

**Each table row is REQUIRED** under the **Engagement exit rule** (see above): close it in `many_faces_admin` **with verification**, or **waive in the PR with measurement evidence**.

| Area | Path(s) | Notes | **Pre AI** |
| ---- | ------- | ----- | --- |
| **God module / routing shell** | `src/App.tsx` | **~320 lines**: static imports of **all** admin pages (users, faces, pages CRUD, chat, dashboard); **`AppContent`** holds the full `<Routes>` tree, **`getRoutePaths`**, **`withLayout`** helper. Primary **refactor** and **code-splitting** target. | [REQ · AI · no exit](#ai-req-exit) |
| **Render-path logging** | `src/App.tsx` (`AppContent`) | **`logger.info('App component mounted', …)`** at top of `AppContent` runs on **every render** of `AppContent`, not only mount — treat as **P0** noise + cost (§ Quick wins table). | [REQ · AI · no exit](#ai-req-exit) |
| **App shell context** | `src/contexts/AppContext.tsx` | **`changeLanguage`** recreated each render; context **`value`** object recreated — broad **re-render fan-out** for `useApp()`. | [REQ · AI · no exit](#ai-req-exit) |
| **Capabilities warmup** | `src/contexts/AuthContext.tsx` (`MeCapabilitiesWarmup`) | **`useMeCapabilities(token)`** when `token` is set — same class of concern as `many_faces_portal`: verify **no duplicate** `/me/capabilities` fetches vs pages that need ACL. | [REQ · AI · no exit](#ai-req-exit) |
| **React Query defaults** | `src/providers/QueryProvider.tsx` | Module-level `QueryClient`: `refetchOnWindowFocus: false`, `retry: 1`, default `staleTime: 5 * 60 * 1000`. **No `gcTime`** set explicitly — audit **per-hook** alignment for large tables (users, faces, pages). | [REQ · AI · no exit](#ai-req-exit) |
| **Auth + polling** | `src/contexts/AuthContext.tsx` | **`setInterval(checkExpiry, 30_000)`** when authenticated — overlaps with **`useAuthToken`** semantics; candidate for **visibility API** or **Query-driven** expiry only. | [REQ · AI · no exit](#ai-req-exit) |
| **Auth provider value** | `src/contexts/AuthContext.tsx` | **`AuthContext.Provider value={{ … }}`** new object each render — any `useAuth()` consumer may re-render with parent even if primitives unchanged. | [REQ · AI · no exit](#ai-req-exit) |
| **Provider tree** | `src/main.tsx`, `src/App.tsx` | `StrictMode` → **`QueryProvider`** → **`App`** → **`AppProvider`** → **`AuthProvider`** → **`BrowserRouter`** → **`AppContent`** + **`ToastContainer`**. | [REQ · AI · no exit](#ai-req-exit) |
| **API interceptors** | `src/api/config.ts`, `src/api/interceptors.ts` | Request interceptor applies **`applyFacePrefixToRequestUrl`** on matching URLs — hot path for high-churn admin UIs; **401** refresh / logout policy lives in interceptors. | [REQ · AI · no exit](#ai-req-exit) |
| **i18n bundle** | `src/i18n/config.ts` | **Static JSON imports** for `en`, `sk`, `cz` into namespace `common` — full locale payloads in initial JS (same trade-off as `many_faces_portal`). | [REQ · AI · no exit](#ai-req-exit) |
| **Admin chrome** | `src/components/AdminLayout.tsx`, `Sidebar.tsx`, `Header.tsx` | **`framer-motion`** in layout/sidebar — ensure animations do not force **layout thrash** on every navigation; **`prefers-reduced-motion`** is **mandatory** to respect (see §2.1). | [REQ · AI · no exit](#ai-req-exit) |
| **Motion + a11y** | Same as admin chrome | **`(prefers-reduced-motion: reduce)`** — shorten or skip motion (`framer-motion` **`useReducedMotion`**, `reduced` motion config, or CSS). Reduces CPU and meets accessibility expectations. | [REQ · AI · no exit](#ai-req-exit) |
| **Realtime (AI chat)** | `src/pages/ChatPage.tsx` | **SignalR** `HubConnectionBuilder` inline — **~230 lines**; candidate for **shared hub helper** (URL, token, reconnect, logging) if more hubs appear later. | [REQ · AI · no exit](#ai-req-exit) |
| **TanStack Table** | `src/components/UsersTable.tsx`, `FacesTable.tsx`, `PagesTable.tsx` | **`@tanstack/react-table`** `useReactTable` returns **function-heavy** instances; in-repo comments reference **React Compiler** friction — audit **stable column defs / data**, **memo**d row cells, Profiler on **sort / pagination**. Cross-read [react-hooks-compiler-rules-rollout-agent-prompt.md](./react-hooks-compiler-rules-rollout-agent-prompt.md). | [REQ · AI · no exit](#ai-req-exit) |
| **Data tables (general)** | Same three files | List UIs — **virtualization** if row counts grow (Profiler first); overlaps with TanStack row above. | [REQ · AI · no exit](#ai-req-exit) |
| **CRUD / forms** | `src/pages/CreateUserPage.tsx`, `EditUserPage.tsx`, `CreateFacePage.tsx`, `EditFacePage.tsx`, `CreatePagePage.tsx`, `EditPagePage.tsx`, … | **`react-hook-form`** + **yup** (where used) — **`watch`** / subscription mode, **validation timing**, and **avoiding refetch storms** after mutations. | [REQ · AI · no exit](#ai-req-exit) |
| **Global toasts** | `src/App.tsx` (`ToastContainer`) | **`react-toastify`** — stable props, optional **`limit`** to avoid toast storms after **401** / logout bursts. | [REQ · AI · no exit](#ai-req-exit) |
| **Toast CSS critical path** | `src/main.tsx` | **`react-toastify/dist/ReactToastify.css`** imported at startup — see §2.6 and §5 Phase D (defer or waive with bundle proof). | [REQ · AI · no exit](#ai-req-exit) |
| **Language routing** | `src/components/LanguageRouter.tsx`, `src/hooks/useLocalizedLink.ts`, `useLocalizedNavigate.ts` | Must stay aligned with **`getAllRouteTranslations`** / `i18n` after route extraction. | [REQ · AI · no exit](#ai-req-exit) |
| **Unused / questionable deps** | `package.json` | **`react-grid-layout`**: no **`src/`** imports today — **remove** or **document**. Also run **`depcheck`** (or equivalent manual audit) once for **other** unused or misleading dependencies; fix or **waiver with dependency policy** note in PR. | [REQ · AI · no exit](#ai-req-exit) |

---

## 2. Performance analysis (what to fix and why)

### 2.1 Initial load / JavaScript payload (TTI, FCP, LCP)

- [ ] **[REQUIRED — no agent exit until done]** **No route-level code splitting today:** `App.tsx` statically imports every page. Initial bundle pays for **routes the user may never visit** (e.g. wall tickets, page editor, chat). [REQ · AI · no exit](#ai-req-exit)
  - **Action:** Introduce `React.lazy` + `Suspense` with minimal fallback for **infrequent** admin routes first; keep **login** (and optionally **dashboard**) eager if product requires instant first paint.
- [ ] **[REQUIRED — no agent exit until done]** **`framer-motion`:** already on **`AdminLayout` / `Sidebar`** — measure bundle share; consider **dynamic import** of motion-heavy branches only if analyze shows meaningful weight (or waive with bundle table). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`prefers-reduced-motion`:** implement **reduced or disabled** sidebar / layout motion when **`(prefers-reduced-motion: reduce)`** matches — use **`framer-motion`** **`useReducedMotion`**, `motion` config with **`reduced`**, and/or CSS. **REQUIRED** for accessibility and can lower main-thread animation cost; document the chosen approach in the PR. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **i18n:** evaluate **`i18next` lazy loading** vs static JSON for `common` namespace — measure gzip / rollup chunk before deciding. [REQ · AI · no exit](#ai-req-exit)

### 2.2 Network and caching (TanStack Query)

- [ ] **[REQUIRED — no agent exit until done]** Document a **matrix**: default **`staleTime`** vs hooks (`useAuthToken`, `useUsersApi`, `useFacesApi`, `usePagesApi`, `usePageTypesApi`, …) — which data is **stale-ok** vs **must refetch** on focus/mount. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Consider **`gcTime`** for large list queries after navigating away from heavy tables. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Audit **`enabled`** flags so disabled queries do not fire when `token` is null or on guest-only routes. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **ACL / capabilities in UI:** map which components read **`useMeCapabilities`** (or related) vs relying only on **`MeCapabilitiesWarmup`**; ensure **no duplicate `/me/capabilities`** fetches unless product-intentional. For **disallowed** actions, prefer **not mounting** heavy editors or list tooling over only **CSS-hiding** controls — or **waive in PR** with UX/product note and network proof. [REQ · AI · no exit](#ai-req-exit)

### 2.3 Main thread and re-renders

- [ ] **[REQUIRED — no agent exit until done]** **`AuthContext.Provider` value:** memoize with **`useMemo`** (correct deps) or **split contexts** (state vs actions) if Profiler shows broad subtree churn. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`AppContent` / route maps:** reduce repeated **`getRoutePaths`** work (§ Quick wins); extract **presentational** route rows if it clarifies memo boundaries. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`withLayout` helper:** align with § Quick wins — **stable** factory (`useCallback`, module-level helper, or static JSX) if Profiler shows unnecessary child churn. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **TanStack Table (`useReactTable`):** keep **column definitions** and **data** references stable where the table docs recommend; Profiler commits on **sort / filter / pagination**; reconcile with **eslint / React Compiler** rules per [react-hooks-compiler-rules-rollout-agent-prompt.md](./react-hooks-compiler-rules-rollout-agent-prompt.md) if those files are flagged. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Axios request interceptor:** if profiling shows cost, consider subscribing to **router location** once and passing a **memoized** face-prefix input — **only** if contract with `faceApiRouting` stays identical. [REQ · AI · no exit](#ai-req-exit)

### 2.4 Realtime (SignalR)

- [ ] **[REQUIRED — no agent exit until done]** **`ChatPage` hub lifecycle:** ensure **clean stop** on unmount, **token** changes, and **tab visibility** if product cares about background connections. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Extract a **small `buildHubConnection` helper** (base URL, access token factory, logging, reconnect policy) **or** waive with note that only one hub exists today — still document extension point in PR. [REQ · AI · no exit](#ai-req-exit)

### 2.5 Timers and background work

- [ ] **[REQUIRED — no agent exit until done]** **`AuthContext` `setInterval` every 30s:** align with **`useAuthToken`** / refresh flow — avoid redundant wakeups when `document.visibilityState === 'hidden'` unless product mandates otherwise. [REQ · AI · no exit](#ai-req-exit)

### 2.6 Assets and CSS

- [ ] **[REQUIRED — no agent exit until done]** **Sass pipeline:** `main.scss` and partials — no accidental **huge** imports on the critical path. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Tables / avatars:** lazy images, dimensions where applicable to reduce CLS. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`react-toastify` global CSS** (`main.tsx`): evaluate **deferring** toast stylesheet to an **authenticated** lazy chunk or **admin-only** entry — **or** **waive** with before/after bundle bytes (ties to §5 Phase D). [REQ · AI · no exit](#ai-req-exit)

### 2.7 Logging, telemetry, and dev-only work

- [ ] **[REQUIRED — no agent exit until done]** **Never call `logger.*` synchronously in render** for high-frequency components (see `AppContent` quick win). Prefer **`useEffect`** with explicit deps or **sampling**. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`src/utils/logger.ts`** flush / interval behavior — if Seq forwarding exists, confirm **backoff** when `document.hidden` (or waive with ops note). [REQ · AI · no exit](#ai-req-exit)

### 2.8 Duplicate auth / session work (conceptual consolidation)

**`many_faces_admin` today:** session teardown after **failed refresh** is driven by **`src/api/interceptors.ts`** (**`forceLogout`**, redirect to login, **`setAuthToken(null)`**) — not by a documented **`window` `auth:unauthorized`** event unless the codebase adds one. Keep this mental model when consolidating layers.

Layers touching session health:

- [ ] **[REQUIRED — no agent exit until done]** **React Query** `useAuthToken` + cache clearing on logout paths. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`AuthContext` localStorage bootstrap** + sync from **`tokenData`**. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`setInterval` expiry check** (§2.5). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`setupAxiosInterceptors`** — **401** refresh queue, **`forceLogout`**, and **redirect / toast** behaviour consistent with **`AuthContext`** logout UX. [REQ · AI · no exit](#ai-req-exit)

**Goal:** one clear story for **token invalid → logout UI** where possible; document **intended redundancy** in the PR after any consolidation.

- [ ] **[REQUIRED — no agent exit until done]** In the **PR body**, document **source of truth** for session expiry and logout UX after §2.8 work (even if multi-layered on purpose). [REQ · AI · no exit](#ai-req-exit)

### 2.9 Route generation cost (`getRoutePaths` / `i18n.t`)

- [ ] **[REQUIRED — no agent exit until done]** Memoize per-language route tables (`useMemo` keyed by `i18n.language` / `currentLanguage`) or **precompute** in a pure module — same pattern as `many_faces_portal` §2.9. [REQ · AI · no exit](#ai-req-exit)

### 2.10 Vite / Rollup build tuning (after bundle analyze)

- [ ] **[REQUIRED — no agent exit until done]** Evaluate **`build.rollupOptions.output.manualChunks`** for stable vendors (`react`, `react-dom`, `react-router`, `@tanstack/react-query`, `@microsoft/signalr`, `framer-motion` if large). If **no** `manualChunks` change, PR **must** explain why + cite bundle output. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`modulePreload` / preload** — decide with evidence or document waiver. [REQ · AI · no exit](#ai-req-exit)

### 2.11 Forms and CRUD pages (react-hook-form / validation)

- [ ] **[REQUIRED — no agent exit until done]** Audit **create/edit** flows (users, faces, pages, …): **`watch`** usage and **default vs `onChange` / `onBlur`** validation modes — avoid **main-thread churn** on every keystroke where not needed; align **mutation success** handlers so list queries **invalidate** selectively (not blanket refetch of every admin list). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Profiler** at least one **heavy form** (open, type, submit): document hotspots or **waive** with “form acceptable” note + commit timings. [REQ · AI · no exit](#ai-req-exit)

---

## 3. Refactor inventory (structural debt)

These are **maintainability** items that also unlock performance work.

### 3.1 Split `App.tsx` / `AppContent` into cohesive modules

Target structure (example — adjust names to taste):

- [ ] **[REQUIRED — no agent exit until done]** `src/routes/` — language layout wrapper, **guest** routes (`LoginPage`), **protected** admin routes, optional `lazyPages.tsx` + `routeLoadingFallback.tsx`. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** `src/shell/` or `src/layout/` — thin composition re-exports if it clarifies **AdminLayout** boundaries (no new data fetching in shell-only files). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** `src/features/` (optional) — group **users**, **faces**, **pages**, **chat** route modules or lazy entry points for readability. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Keep **`getRoutePaths` / `getAllRouteTranslations`** in **pure** modules with tests (extend `utils/__tests__/routeTranslations.test.ts` and any new routing helpers). [REQ · AI · no exit](#ai-req-exit)

### 3.2 Context hygiene

- [ ] **[REQUIRED — no agent exit until done]** **Memoize** or **split** `AuthContext` value (§2.3). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Stabilize `AppContext`:** `useCallback` for `changeLanguage`, `useMemo` for provider `value` (verify `t` identity across i18n events with Profiler). [REQ · AI · no exit](#ai-req-exit)

### 3.3 Realtime and API patterns

- [ ] **[REQUIRED — no agent exit until done]** Shared **SignalR hub builder** helper or documented single-hub policy (§2.4). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Align **ChatPage** errors (connection drop, **401**) with global **logout** / toast policy where appropriate. [REQ · AI · no exit](#ai-req-exit)

### 3.4 Type safety and boundaries

- [ ] **[REQUIRED — no agent exit until done]** Reduce `any` in tests and window mocks where it blocks refactors — follow patterns from existing `many_faces_admin` hook tests. [REQ · AI · no exit](#ai-req-exit)

### 3.5 ACL and capabilities (UI layer)

- [ ] **[REQUIRED — no agent exit until done]** Produce a short **map** (PR appendix or comment): **which routes/components** depend on **`/me/capabilities`** vs route guards only; ensure **`MeCapabilitiesWarmup`** remains the **single early fetch** unless product requires otherwise (see also §2.2 ACL bullet). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** For **capability-gated** UI, document whether **hidden** controls still **mount** heavy children — align with §2.2 or waive with product approval. [REQ · AI · no exit](#ai-req-exit)

---

## 4. Measurement protocol (required before large changes)

Record numbers in the PR description (table: before → after).

### 4.1 PR waiver block (copy into PR when skipping code)

When any **§0–§6** item is **waived** (not implemented), paste a block **per waiver** so the exit rule is satisfied:

```text
Waiver — [section id, e.g. §2.6 toast CSS]
- Area / file:
- Metric before → after (or N/A with reason):
- Why not implemented (product / risk / measured no gain):
- Evidence link (Profiler export, bundle table row, Lighthouse screenshot):
```

**Pre AI:** Každý **waiver** v PR je **legálna náhrada dokončenia** len ak spĺňa tú istú latku ako body s **[REQ · AI · no exit](#ai-req-exit)** — pozri [pravidlo ukončenia](#ai-req-exit).

- [ ] **[REQUIRED — no agent exit until done]** **Bundle:** `yarn build` in `many_faces_admin` — analyze output (`rollup-plugin-visualizer` or equivalent — devDependency only if team accepts). Capture **total JS**, **largest chunks**. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Lighthouse** (Chrome) on **preview**: Performance + **TBT** + **LCP** for default language **login** and **authenticated dashboard**. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **React Profiler** (production build): commit duration for **open sidebar**, **navigate users → faces → chat**, **open a heavy table page**. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Network:** DevTools **disable cache** — count duplicate **`/me/capabilities`** (if any) + list endpoints on cold authenticated load. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Chrome Performance** trace (5–10s) during navigation — or **waive** with screenshot + substitute evidence (extended Profiler). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Any **waived** §0–§6 item uses the **§4.1 waiver block** (or equivalent table) in the PR body with **metrics / evidence** — same bar as the **Engagement exit rule**. [REQ · AI · no exit](#ai-req-exit)

---

## 5. Phased implementation plan (suggested order)

**Phase A — Quick wins (low risk)**  
- [ ] **[REQUIRED — no agent exit until done]** Profiler + bundle baseline (§4). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Remove or guard **`logger.info` in `AppContent`** render path (§ Quick wins). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`AppContext`** stable callbacks + stable provider `value`. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`AuthContext`** `useMemo` on provider value where safe. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Memoize **route path lists** (`getRoutePaths` / §2.9). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Auth interval + visibility / Query alignment (§2.5). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Remove or justify **`react-grid-layout`** dependency if still unused after audit. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Run **`depcheck`** (e.g. `yarn dlx depcheck`) **or** an agreed equivalent — address **any other** unused or misleading **heavy** dependencies found (not only `react-grid-layout`); **waiver** requires dependency-policy note in PR. [REQ · AI · no exit](#ai-req-exit)

**Phase B — Route splitting**  
- [ ] **[REQUIRED — no agent exit until done]** `React.lazy` for **protected** and **infrequent** routes first (wall tickets, page create/edit, chat). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Suspense fallbacks consistent with admin UI (skeleton / subtle spinner). [REQ · AI · no exit](#ai-req-exit)

**Phase C — `App.tsx` decomposition**  
- [ ] **[REQUIRED — no agent exit until done]** Extract route modules; reduce `App.tsx` to **providers + router shell** (goal **well under ~320 lines**, ideally **< ~200** for `App` + thin `AppContent` or split files). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Optional **`features/*`** lazy entry points for large admin areas. [REQ · AI · no exit](#ai-req-exit)

**Phase D — Deeper optimizations (REQUIRED: decide + implement or waive)**  
After Phases A–C, **re-measure**. Each item is **mandatory** — implement in `many_faces_admin` or **waive in PR** with before/after metrics.

- [ ] **[REQUIRED — no agent exit until done]** i18n lazy loading **or** documented waiver + bundle table. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** Interceptor / face-prefix memoization **or** documented waiver + request-count evidence. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **Virtualized** tables **or** documented waiver (max row contract + Profiler). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`framer-motion` chunk strategy** **or** waiver with analyze proof. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** **`react-toastify` CSS** on the critical path — **defer** / **split** with lazy auth shell **or** **waiver** with bundle byte table (see §2.6). [REQ · AI · no exit](#ai-req-exit)

---

## 6. Acceptance criteria (definition of done)

- [ ] **[REQUIRED — no agent exit until done]** PR lists **bundle stats** before/after and **Profiler** (or Performance) evidence for at least **two** flows (e.g. cold login, dashboard → users table). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** No regression in **auth**, **token refresh** (**`setupAxiosInterceptors`** / **`forceLogout`** paths), **SignalR chat**, **face-prefixed API** URLs (existing tests + manual smoke). [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** `yarn validate` and **`yarn test`** (use **`yarn vitest run`** / **`vitest run`** in CI logs if that is the project’s non-watch default — keep **non-interactive** runs green) green in `many_faces_admin`; **`yarn build`** green. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** If new lazy routes: document **fallback UX** in PR; SPA SEO constraints unchanged. [REQ · AI · no exit](#ai-req-exit)
- [ ] **[REQUIRED — no agent exit until done]** If project adds **Cypress** (or similar) for `many_faces_admin`, smoke still passes **or** PR documents manual substitute checklist. [REQ · AI · no exit](#ai-req-exit)

---

## 7. Non-goals (avoid rabbit holes)

These bullets are **not** deliverables and **do not** use the `[ ]` / exit rule — **do not** “complete” them as tasks; they forbid scope creep.

- Rewriting **OpenAPI generated** `src/api/**` (except thin wrappers and interceptors glue).  
- Replacing **React Router** without explicit product approval.  
- Premature **`useCallback` on every handler** without Profiler proof.  
- Re-implementing **`many_faces_portal`** features inside `many_faces_admin`.

---

## 8. Related documentation

- [docs/guides/development.md](../guides/development.md) — local scripts (`yarn validate`, etc.).  
- [docs/readmes/admin-demo-overview.md](../readmes/admin-demo-overview.md) — high-level **`many_faces_admin`** architecture (update after large routing/context refactors).  
- [docs/prompts/fe-performance-and-refactor-agent-prompt.md](./fe-performance-and-refactor-agent-prompt.md) — **parallel** spec for `many_faces_portal` (keep concerns symmetric where useful).  
- [docs/prompts/react-hooks-compiler-rules-rollout-agent-prompt.md](./react-hooks-compiler-rules-rollout-agent-prompt.md) — hook lint alignment after refactors.  
- [docs/prompts/unit-test-gap-fill-agent-prompt.md](./unit-test-gap-fill-agent-prompt.md) — tests for extracted pure modules and hooks.

---

## 9. Prompt maintenance (for future passes)

When code moves (line counts, new pages, new hubs), update **§1** paths and re-verify **§ Quick wins**. If a hotspot is **fixed in repo**, add a one-line **“Resolved in PR #…”** note in the PR checklist rather than ticking this file’s `[ ]` rows globally (per [prompts/README.md](./README.md) retention rules).

---

## 10. Master checklist (all bodies — final pass)

Use this as a **single closing pass** over the entire prompt. **Same rules as above:** each `- [ ]` is **mandatory** under the **Engagement exit rule** unless the row is explicitly **out of scope** (§7) or **reference-only** (§8). **Do not tick this canonical file in git** — mirror ticks in the **PR / issue** ([prompts/README.md](./README.md)).

### 10.0 Read first

- [ ] **Engagement exit rule** (EN + SK): understood; agent will not exit until §0–§6 + tables below are satisfied or waived with PR evidence. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Out of scope** (Purpose paragraph): no unscoped work in `many_faces_portal` / `many_faces_backend` / etc. unless explicitly added to the task. [REQ · AI · no exit](#ai-req-exit)

### 10.1 Quick wins table (four signals)

- [ ] **`logger.info` in `AppContent` render path** — guard, sample, remove, or move to `useEffect`; or PR waiver with Profiler proof. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`AppContext` provider** — stable `changeLanguage` + stable `value`; or PR waiver with Profiler proof. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`getRoutePaths` in render** — memoized / precomputed; or PR waiver with Profiler proof. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`withLayout` stability** — hoist / `useCallback` / factory pattern; or PR waiver with Profiler proof. [REQ · AI · no exit](#ai-req-exit)

### 10.2 §1 Repository inventory (every *Area* row)

- [ ] **God module / routing shell** (`App.tsx` / `AppContent`) — refactor / split / metrics or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Render-path logging** (`AppContent`) — aligned with Quick wins row. [REQ · AI · no exit](#ai-req-exit)
- [ ] **App shell context** (`AppContext.tsx`) — aligned with Quick wins / §3.2. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Capabilities warmup** (`MeCapabilitiesWarmup` / `useMeCapabilities`) — duplicate fetch / `enabled` gates verified or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **React Query defaults** (`QueryProvider.tsx`) — matrix (§2.2) or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Auth + polling** (`AuthContext.tsx`) — §2.5 closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Auth provider value** (`AuthContext.tsx` inline `value={{…}}`) — §2.3 / §3.2 closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Provider tree** (`main.tsx`, `App.tsx`) — evaluated or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **API interceptors** (`api/config.ts`, `interceptors.ts`) — §2.3 / Phase D closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **i18n bundle** (`i18n/config.ts`) — lazy-load decision (§2.1 / Phase D) closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Admin chrome** (`AdminLayout`, `Sidebar`, `Header` + motion) — Profiler / motion cost closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Motion + a11y** (`prefers-reduced-motion`) — §2.1 satisfied or waived with UX note. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Realtime** (`ChatPage.tsx`) — hub lifecycle + helper extraction policy closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **TanStack Table** (`UsersTable`, `FacesTable`, `PagesTable`) — stable defs + Compiler alignment or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Data tables (general)** — virtualization / memo follow-ups or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **CRUD / forms** — §2.11 + mutation invalidation or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Global toasts** (`ToastContainer`) — props / limit or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Toast CSS critical path** (`main.tsx`) — §2.6 / Phase D closed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Language routing** (`LanguageRouter`, localized hooks) — still correct after refactors or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **Unused deps** (`depcheck`, `react-grid-layout`, others) — removed, justified, or waived with dependency policy note. [REQ · AI · no exit](#ai-req-exit)

### 10.3 §0 Preconditions

- [ ] Baseline clean; `yarn install --immutable` succeeds. [REQ · AI · no exit](#ai-req-exit)
- [ ] Profiling uses **production build** (`yarn build && yarn preview`) where meaningful. [REQ · AI · no exit](#ai-req-exit)
- [ ] Security / auth invariant preserved (**OAuth2**, **`setupAxiosInterceptors`** / **`forceLogout`**, **`setAuthToken`** — do not assume **`auth:unauthorized`** unless repo adds it). [REQ · AI · no exit](#ai-req-exit)

### 10.4 §2 Performance analysis

**§2.1 Initial load / payload**

- [ ] Route-level code splitting plan or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] `framer-motion` strategy or waiver with bundle evidence. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`prefers-reduced-motion`** implemented or waived with a11y + metrics note. [REQ · AI · no exit](#ai-req-exit)
- [ ] i18n lazy loading evaluated or waived. [REQ · AI · no exit](#ai-req-exit)

**§2.2 Network / TanStack Query**

- [ ] `staleTime` matrix documented or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] `gcTime` for large lists considered or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] `enabled` flags audited. [REQ · AI · no exit](#ai-req-exit)
- [ ] **ACL / capabilities UI** (duplicate fetch, heavy hidden UI) closed or waived. [REQ · AI · no exit](#ai-req-exit)

**§2.3 Main thread / re-renders**

- [ ] `AuthContext` provider value stabilized or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] `AppContent` / route extraction + memo where Profiler shows waste or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`withLayout`** stabilized or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **TanStack Table** / Compiler alignment or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Axios interceptor / face prefix optimization or waiver. [REQ · AI · no exit](#ai-req-exit)

**§2.4 SignalR**

- [ ] `ChatPage` lifecycle + shared helper policy closed or waived. [REQ · AI · no exit](#ai-req-exit)

**§2.5 Timers / background**

- [ ] `AuthContext` interval + visibility / Query alignment or waiver. [REQ · AI · no exit](#ai-req-exit)

**§2.6 Assets / CSS**

- [ ] Sass critical path or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Table images / CLS or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`react-toastify` CSS** defer or waiver (bundle bytes). [REQ · AI · no exit](#ai-req-exit)

**§2.7 Logging / telemetry**

- [ ] No unguarded `logger.*` in hot render paths or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Logger flush / hidden-doc behavior or waiver. [REQ · AI · no exit](#ai-req-exit)

**§2.8 Duplicate auth / session**

- [ ] `useAuthToken` + storage story clear or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] `AuthContext` bootstrap + sync `useEffect` reviewed or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] `setInterval` aligned with §2.5 outcome or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`interceptors.ts` / `forceLogout` / 401** policy clear or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **PR body:** source of truth for session expiry + logout UX. [REQ · AI · no exit](#ai-req-exit)

**§2.9 Route generation**

- [ ] `getRoutePaths` / `i18n.t` memoized or precomputed or waiver. [REQ · AI · no exit](#ai-req-exit)

**§2.10 Vite / Rollup**

- [ ] `manualChunks` evaluated — change or PR explains why not + bundle cite. [REQ · AI · no exit](#ai-req-exit)
- [ ] `modulePreload` decision documented or waived. [REQ · AI · no exit](#ai-req-exit)

**§2.11 Forms / CRUD**

- [ ] Form / mutation Profiler or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Selective invalidation or waiver. [REQ · AI · no exit](#ai-req-exit)

### 10.5 §3 Refactor inventory

**§3.1 Split `App.tsx`**

- [ ] `src/routes/` structure landed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] `src/shell/` / `src/features/` optional structure landed or waived. [REQ · AI · no exit](#ai-req-exit)
- [ ] Pure route translation helpers + tests extended or waiver. [REQ · AI · no exit](#ai-req-exit)

**§3.2 Context hygiene**

- [ ] `AuthContext` + `AppContext` memoization / split (§2.3) or waiver. [REQ · AI · no exit](#ai-req-exit)

**§3.3 Realtime / API**

- [ ] Hub helper + error alignment or waiver. [REQ · AI · no exit](#ai-req-exit)

**§3.4 Types**

- [ ] `any` reduction in tests/mocks where blocking or waiver. [REQ · AI · no exit](#ai-req-exit)

**§3.5 ACL / capabilities (UI)**

- [ ] Capability consumption map + warmup policy or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Hidden vs unmounted heavy UI documented or waived. [REQ · AI · no exit](#ai-req-exit)

### 10.6 §4 Measurement protocol

- [ ] Bundle analyze recorded. [REQ · AI · no exit](#ai-req-exit)
- [ ] Lighthouse guest + authed (or waiver). [REQ · AI · no exit](#ai-req-exit)
- [ ] React Profiler flows recorded. [REQ · AI · no exit](#ai-req-exit)
- [ ] Network duplicate fetches counted or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Chrome Performance trace or waiver + substitute. [REQ · AI · no exit](#ai-req-exit)
- [ ] **§4.1 waiver blocks** in PR for every waived mandatory item. [REQ · AI · no exit](#ai-req-exit)

### 10.7 §5 Phased implementation

**Phase A**

- [ ] Baseline measured. [REQ · AI · no exit](#ai-req-exit)
- [ ] `AppContent` render-path logger fixed/guarded. [REQ · AI · no exit](#ai-req-exit)
- [ ] `AppContext` + `AuthContext` provider fixes. [REQ · AI · no exit](#ai-req-exit)
- [ ] Route path memoization. [REQ · AI · no exit](#ai-req-exit)
- [ ] Auth interval / visibility alignment. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`depcheck`** / unused-deps audit (incl. `react-grid-layout`) outcome. [REQ · AI · no exit](#ai-req-exit)

**Phase B**

- [ ] `React.lazy` for protected / infrequent routes. [REQ · AI · no exit](#ai-req-exit)
- [ ] Suspense fallbacks aligned. [REQ · AI · no exit](#ai-req-exit)

**Phase C**

- [ ] `App.tsx` / `AppContent` slimmed (line goal or waiver). [REQ · AI · no exit](#ai-req-exit)
- [ ] Optional feature lazy entry points. [REQ · AI · no exit](#ai-req-exit)

**Phase D**

- [ ] i18n lazy load or waiver + table. [REQ · AI · no exit](#ai-req-exit)
- [ ] Interceptor memoization or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] Virtualized tables or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] `framer-motion` chunk strategy or waiver. [REQ · AI · no exit](#ai-req-exit)
- [ ] **`react-toastify` CSS** defer or waiver + bytes. [REQ · AI · no exit](#ai-req-exit)

### 10.8 §6 Acceptance criteria

- [ ] PR: bundle + Profiler/Performance for **≥ two** flows. [REQ · AI · no exit](#ai-req-exit)
- [ ] No regression: auth, **`interceptors` / `forceLogout`**, SignalR chat, face-prefixed URLs. [REQ · AI · no exit](#ai-req-exit)
- [ ] `yarn validate`, **`yarn test`** (non-watch / **`vitest run`** in CI if applicable), `yarn build` green. [REQ · AI · no exit](#ai-req-exit)
- [ ] Lazy routes: fallback UX documented. [REQ · AI · no exit](#ai-req-exit)
- [ ] E2E or documented manual substitute if applicable. [REQ · AI · no exit](#ai-req-exit)

### 10.9 Non-goals & references (sanity)

- [ ] **§7** respected. [REQ · AI · no exit](#ai-req-exit)
- [ ] **§8** links consulted as needed. [REQ · AI · no exit](#ai-req-exit)

### 10.10 Prompt maintenance (optional meta)

- [ ] If this prompt was edited: **§1** / **§ Quick wins** updated; PR references [prompts/README.md](./README.md) policy for canonical file ticks. [REQ · AI · no exit](#ai-req-exit)
