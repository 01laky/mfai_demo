# Many Faces Mobile — Phase 1 Foundation — Agent Prompt (Expo / React Native)

**Language:** All **new** prose you add to the codebase (README, guides, comments in new mobile files) must be **English**.

**Mission:** Turn the `many_faces_mobile` git submodule into a **production-grade skeleton** of the Many Faces user experience: **config-driven navigation and auth parity** with `many_faces_portal`, a **README in the same narrative style** as the portal (product story, AI-assisted workflows as context, security posture, engineering stack), **developer tooling** (ESLint, Prettier, TypeScript, **strict `tsconfig`**, Husky, lint-staged, commitlint aligned with the SPAs), **documented git/submodule workflow**, **required** CI in `many_faces_main` **and** a standalone workflow in the submodule, plus **required** integration into `scripts/ci-local.sh` / `lint-all.sh` / `test-all.sh`. Do **not** implement the full page grid / `gridSchema` renderer in phase 1 — only foundations, placeholders, and extension points.

**Canonical human guide:** after implementation, developers start from [`docs/guides/mobile-expo-development.md`](../guides/mobile-expo-development.md) (keep it accurate; update it whenever setup commands change).

---

## 1. Context — Why this submodule exists

The Many Faces monorepo (`many_faces_main`) is a multi-submodule demo of a **face-scoped social platform**: configurable “faces” (tenants), OAuth2/JWT auth, ASP.NET Core API (`many_faces_backend`), Redis-backed jobs, a Python gRPC AI service (`many_faces_ai`), and rich web SPAs (`many_faces_portal`, `many_faces_admin`). **User-created** albums, blogs, and reels can enter an **AI-assisted moderation pipeline** (pending approval, admin queue, creator “My submissions”) — see [`docs/guides/ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md).

The **mobile app** is the portable client for the **same product story**. Phase 1 does **not** ship every web module; it **does** establish the same **configuration contract** (`GET /api/faces/config`), the same **auth model** (password + refresh, **`rememberMe` parity with the portal**), and a **shell UI** that reflects the selected face’s branding (`gradientSettings`). Future phases add grid renderers, SignalR, “My submissions”, etc.

---

## 2. Hard scope boundaries

### 2.1 In scope (Phase 1)

- **Submodule hygiene:** `many_faces_mobile` remains a **separate git repo**; all tooling config lives inside it (`package.json`, `eslint.config.*`, `.prettierrc`, **`.husky/`**, `commitlint.config.*`). **You must** add **both**: (1) a **`many_faces_mobile`** job in `many_faces_main/.github/workflows/ci.yml`, and (2) **`many_faces_mobile/.github/workflows/ci.yml`** so the submodule passes CI when cloned standalone.
- **README (portal style):** long-form overview: faces concept, auth, link to AI-assisted approval doc as **product context**, security notes, Expo/React Native stack, scripts table, local dev, testing, **CI status badge** in **`many_faces_mobile/README.md`** pointing to **this submodule’s** GitHub Actions; the monorepo root README **may** duplicate a short badge only if it links to the same workflow — document the single source of truth in the mobile README.
- **Guide sync:** [`docs/guides/mobile-expo-development.md`](../guides/mobile-expo-development.md) — exact prerequisites, `nvm use`, `npm install`, `npm run start`, env var names, Expo Go notes, submodule bump workflow, links to portal files for parity.
- **API types:** TypeScript types aligned with `many_faces_portal/src/api/types/facesConfig.ts` — copy or maintain a thin duplicate **inside** `many_faces_mobile` for phase 1. **Do not** introduce a new published npm package for shared types in this phase.
- **`getFacesConfig` equivalent:** one module that performs `GET {baseUrl}/api/faces/config`; send **`Authorization: Bearer <accessToken>`** when the access token string is non-empty — omit the header otherwise.
- **React contexts:** **`FaceConfigProvider`** and **`AuthProvider`** — use these **exact** export names (match portal grep/review ergonomics).
- **Navigation:** **React Navigation** (stack + nested stacks/tabs as needed). **Expo Router is forbidden** in phase 1. Routes must be **data-driven** from config: build a list of navigable targets from `selectedFace.pages` (unknown `pageType.index` → **`PlaceholderScreen`** with `page.name` + `pageType.index`).
- **Screens (minimum — all required):**
  - **Loading / error** while faces config loads.
  - **Login** — fields and semantics aligned with `many_faces_portal/src/pages/LoginPage.tsx` (email, password, stay signed in).
  - **Register** — screen and flow aligned with `many_faces_portal/src/pages/RegisterPage.tsx` at the same level of quality as Login (validation, error display, success path); wire to config when the face exposes a register page (`pageType` / path parity with portal).
  - **Post-login home** — navigate to the page where `pageType.index === 'home'` for the selected face (same derivation as `getFaceHomePath()` in `FaceConfigContext.tsx`).
  - **App shell** — top bar: brand, face-aware gradient background, guest vs authenticated affordance (simplified vs web but recognisable).
- **Persistence:** `selectedFaceId` and tokens in **`expo-secure-store`** on iOS/Android. For **Expo web** or any platform where SecureStore is unavailable, you **must** implement a **documented** fallback (e.g. in-memory only for dev web, or `localStorage` behind a `__DEV__` guard) in code + README — no silent failure.
- **i18n:** **`i18next`** wired with at least **English** JSON resources; namespaces **`common`**, **`login`**, **`register`** mirroring portal keys where practical. Structure must allow adding `sk`/`cs` later without refactor.
- **Lint + format + typecheck:** ESLint (flat config), Prettier, `tsc --noEmit`, `npm` scripts documented in README.
- **Unit tests:** **Jest + `jest-expo`** — **only** supported test runner for phase 1.
- **Git workflow:** documented branch naming, **commitlint** + **Husky** + **lint-staged** mirroring `many_faces_portal` / `many_faces_admin` (ESM `commitlint.config` pattern acceptable; `prepare` script must work after `npm install`).
- **Parent monorepo CI:** **`many_faces_mobile`** job in `many_faces_main/.github/workflows/ci.yml` — `submodules: recursive`, `npm ci`, `npm run lint`, `npm run typecheck`, `npm test`, **`npx expo-doctor`** (exit non-zero fails the job), **`npm audit`** (informational: `|| true` but **must** run and print output).
- **`many_faces_mobile/.env.example`** **and** `app.config` / `extra` wiring for **`EXPO_PUBLIC_API_BASE_URL`** — **required**; **never** commit secrets or real `.env`.

### 2.2 Explicitly out of scope (later phases)

- Rendering **`gridSchema`** / `FacePageView` parity.
- SignalR / real-time chat, wall tickets, stories composer.
- **My submissions** list UI, moderation dashboards, admin flows.
- **Calling `many_faces_ai` gRPC directly from the phone** — **forbidden** in phase 1; mobile uses **HTTP** to `many_faces_backend` only.
- EAS Submit / store releases (document as future).

---

## 3. Product and README content (mirror `many_faces_portal/README.md` style)

The mobile `README.md` must be **long-form English** similar in spirit to:

`many_faces_portal/README.md` (Overview, “What This … Shows”, feature lists, security paragraph, engineering paragraph).

### 3.1 Required README sections (use these headings)

1. **Title + one-line summary** — Expo client for Many Faces AI demo; submodule of `many_faces_main`.
2. **Overview** — faces, URL/index concept (mobile uses **navigator paths** instead of browser URL but same `face.index`), public vs private faces, config from API.
3. **What this app shows (Phase 1)** — bullet list: config-driven stack, login, face shell, placeholders, future grid.
4. **Relationship to the web portal** — link to `many_faces_portal/README.md` (relative path from submodule: `../many_faces_portal/README.md` or monorepo-absolute URL on GitHub).
5. **User content & AI-assisted moderation (context only)** — 1 short subsection linking `docs/guides/ai-assisted-content-approval.md` — clarify mobile **does not** implement approval UI yet; web is canonical until mobile catches up.
6. **Security & trust** — tokens in SecureStore, HTTPS-only production, no secrets in repo, jailbreak disclaimer if appropriate (brief).
7. **Tech stack** — Expo SDK version, React Native version, TypeScript, React Navigation, testing stack.
8. **Prerequisites** — Node from `.nvmrc`, Watchman, Xcode/Android, Expo Go.
9. **Getting started** — copy-paste commands (`nvm use`, `npm install`, `cp .env.example .env`, `npm run start`).
10. **Environment variables** — table of `EXPO_PUBLIC_*` keys, example values for local dev.
11. **Scripts** — table: `start`, `android`, `ios`, `web`, `lint`, `typecheck`, `test`, `format`, `format:check`.
12. **Project layout** — `src/` tree description (`api/`, `contexts/`, `navigation/`, `screens/`, `theme/`, `i18n/`, …).
13. **Testing** — how to run unit tests locally; CI mention.
14. **Git / submodule** — how to bump pointer from parent repo; branch naming.
15. **Roadmap / Phase 2 teaser** — grid renderer, submissions, push notifications, etc.

### 3.2 Tone and honesty

- Do **not** claim features that are not implemented; label them **Roadmap** or **Phase 2**.
- Do **mention AI** and moderation **as product context** (same as portal README references approval UX).

---

## 4. Technical design — Parity with `many_faces_portal`

### 4.1 Config fetch

- Implement `getFacesConfig(token?: string | null)` using the shared HTTP wrapper (§4.7). Use **`@react-native-community/netinfo`**: if offline, **do not** fire the request; surface the offline state from the connectivity module (see §8.2).
- Base URL from `process.env.EXPO_PUBLIC_API_BASE_URL` (document in README + **required** `.env.example`).
- Headers: add `Authorization` only when `token` is non-null/non-empty.
- Errors: surface **retry** + user-readable message on the loading screen.

### 4.2 `FaceConfigContext` parity

Mirror the responsibilities of `many_faces_portal/src/contexts/FaceConfigContext.tsx`:

- Load on mount and when auth session changes.
- Derive `publicFaces`, `availableFaces` (guest → public only; authenticated → private + public union without duplicates — same order preference as portal).
- `selectedFace` resolution: persisted id with fallback to first available; sync when config reloads.
- `getFaceHomePath()` — identical **logical** result as portal: find `page` with `pageType.index === 'home'`, strip leading `/`, return `/${selectedFace.index}/${pagePath}` **or** the mobile-internal route key equivalent (document mapping: “web path segment” vs “navigator screen param”).

### 4.3 Auth parity

Mirror `many_faces_portal` OAuth2 password grant and refresh behaviour at a **high level**:

- Study `many_faces_portal/src/contexts/AuthContext.tsx`, `many_faces_portal/src/hooks/api/useAuthApi.ts`, and **`many_faces_portal/src/utils/jwtUtils.ts`** for expiry / refresh behaviour.
- Mobile **must** implement: **login**, **logout**, and **the same token refresh behaviour as the portal** on **401** / expiry (no “documented deviation” in phase 1 — match portal; if a technical blocker exists, **stop** and resolve in the same PR or split PR with explicit backend/mobile agreement).
- Store **access** and **refresh** tokens in SecureStore (per portal); clear on logout.
- `rememberMe`: honour the same API contract as the portal (`rememberMe` boolean on login); expose the checkbox in UI.

### 4.4 Navigation mapping

- Build an in-memory structure from `selectedFace.pages`: `{ path, pageTypeIndex, isPublic }` deduplicated.
- **Phase 1 screen registry:** map `pageType.index` values **`home`**, **`login`**, **`register`** (and any others the config exposes that you add as placeholders) to concrete screen components; unknown types → `PlaceholderScreen` showing `page.name` + `pageType.index` for debugging.
- **Auth gates:** unauthenticated users must not enter protected stack; mirror `GuestRoute` / `ProtectedRoute` semantics.

### 4.5 UI shell

- Parse `selectedFace.gradientSettings` (JSON string from API — same as web). If parse fails, use a **default** gradient matching Many Faces branding (document hex stops in README).
- Implement with **`expo-linear-gradient`** and **`react-native-reanimated`**. You **must** reproduce **animated** header/footer gradient behaviour equivalent to `many_faces_portal` `useAnimatedGradientStyle` + `AnimatedGradient.scss`. Any remaining deviation from pixel-perfect web output **must** be listed in README under **“Known visual deltas”** with screenshots and the technical reason — **a static gradient without motion is insufficient** for phase 1 completion.
- Header: logo (asset or wordmark), app name “The Many Faces”, right-side **Guest** / user email.
- **Footer (required):** a bottom bar or inset with static copy (e.g. copyright) matching the web shell intent; **safe-area** aware on all platforms.

### 4.6 Mobile UX primitives

- Wrap the app in **`react-native-safe-area-context`** (`SafeAreaProvider`) so header, footer, and forms respect notches and home indicators.
- **`KeyboardAvoidingView`** on **Login** and **Register** so fields and primary actions stay visible on small devices.
- Primary actions: minimum touch target **44×44** pt; **`accessibilityRole`** and **`accessibilityLabel`** on every interactive control (including icon-only).

### 4.7 HTTP client layer (thin wrapper)

- Centralise **`fetch`** in **`src/api/httpClient.ts`** (name illustrative) with: **timeout**, unified **JSON parse** errors, and **status → user-safe message** mapping (never show raw stack traces in UI). **Do not** use axios in phase 1.
- **401 handling:** **must** match portal refresh semantics (§4.3). All API calls go through this wrapper — **no** ad-hoc `fetch` in screens.
- Export typed helpers used by `getFacesConfig`, auth, and future modules.

### 4.8 Locales vs route translations

- Ship **English** UI via **`i18next`** (required). The portal uses translated URL segments (`useLocalizedLink`, `routeTranslations`); README **must** include a **“Mobile routing vs web URLs”** subsection describing how `face.index` + internal navigator state map to portal paths today, and how **`routeTranslations`** will be honoured in **phase 2** (list concrete follow-up tasks in README Roadmap — no “optional” wording).

---

## 5. Tooling — ESLint, Prettier, TypeScript

### 5.1 TypeScript

- `tsconfig.json`: **`"strict": true`** — **required** with no relaxation. If Expo template conflicts, fix template code — do not weaken `strict` in phase 1.
- **Path aliases:** **`@/`** prefixes for `src/api`, `src/contexts`, `src/screens`, `src/navigation`, `src/theme`, `src/i18n` — configure with **`babel-plugin-module-resolver`** (or Expo-supported equivalent) **and** ESLint import resolution so `npm run lint` catches bad imports.

### 5.2 ESLint (flat config)

- **Flat config** only (`eslint.config.js` or `eslint.config.mjs`).
- Include: `@eslint/js`, `typescript-eslint`, `eslint-plugin-react`, `eslint-plugin-react-hooks`, **`eslint-config-expo`**.
- **Logging rule:** implement a small **`src/utils/logger.ts`** (names illustrative); **`console.log` / `console.debug` are forbidden in `src/**`** except inside the logger implementation — enforce with ESLint (`no-console` with narrow override for the logger file only).
- Scripts: **`npm run lint`** and **`npm run lint:fix`** (both required).

### 5.3 Prettier

- `.prettierrc` + `.prettierignore` — **must** match `many_faces_portal` choices (quote style, width, trailing comma) after diffing that repo’s Prettier config.
- Scripts: **`format`**, **`format:check`** (required).
- **`eslint-config-prettier` last** in ESLint flat merge — required.

### 5.4 Husky + lint-staged + commitlint

- **Required:** Husky **9**, **lint-staged**, **commitlint** (same Conventional Commit rules as [`docs/guides/development.md`](../guides/development.md)); `prepare` script runs `husky`; pre-commit runs **`lint-staged`** (`eslint --fix` + `prettier --write` on staged files); **`commit-msg`** runs commitlint. Document troubleshooting for `npm install` in CI (use `HUSKY=0` only where documented for automation, not by default).

### 5.5 EditorConfig

- `.editorconfig` — required; align charset/indent with other submodules.

---

## 6. Gitflow, branching, and submodule discipline

### 6.1 Branch naming (document in README — required model)

Use:
- `main` — always releasable; protected if repo settings allow.
- `feature/<ticket>-short-slug` — features.
- `fix/<ticket>-short-slug` — bugfixes.
- `chore/<short-slug>` — tooling.

### 6.2 Submodule two-step

1. Push commits to `many_faces_mobile` remote.
2. In `many_faces_main`, commit the updated **gitlink** + any monorepo workflow changes (e.g. `ci.yml`).

### 6.3 Conventional Commits

- **Enforced** via **commitlint** (see §5.4). Prefixes: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` — same rules as [`docs/guides/development.md`](../guides/development.md).

### 6.4 PR strategy

- **Small PRs** in the mobile repo; parent repo PR **must** include submodule gitlink bump whenever mobile changes; CI/docs in the same parent PR when workflows change.

---

## 7. CI — `many_faces_main` GitHub Actions

### 7.1 New job: `many_faces_mobile`

Add to `.github/workflows/ci.yml` (same workflow file other jobs use):

- `runs-on: ubuntu-latest`
- `actions/checkout@v4` with `submodules: recursive`
- `actions/setup-node@v4` with `node-version-file: many_faces_mobile/.nvmrc`
- **Caching:** `cache: npm`, `cache-dependency-path: many_faces_mobile/package-lock.json`
- Steps (required order):
  1. `cd many_faces_mobile && npm ci`
  2. `npm run lint`
  3. `npm run typecheck`
  4. `npm test`
  5. **`npx expo-doctor`** — **must** exit zero (fix all doctor failures before merge).
  6. **`npm audit`** — **must** run; pipeline **must not** fail on audit (append `|| true`) but log output for triage.

### 7.2 Standalone workflow in the submodule

- **Required:** `many_faces_mobile/.github/workflows/ci.yml` mirroring the parent job steps (§7.1 items 1–6) so pushes to the mobile repo alone stay green.

### 7.3 Monorepo orchestration scripts

- **Required:** extend **`scripts/ci-local.sh`**, **`scripts/lint-all.sh`**, and **`scripts/test-all.sh`** to invoke the mobile npm scripts behind `if [ -d many_faces_mobile ]; then … fi`, with loud echo banners. Update **`docs/guides/development.md`** to state that `ci-local.sh` now includes mobile (one short paragraph is enough).

---

## 8. Testing strategy

- **Unit tests** for pure functions: path builders, `getFaceHomePath` clone, token storage wrapper (mock SecureStore).
- **Integration-style RN tests** with **`@testing-library/react-native`**: Login and Register happy path + validation errors — **`react-hook-form` + `yup`** **required**, mirroring `many_faces_portal` patterns.
- **No flaky network in unit tests:** mock the HTTP wrapper / `fetch`.
- **Snapshot tests:** **not allowed** in phase 1 — use explicit assertions only.

### 8.1 Connectivity and offline UX (**required**)

- Integrate **`@react-native-community/netinfo`** app-wide.
- When offline: show a **persistent banner** in the app shell. **Disable** config fetch, login, and register actions with clear copy. When the device returns online, show a **Retry** affordance that re-attempts the last failed network operation and refreshes UI state from NetInfo.

### 8.2 CI quality gates (repeated from §2.1 / §7.1)

- **`expo-doctor`**: **blocking** in all mobile CI jobs.
- **`npm audit`**: **required**, **non-blocking** (`|| true`), logs retained.

---

## 9. Security checklist (embed reasoning in README + code)

- HTTPS base URL in production builds.
- No tokens in **AsyncStorage** in **release** builds; **SecureStore** is the default on native. Any dev-only storage exception **must** be gated by `__DEV__` (or equivalent) and documented in README + code comments.
- Log redaction: never log full tokens.
- **iOS ATS / cleartext:** document that **HTTP** dev URLs (e.g. `http://127.0.0.1:8000`) require **`NSAppTransportSecurity`** exceptions in dev client builds or use **HTTPS** / tunnel; production must stay HTTPS.
- **Android cleartext:** if HTTP is used in dev only, document `usesCleartextTraffic` / network security config scope (dev vs release).
- Certificate pinning is **not** in scope for phase 1; rely on **HTTPS** and platform TLS stacks — **do not** add pinning tasks in this phase.

---

## 10. Deliverables checklist (tick in PR / issue — keep `[ ]` in canonical prompt file)

Copy this section into your PR description and tick items there; **do not** mass-replace `[ ]` with `[x]` in this canonical prompt unless the engagement is fully complete per repo policy.

### 10.1 Documentation

- [ ] `many_faces_mobile/README.md` — full portal-style narrative (§3.1).
- [ ] `docs/guides/mobile-expo-development.md` — **must** stay accurate: exact commands, env vars, ATS/cleartext notes, Expo Go, submodule bump — update on every setup change.
- [ ] `docs/README.md` — guides table **must** link `mobile-expo-development.md` (add or fix row if missing).
- [ ] `docs/prompts/README.md` — **must** index `mobile-phase1-foundation-agent-prompt.md` (add or fix row if missing).
- [ ] `README.md` (monorepo root) — **must** mention **`many_faces_mobile/`** in the layout / architecture section (same prominence as other submodules).

### 10.2 Application code (Phase 1)

- [ ] `getFacesConfig` + shared TS types for `FaceConfig` / `PageConfig`.
- [ ] `FaceConfigProvider` + `useFaceConfig()` hook.
- [ ] `AuthProvider` + `useAuth()` hook (login / logout / refresh **matching portal** — document endpoints in README).
- [ ] React Navigation root + authenticated stack + guest stack.
- [ ] Screens: `SplashOrLoading`, `ConfigError`, `Login`, **`Register`**, `HomePlaceholder` (wired to config), `PlaceholderPage`.
- [ ] **Login + Register** forms implemented with **`react-hook-form` + `yup`** (portal parity).
- [ ] **Animated gradients** via **Reanimated** (or equivalent **maintained** animation library) per §4.5; README **Known visual deltas** if any.
- [ ] App shell: gradient (**animated** per §4.5), header, **footer**, brand, guest/user chip.
- [ ] Root **`react-error-boundary`** (`ErrorBoundary` component) wrapping the navigation tree: catch render errors, show fallback UI, log without leaking tokens.
- [ ] **Accessibility:** labels, roles, contrast (§4.6).
- [ ] **NetInfo** offline UX (§8.1).
- [ ] `.env.example` + `app.config` / `extra` for **`EXPO_PUBLIC_API_BASE_URL`**.

### 10.3 Tooling

- [ ] ESLint flat config + **`npm run lint`** + **`npm run lint:fix`**.
- [ ] Prettier + **`npm run format`** + **`npm run format:check`** + `.prettierignore`.
- [ ] **`npm run typecheck`** (`tsc --noEmit`).
- [ ] `.editorconfig`.
- [ ] **`react-error-boundary`** dependency + root `ErrorBoundary` wiring (§10.2).
- [ ] **`src/utils/logger.ts`** + ESLint `no-console` policy (§5.2).
- [ ] **React Native Reanimated** installed and used for **animated** shell gradients (§4.5); README **Known visual deltas** section if any deviation from web remains after best effort.
- [ ] **`@/` path aliases** + Babel + ESLint import resolution (§5.1).
- [ ] Jest + `jest-expo` + **`npm test`** (CI mode, no watch).

### 10.4 CI / monorepo

- [ ] `many_faces_main/.github/workflows/ci.yml` — **`many_faces_mobile`** job: `npm ci`, `lint`, `typecheck`, `test`, **`npx expo-doctor`**, **`npm audit || true`** (§7.1).
- [ ] `many_faces_mobile/.github/workflows/ci.yml` — **standalone** workflow with the **same** steps (§7.2).
- [ ] `scripts/ci-local.sh`, `scripts/lint-all.sh`, `scripts/test-all.sh` — **must** include mobile (§7.3).

### 10.5 Git discipline

- [ ] README subsection: branch naming, submodule bump instructions, Conventional Commits + commitlint pointer.
- [ ] Example PR sequence: feature branch in submodule → merge to `main` → bump gitlink in `many_faces_main`.

### 10.6 Verification (run locally before merge)

- [ ] `cd many_faces_mobile && npm ci && npm run lint && npm run typecheck && npm test && npx expo-doctor`
- [ ] `npm audit` executed locally (result triaged; log in PR if issues).
- [ ] `npx expo start` — Login **and** Register reachable; config fetch works against running `many_faces_backend` (document prerequisite in README).
- [ ] Toggle airplane mode / NetInfo — offline banner and disabled actions behave as specified.
- [ ] No secrets in git index (`git grep -i password` clean; `.env` not tracked).

---

## 11. Hints — portal files to diff while implementing

- `many_faces_portal/src/contexts/FaceConfigContext.tsx`
- `many_faces_portal/src/contexts/AuthContext.tsx`
- `many_faces_portal/src/pages/LoginPage.tsx`
- `many_faces_portal/src/api/config/getFacesConfig.ts`
- `many_faces_portal/src/api/types/facesConfig.ts`
- `many_faces_portal/src/routes/useFaceRouteEntries.ts`
- `many_faces_portal/src/routes/facePagePaths.ts` (path expansion / translations)
- `many_faces_portal/src/pages/RegisterPage.tsx`
- `many_faces_portal/src/utils/jwtUtils.ts` (expiry + refresh alignment)
- `many_faces_portal/src/components/Header.tsx` (shell inspiration only)

---

## 12. Success criteria (Phase 1 complete when)

1. A new contributor can follow **`docs/guides/mobile-expo-development.md`** and reach **Login** and **Register** with **faces config loaded** without reading source.
2. Successful **login** and **registration** each navigate to the **same post-auth destinations** as `many_faces_portal` for the same API responses (if web behaviour is ambiguous, README **must** cite the exact portal files and line-level behaviour you matched).
3. **Offline** behaviour matches §8.1 (banner + disabled network actions).
4. **`npx expo-doctor`** passes locally and in **both** CI workflows (parent + submodule).
5. **Husky** hooks run on a clean clone after `npm install` (document in README).
6. **`scripts/ci-local.sh`** from monorepo root runs mobile lint/typecheck/tests without manual extra steps.
7. README explains the **product** (faces, auth, AI moderation context) and lists **no unimplemented feature** as shipped.

---

_End of prompt — keep unchecked `[ ]` boxes in this file per `docs/prompts/README.md` policy._
