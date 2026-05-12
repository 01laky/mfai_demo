# Many Faces Mobile — Phase 1 Foundation — Agent Prompt (Expo / React Native)

**Language:** All **new** prose you add to the codebase (README, guides, comments in new mobile files) must be **English**.

**Mission:** Turn the `many_faces_mobile` git submodule into a **production-grade skeleton** of the Many Faces user experience: **config-driven navigation and auth parity** with `many_faces_portal`, a **README in the same narrative style** as the portal (product story, AI-assisted workflows as context, security posture, engineering stack), **developer tooling** (ESLint, Prettier, TypeScript, optional Husky), **documented git/submodule workflow**, and **CI** in `many_faces_main`. Do **not** implement the full page grid / `gridSchema` renderer in phase 1 — only foundations, placeholders, and extension points.

**Canonical human guide:** after implementation, developers start from [`docs/guides/mobile-expo-development.md`](../guides/mobile-expo-development.md) (keep it accurate; update it whenever setup commands change).

---

## 1. Context — Why this submodule exists

The Many Faces monorepo (`many_faces_main`) is a multi-submodule demo of a **face-scoped social platform**: configurable “faces” (tenants), OAuth2/JWT auth, ASP.NET Core API (`many_faces_backend`), Redis-backed jobs, a Python gRPC AI service (`many_faces_ai`), and rich web SPAs (`many_faces_portal`, `many_faces_admin`). **User-created** albums, blogs, and reels can enter an **AI-assisted moderation pipeline** (pending approval, admin queue, creator “My submissions”) — see [`docs/guides/ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md).

The **mobile app** is the portable client for the **same product story**. Phase 1 does **not** ship every web module; it **does** establish the same **configuration contract** (`GET /api/faces/config`), the same **auth model** (password + refresh, `rememberMe` parity where applicable), and a **shell UI** that reflects the selected face’s branding (`gradientSettings`). Future phases add grid renderers, SignalR, “My submissions”, etc.

---

## 2. Hard scope boundaries

### 2.1 In scope (Phase 1)

- **Submodule hygiene:** `many_faces_mobile` remains a **separate git repo**; all tooling config lives inside it (`package.json`, `eslint.config.*`, `.prettierrc`, `.github/workflows/*.yml` if you add submodule-local CI in addition to parent CI).
- **README (portal style):** long-form overview: faces concept, auth, link to AI-assisted approval doc as **product context**, security notes, Expo/React Native stack, scripts table, local dev, testing, CI badge (if applicable), monorepo relationship.
- **Guide sync:** [`docs/guides/mobile-expo-development.md`](../guides/mobile-expo-development.md) — exact prerequisites, `nvm use`, `npm install`, `npm run start`, env var names, Expo Go notes, submodule bump workflow, links to portal files for parity.
- **API types:** TypeScript types aligned with `many_faces_portal/src/api/types/facesConfig.ts` (copy or thin shared module **inside** `many_faces_mobile` for phase 1 — do **not** introduce a new published npm package unless explicitly agreed).
- **`getFacesConfig` equivalent:** one module that performs `GET {baseUrl}/api/faces/config` with optional `Authorization: Bearer <accessToken>`.
- **React contexts:** `FaceConfigProvider` + `AuthProvider` (names may vary but responsibilities must mirror portal).
- **Navigation:** React Navigation (Expo Router is **optional**; prefer **explicit React Navigation** stack/tab for clarity unless the team already standardized on Router). Routes must be **data-driven** from config: build a list of navigable targets from `selectedFace.pages` (phase 1 can render **placeholder** screens for unknown `pageType.index`).
- **Screens (minimum):**
  - **Loading / error** while faces config loads.
  - **Login** — fields and semantics aligned with `many_faces_portal/src/pages/LoginPage.tsx` (email, password, stay signed in).
  - **Post-login home** — navigate to the page where `pageType.index === 'home'` for the selected face (same derivation as `getFaceHomePath()` in `FaceConfigContext.tsx`).
  - **App shell** — top bar: brand, face-aware gradient background, guest vs authenticated affordance (simplified vs web but recognisable).
- **Persistence:** `selectedFaceId` and tokens stored with **`expo-secure-store`** (access/refresh as appropriate); fall back policy documented if SecureStore unavailable on a platform.
- **i18n hook:** structure ready for `i18next` + JSON locales (English minimum); keys namespaced (`common`, `login`) mirroring portal where practical.
- **Lint + format + typecheck:** ESLint (flat config), Prettier, `tsc --noEmit`, `npm` scripts documented in README.
- **Unit tests:** Jest + `jest-expo` **or** Vitest if you prove Expo compatibility — pick **one** test runner, document it, add CI command.
- **Git workflow:** documented branch naming, commit message convention (match portal if commitlint added; otherwise Conventional Commits in README).
- **Parent monorepo CI:** add a **`many_faces_mobile`** job to `many_faces_main/.github/workflows/ci.yml` that checks out submodules recursively, runs `npm ci`, `npm run lint`, `npm run typecheck`, `npm test` inside `many_faces_mobile`.
- **Optional:** `many_faces_mobile/.env.example` with `EXPO_PUBLIC_API_BASE_URL` (or `app.config` `extra`) — **never** commit secrets.

### 2.2 Explicitly out of scope (later phases)

- Rendering **`gridSchema`** / `FacePageView` parity.
- SignalR / real-time chat, wall tickets, stories composer.
- **My submissions** list UI, moderation dashboards, admin flows.
- **Calling `many_faces_ai` gRPC directly from the phone** — mobile talks to **HTTP API** (`many_faces_backend`) only unless product later specifies otherwise.
- EAS Submit / store releases (document as future).

---

## 3. Product and README content (mirror `many_faces_portal/README.md` style)

The mobile `README.md` must be **long-form English** similar in spirit to:

`many_faces_portal/README.md` (Overview, “What This … Shows”, feature lists, security paragraph, engineering paragraph).

### 3.1 Required README sections (headings suggested)

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

- Implement `getFacesConfig(token?: string | null)` using `fetch` or `@react-native-community/netinfo`-aware client (start with `fetch`).
- Base URL from `process.env.EXPO_PUBLIC_API_BASE_URL` (document in README + `.env.example`).
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

- Study `many_faces_portal/src/contexts/AuthContext.tsx` and `many_faces_portal/src/hooks/api/useAuthApi.ts` (or equivalent) for exact endpoints and payload shape.
- Mobile must support: **login**, **logout**, **token refresh** on 401 if portal does automatic refresh (match or document deviation).
- Store **access** (and **refresh** if used) in SecureStore; clear on logout.
- `rememberMe`: honour the same API contract as the portal (`rememberMe` boolean on login) even if mobile only exposes a checkbox defaulting false.

### 4.4 Navigation mapping

- Build an in-memory structure from `selectedFace.pages`: `{ path, pageTypeIndex, isPublic }` deduplicated.
- **Phase 1 screen registry:** map `pageType.index` values you implement (`home`, `login`, `register` if present) to concrete screen components; unknown types → `PlaceholderScreen` showing `page.name` + `pageType.index` for debugging.
- **Auth gates:** unauthenticated users must not enter protected stack; mirror `GuestRoute` / `ProtectedRoute` semantics.

### 4.5 UI shell

- Parse `selectedFace.gradientSettings` (JSON string from API — same as web). If parse fails, use a **default** gradient matching Many Faces branding (document hex stops).
- Implement with `expo-linear-gradient`; animation is **optional** in phase 1 (if skipped, document as TODO).
- Header: logo (use existing Expo asset or add a simple wordmark), app name “The Many Faces”, right-side **Guest** / user email.
- **Footer (optional but recommended for FE parity):** a simple bottom bar or inset for static copy (e.g. copyright); keep it **safe-area** aware so it matches the web shell feel on tall phones.

### 4.6 Mobile UX primitives

- Wrap the app in **`react-native-safe-area-context`** so header, footer, and forms respect notches and home indicators.
- Use **`KeyboardAvoidingView`** (or a justified scroll helper) on **Login** so fields and the primary button stay visible on small devices.
- Primary actions: minimum touch target ~**44×44** pt; use `accessibilityRole` / `accessibilityLabel` on icon-only controls.

### 4.7 HTTP client layer (thin wrapper)

- Centralise **`fetch`** (or one axios instance) with: **timeout**, unified **JSON parse** errors, and **status → user-safe message** mapping (never show raw stack traces in UI).
- **401 policy:** match portal token **refresh** behaviour **or** document an intentional deviation (e.g. “logout and return to login”) with a TODO to align later.
- Keep all API calls under **`src/api/*`** — no ad-hoc `fetch` inside presentational screens.

### 4.8 Locales vs route translations

- The portal uses **translated URL segments** (`useLocalizedLink`, `routeTranslations`). Phase 1 mobile may ship **English-only UI strings** while still consuming the same API; document a **Phase 2** plan for mapping `routeTranslations` to navigator state without claiming full parity now.

---

## 5. Tooling — ESLint, Prettier, TypeScript

### 5.1 TypeScript

- `tsconfig.json`: `"strict": true` unless impossible; justify any relaxed flag in README.
- Path aliases **optional** (`@/api/...`); if added, configure `babel-plugin-module-resolver` or Expo’s preferred approach and ESLint import resolver.

### 5.2 ESLint (flat config)

- Use **flat config** (`eslint.config.js` or `eslint.config.mjs`) consistent with modern monorepo style.
- Include: `@eslint/js`, `typescript-eslint`, `eslint-plugin-react`, `eslint-plugin-react-hooks`, `eslint-plugin-react-native` / **`eslint-config-expo`** (preferred Expo integration).
- Rules: no `console.log` in production paths **or** allow with a `logger` wrapper — pick one and document.
- Add `npm run lint` and optional `npm run lint:fix`.

### 5.3 Prettier

- Add `.prettierrc` / `.prettierignore` aligned with portal conventions where sensible (single vs double quotes: **match portal** — check `many_faces_portal` Prettier config).
- Scripts: `format`, `format:check`.
- Ensure ESLint + Prettier do not fight (`eslint-config-prettier`).

### 5.4 Optional Husky + lint-staged

- If you add Husky, document **submodule-only** hooks (do not assume monorepo root Husky). Provide `npm run prepare` cautiously (Expo + husky can annoy contributors) — either implement fully or omit; if omitted, state in README that CI is the enforcement gate.

### 5.5 EditorConfig

- Add `.editorconfig` (indent, charset, final newline) consistent with other submodules.

---

## 6. Gitflow, branching, and submodule discipline

### 6.1 Branch naming (document in README)

Suggested:

- `main` — always releasable; protected if repo settings allow.
- `feature/<ticket>-short-slug` — features.
- `fix/<ticket>-short-slug` — bugfixes.
- `chore/<short-slug>` — tooling.

### 6.2 Submodule two-step

1. Push commits to `many_faces_mobile` remote.
2. In `many_faces_main`, commit the updated **gitlink** + any monorepo workflow changes (e.g. `ci.yml`).

### 6.3 Conventional Commits

- Prefer `feat:`, `fix:`, `chore:`, `docs:`, `test:` prefixes.
- If you add **commitlint** to the mobile repo, mirror `many_faces_portal` / `many_faces_admin` config patterns; otherwise document “soft convention” only.

### 6.4 PR strategy

- Prefer **small PRs** in the mobile repo; parent repo PR only bumps submodule + CI/docs.

---

## 7. CI — `many_faces_main` GitHub Actions

### 7.1 New job: `many_faces_mobile`

Add to `.github/workflows/ci.yml` (same workflow file other jobs use):

- `runs-on: ubuntu-latest`
- `actions/checkout@v4` with `submodules: recursive`
- `actions/setup-node@v4` with `node-version-file: many_faces_mobile/.nvmrc`
- **Caching:** `cache: npm`, `cache-dependency-path: many_faces_mobile/package-lock.json`
- Steps (names illustrative):
  1. `cd many_faces_mobile && npm ci`
  2. `npm run lint`
  3. `npm run typecheck` (must exist — wraps `tsc --noEmit`)
  4. `npm test` (non-interactive; no watch mode)

### 7.2 Optional: duplicate workflow inside `many_faces_mobile/.github/workflows/ci.yml`

- Useful if the mobile repo is ever checked out **standalone**; not required if parent CI is sufficient — choose one or both and document.

### 7.3 `scripts/ci-local.sh` (monorepo)

- Extend `scripts/ci-local.sh`, `scripts/lint-all.sh`, `scripts/test-all.sh` **if** the monorepo policy is “one button runs all submodules”. If adding, guard with `if [ -d many_faces_mobile ]; then … fi` and document in `docs/guides/development.md` in a short subsection (update that guide minimally — one paragraph + link to `mobile-expo-development.md`).

---

## 8. Testing strategy

- **Unit tests** for pure functions: path builders, `getFaceHomePath` clone, token storage wrapper (mock SecureStore).
- **Context tests:** `@testing-library/react-native` for login form validation messages (if using `react-hook-form` + `yup` like portal — optional; simpler manual validation acceptable if tested).
- **No flaky network in unit tests:** mock `fetch`.
- **Snapshot tests:** use sparingly; prefer explicit assertions.

### 8.1 Optional CI extras (document choice in README)

- **`npx expo-doctor`** — run in CI as **blocking** once the repo is stable, or **informational** during bootstrap; state which.
- **`npm audit`** — run like portal jobs: **informational** (`|| true`) and keep logs for supply-chain triage.

### 8.2 Connectivity (optional Phase 1)

- **`@react-native-community/netinfo`:** optional **offline banner** or disabled actions with copy when offline. If skipped, state **online-only** in README.

---

## 9. Security checklist (embed reasoning in README + code)

- HTTPS base URL in production builds.
- No tokens in AsyncStorage unless justified; prefer SecureStore.
- Log redaction: never log full tokens.
- **iOS ATS / cleartext:** document that **HTTP** dev URLs (e.g. `http://127.0.0.1:8000`) require **`NSAppTransportSecurity`** exceptions in dev client builds or use **HTTPS** / tunnel; production must stay HTTPS.
- **Android cleartext:** if HTTP is used in dev only, document `usesCleartextTraffic` / network security config scope (dev vs release).
- Certificate pinning: **out of scope** phase 1 — mention as future hardening.

---

## 10. Deliverables checklist (tick in PR / issue — keep `[ ]` in canonical prompt file)

Copy this section into your PR description and tick items there; **do not** mass-replace `[ ]` with `[x]` in this canonical prompt unless the engagement is fully complete per repo policy.

### 10.1 Documentation

- [ ] `many_faces_mobile/README.md` — full portal-style narrative (§3.1).
- [ ] `docs/guides/mobile-expo-development.md` — updated with **exact** commands and env vars after implementation (baseline may already exist — **verify** accuracy after code lands).
- [ ] `docs/README.md` — ensure guides table links **`mobile-expo-development.md`** (add row if missing).
- [ ] `docs/prompts/README.md` — ensure this prompt is indexed (add row if missing).
- [ ] `README.md` (monorepo root) — optional one-line mention of **`many_faces_mobile/`** in layout / architecture if not already present.

### 10.2 Application code (Phase 1)

- [ ] `getFacesConfig` + shared TS types for `FaceConfig` / `PageConfig`.
- [ ] `FaceConfigProvider` + `useFaceConfig()` hook.
- [ ] `AuthProvider` + `useAuth()` hook (login/logout/refresh semantics documented).
- [ ] React Navigation root + authenticated stack + guest stack.
- [ ] Screens: `SplashOrLoading`, `ConfigError`, `Login`, `HomePlaceholder` (wired to config), `PlaceholderPage`.
- [ ] **(Optional parity)** `Register` screen if `pageType` / path exposes register in config — mirror `many_faces_portal/src/pages/RegisterPage.tsx` at high level or document deferral.
- [ ] App shell with gradient + brand + guest/user chip.
- [ ] **Root `React` error boundary** (or Expo `ErrorBoundary` pattern): catch render errors, show fallback UI, log without leaking tokens.
- [ ] **Accessibility:** form labels linked to inputs, login error text exposed to screen readers, sufficient contrast on gradient + buttons.
- [ ] `.env.example` + `app.config` / `extra` wiring for `EXPO_PUBLIC_API_BASE_URL`.

### 10.3 Tooling

- [ ] ESLint flat config + `npm run lint` / `lint:fix`.
- [ ] Prettier + `npm run format` / `format:check` + `.prettierignore`.
- [ ] `npm run typecheck` (`tsc --noEmit`).
- [ ] `.editorconfig`.
- [ ] Unit test runner configured + `npm test` in CI mode (no watch).

### 10.4 CI / monorepo

- [ ] `.github/workflows/ci.yml` includes `many_faces_mobile` job (`npm ci`, lint, typecheck, test).
- [ ] (Optional) **`expo-doctor`** + informational **`npm audit`** in that job (see §8.1).
- [ ] (Optional) `many_faces_mobile` standalone GitHub workflow.
- [ ] (Optional) `scripts/ci-local.sh` (+ lint-all / test-all) extended to include mobile with clear echo banners.

### 10.5 Git discipline

- [ ] README subsection: branch naming, submodule bump instructions, conventional commits.
- [ ] At least one example PR sequence described (“feature branch in submodule → merge → bump pointer in main”).

### 10.6 Verification (run locally before merge)

- [ ] `cd many_faces_mobile && npm ci && npm run lint && npm run typecheck && npm test`
- [ ] `npx expo start` launches; login screen reachable; config loads against a running `many_faces_backend` dev instance (document manual prerequisite).
- [ ] No secrets committed (`git grep -i password` / `.env` absent from index).

---

## 11. Hints — portal files to diff while implementing

- `many_faces_portal/src/contexts/FaceConfigContext.tsx`
- `many_faces_portal/src/contexts/AuthContext.tsx`
- `many_faces_portal/src/pages/LoginPage.tsx`
- `many_faces_portal/src/api/config/getFacesConfig.ts`
- `many_faces_portal/src/api/types/facesConfig.ts`
- `many_faces_portal/src/routes/useFaceRouteEntries.ts`
- `many_faces_portal/src/routes/facePagePaths.ts` (path expansion / translations)
- `many_faces_portal/src/pages/RegisterPage.tsx` (if adding register parity)
- `many_faces_portal/src/utils/jwtUtils.ts` (client-side `exp` / expiry helpers, if mirroring refresh UX)
- `many_faces_portal/src/components/Header.tsx` (shell inspiration only)

---

## 12. Success criteria (Phase 1 complete when)

1. A new contributor can follow **`docs/guides/mobile-expo-development.md`** and reach the **Login** screen with **faces config loaded** without reading source.
2. Successful login navigates to the configured **home** route for the selected face.
3. **CI passes** on GitHub for the new `many_faces_mobile` workflow job.
4. README explains the **product** (faces, auth, AI moderation context) even though moderation UI is not built yet.

---

_End of prompt — keep unchecked `[ ]` boxes in this file per `docs/prompts/README.md` policy._
