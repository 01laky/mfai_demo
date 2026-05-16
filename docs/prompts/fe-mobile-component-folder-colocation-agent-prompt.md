# `many_faces_mobile` — component folder colocation (agent prompt)

**Language:** All **new** prose you add to repositories (README, guides, comments in new code, PR description) must be **English**.

**Mission (two tracks in one spec):**

1. **Track A — Folder colocation (required):** Refactor **`many_faces_mobile`** so UI building blocks are **not flat piles of files** under `src/components/`, `src/screens/`, `src/theme/`, and `src/grid/`. Each **component**, **screen**, **theme module**, and **grid layout** lives in its **own directory** with its **`.tsx`**, **colocated styles** (inline `StyleSheet` or optional `*.styles.ts`), and any **component-private** helpers beside it. **Behavior, navigation routes, API contracts, deep links, and i18n keys stay unchanged** in colocation PRs — structure only.

2. **Track B — Post-colocation mobile update roadmap (§23–§27):** After Track A (or in explicitly scoped follow-up PRs), implement the **product / DX** slices documented below (grid block registry, `features/`, `yarn validate`, My Submissions detail, shell i18n + motion). Track B items are **not** part of a pure `git mv` colocation PR unless the PR description says so.

**You are implementing what the product owner asked for:**

> Components and screens will not sit in one heap; each TSX and the styles (and scripts that belong only to that UI unit) live together in folders.

**(required)** Read **§1** (as-is) and **§2** (target layout) before moving files; read **§23** (rollout order) so parity work does not recreate flat files; complete **§13** (master checklist) and **§16** (implementing-agent phases) for Track A; apply **§6–§9** (namespaces), **§18–§21** (large screens, tests, guards, DX); for Track B use **§24–§27** in separate PRs; update **§12** documentation; obey the [**engagement exit rule**](#agent-engagement-exit-rule) for the **agreed track** (A only, or A + named §27 slices).

> **Status (2026-05-16):** Track A and the Track B slices in **§27** are **implemented** on `many_faces_mobile` `main`. **Settings shell:** `SettingsSidePanel` + **`LanguageSwitcher`** (`en`/`sk`/`cz`, `i18nextLng`) — see **§24.6** (`[x]`). Full portal settings tabs remain **parity prompt** scope. **§1** (“Today”) and parts of **§24–§25** describe the **pre-rollout inventory** — for current layout use [`many_faces_mobile/README.md`](../../many_faces_mobile/README.md), [`src/components/README.md`](../../many_faces_mobile/src/components/README.md), [`docs/rest-parity-matrix.md`](../../many_faces_mobile/docs/rest-parity-matrix.md), and [`.cursor/rules/mobile-component-folders.mdc`](../../.cursor/rules/mobile-component-folders.mdc).

**Precedent (web SPAs — portal rolled out, admin spec ready):**

- [fe-portal-component-folder-colocation-agent-prompt.md](./fe-portal-component-folder-colocation-agent-prompt.md) — colocation phases, `git mv`, verify script, CI guard patterns (**delivered** on portal).
- [fe-admin-component-folder-colocation-agent-prompt.md](./fe-admin-component-folder-colocation-agent-prompt.md) — same product intent; **reuse** monorepo script ideas (`colocate-portal-component.mjs`, `verify-portal-component-colocation.mjs`) and add mobile-specific helpers (`colocate-mobile-component.mjs`, `verify-mobile-component-colocation.mjs`).

**Related (do not duplicate scope unless PR explicitly combines):**

- [mobile-phase1-foundation-agent-prompt.md](./mobile-phase1-foundation-agent-prompt.md) — Expo foundation (already delivered); colocation is **orthogonal**.
- [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md) — full portal parity (**behavior**); **§23** mandates colocation (Track A) before large parity PRs; **§25–§27** spell out the highest-priority parity slices to schedule next.
- [push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md](./push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md) — push plumbing; colocation may touch `Push*Effect` folders only as moves.
- [unit-test-gap-fill-agent-prompt.md](./unit-test-gap-fill-agent-prompt.md) — add tests **after** folders exist if gaps remain.

**Non-goals:**

- **`many_faces_portal`**, **`many_faces_admin`**, **`many_faces_backend`** (mobile only unless product expands scope).
- Rewriting business logic, OAuth/session, or hand-maintained API modules under `src/api/**`.
- Renaming user-visible copy or i18n keys “for cleanliness”.
- Introducing **Expo Router** or replacing **React Navigation** stack setup.
- Mandatory barrel files at every ancestor level (only **per-unit** `index.ts` where it helps imports).
- Moving **shared** hooks from `src/hooks/api/` into screen folders when **two or more** screens use them.
- **`src/components/grid/`** in the portal sense — **N/A** (portal grid blocks); mobile has a **small read-only** `src/grid/` engine only.
- Converting inline `StyleSheet.create` to a new styling library (NativeWind, Tamagui, etc.).
- Metro bundle optimization as a **required** deliverable (optional spot-check only — §21).

**In scope (this prompt — structure only):**

- Namespace **`wall-tickets/`** for wall list UI used by `FacePageScreen` / grid (§7).
- **`theme/`** colocation (§6).
- **`grid/`** colocation + optional private sub-components inside `MobilePageLayout/` (§8, §18).
- **`screens/`** colocation (§5).
- Shell + passive **effects** under `src/components/` (§9).
- **Colocated Jest** files (§19) + **final test sweep** (§19.2).
- **Large-screen file splits** into private siblings inside the screen folder (§18).
- **ESLint import boundaries** + verify `--imports` (§20, §17.2).
- **Documentation / local DX** (§21).
- **Rollout order** vs parity (§23), future **`src/features/`** (§24), **grid `blocks/`** conventions (§25), **`yarn validate` + Jest** (§26), **post-colocation product slices** (§27).

---

## 0. Compliance — read every part (**required**)

### 0.1 Labels

| Label                           | Meaning                                                                   |
| ------------------------------- | ------------------------------------------------------------------------- |
| **(required)**                  | Must be satisfied before merge, or explicitly deferred in PR with reason. |
| **(required — if _condition_)** | Mandatory when _condition_ is true.                                       |
| **(optional)**                  | Skip only with written deferral in PR.                                    |

### 0.2 Section coverage (**required** — copy into PR)

| §       | Topic                                         | Status (✓ / N/A) | If N/A, reason |
| ------- | --------------------------------------------- | ---------------- | -------------- |
| **§1**  | As-is audit                                   |                  |                |
| **§2**  | Target folder layout                          |                  |                |
| **§3**  | What belongs inside a UI folder               |                  |                |
| **§4**  | Import / export rules                         |                  |                |
| **§5**  | `screens/`, `navigation/`                     |                  |                |
| **§6**  | `theme/`                                      |                  |                |
| **§7**  | `wall-tickets/` namespace                     |                  |                |
| **§8**  | `grid/`                                       |                  |                |
| **§9**  | Shell + effects                               |                  |                |
| **§10** | Phased delivery / PR split                    |                  |                |
| **§11** | Verification                                  |                  |                |
| **§12** | Documentation                                 |                  |                |
| **§13** | Master checklist (summary)                    |                  |                |
| **§14** | Before / after examples                       |                  |                |
| **§15** | Engagement exit rule                          |                  |                |
| **§16** | Implementing-agent task list                  |                  |                |
| **§17** | Tooling, CI, conventions                      |                  |                |
| **§18** | Large screens / grid — private sub-components |                  |                |
| **§19** | Colocated tests + final sweep                 |                  |                |
| **§20** | Import boundaries (ESLint)                    |                  |                |
| **§21** | DX — README, local verify, CI                 |                  |                |
| **§23** | Rollout sequencing (colocation vs parity)     |                  |                |
| **§24** | Future `src/features/` namespace              |                  |                |
| **§25** | Grid `blocks/` registry + parity matrix       |                  |                |
| **§26** | `yarn validate` + committed Jest config       |                  |                |
| **§27** | Post-colocation product slices                |                  |                |
| **§28** | Explicit non-goals (summary)                  |                  |                |

---

## 1. As-is audit — what exists today (**required**)

Re-run counts when starting work:

```bash
find many_faces_mobile/src/components -maxdepth 1 -name '*.tsx' | wc -l
find many_faces_mobile/src/screens -maxdepth 1 -name '*.tsx' | wc -l
find many_faces_mobile/src/grid -maxdepth 1 -name '*.tsx' | wc -l
find many_faces_mobile/src/theme -maxdepth 1 -name '*.tsx' | wc -l
```

| Area                                | Path                                                   | Today (snapshot)                                                | Problem                                                                                                       |
| ----------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Flat shell / feature components** | `src/components/*.tsx`                                 | **9** TSX at `components/` root                                 | Hard to see ownership; large files (`AppShell`, `ShellDrawer`) mixed with tiny effects                        |
| **Screens**                         | `src/screens/*.tsx`                                    | **12** flat screen TSX                                          | Same issue; auth screens ~200 LOC with inline `StyleSheet`                                                    |
| **Grid engine**                     | `src/grid/MobilePageLayout.tsx` + helpers              | **1** layout TSX + `parseGridSchema.ts` at `grid/` root         | `BlockChrome` / `GridBlockBody` inline; **no** `grid/blocks/` yet — placeholders for most `KNOWN_TYPES` (§25) |
| **Grid block parity**               | `parseGridSchema` `KNOWN_TYPES` vs layout              | **1** real family (`ad*`) + i18n placeholder                    | **§25** registry + matrix; portal has full `components/grid/*`                                                |
| **Theme**                           | `src/theme/*.tsx` + `gradientSettings.ts`              | `AnimatedShellGradient.tsx` + pure TS settings                  | Group exists but not per-module folders                                                                       |
| **Wall tickets cluster**            | `WallTicketsSection.tsx`, `WallTicketsAdGridBlock.tsx` | Flat in `components/`                                           | Only consumed by face page + grid — should be namespaced together                                             |
| **Navigation glue**                 | `src/navigation/RootNavigator.tsx`                     | Imports all screens; inline `AuthReconnectNavigatorEffect`      | Update import paths when screens move; optional effect colocation §5.3                                        |
| **App entry**                       | `src/App.tsx`, `src/Bootstrap.tsx`                     | Provider tree + i18n gate (`Bootstrap` → `App`)                 | Update imports only; **do not** colocate or move into `screens/` / `components/`                              |
| **Contexts / API / hooks**          | `src/contexts/*`, `src/api/*`, `src/hooks/api/*`       | Shared layers                                                   | **Keep** flat at layer root                                                                                   |
| **Tests**                           | `src/screens/__tests__/*`                              | Centralized (`LoginScreen.test.tsx`, `RegisterScreen.test.tsx`) | **Colocate** in Phase 4 per §19                                                                               |
| **Imports**                         | Whole repo                                             | **`@/`** alias (`tsconfig` + `babel-plugin-module-resolver`)    | Prefer **`@/screens/LoginScreen`** style **unchanged** after `index.ts` barrels                               |
| **Styling**                         | All UI TSX                                             | **`StyleSheet.create` at bottom of file** (no `.scss`)          | Colocate styles **in the same folder** — see §2.2                                                             |

**Inventory — `src/components/` (flat today):**

`AppShell`, `ShellDrawer`, `MainLogo`, `ErrorFallback`, `MeCapabilitiesBootstrap`, `PushTokenRegistrationEffect`, `PushNotificationResponseEffect`, `WallTicketsSection`, `WallTicketsAdGridBlock`.

**Inventory — move to `src/components/wall-tickets/` in Phase 2b (§7):**

`WallTicketsSection`, `WallTicketsAdGridBlock`.

**Inventory — `src/screens/`:**

`SplashOrLoadingScreen`, `ConfigErrorScreen`, `HomePlaceholderScreen`, `LoginScreen`, `RegisterScreen`, `RegisterCompleteScreen`, `PlaceholderScreen`, `FacePageScreen`, `MySubmissionsScreen`, `ProfileMePlaceholderScreen`, `ChatAiPlaceholderScreen`, `ChatRoomPlaceholderScreen`.

**Inventory — `src/grid/`:**

`MobilePageLayout.tsx`, `parseGridSchema.ts`, `gridTypes.ts` (types stay at namespace root or under `MobilePageLayout/` per §8).

**Inventory — `src/theme/`:**

`AnimatedShellGradient.tsx`, `gradientSettings.ts`.

**Positive patterns to preserve:**

- **`@/` imports** — keep consumer paths stable via per-folder `index.ts` (e.g. `@/screens/LoginScreen` resolves to `screens/LoginScreen/index.ts`).
- **`src/grid/` namespace** — keep; do not flatten into `components/` (mirrors portal’s separation of grid engine from chrome).
- **Pure modules** (`parseGridSchema.ts`, `gradientSettings.ts`) may stay at namespace root **or** move beside their primary consumer — document choice in PR (§8.1).

**Large UI files — line-count audit (re-run `wc -l`; split in Phase 4 §18):**

| File                         | ~lines (snapshot) | Split guidance                                                     |
| ---------------------------- | ----------------- | ------------------------------------------------------------------ |
| `ShellDrawer.tsx`            | ~339              | §18.1 — drawer sections / menu rows as private siblings            |
| `AppShell.tsx`               | ~297              | §18.1 — header / footer / offline banner as private siblings       |
| `LoginScreen.tsx`            | ~207              | §18.2 — optional `LoginForm.tsx` + `loginSchema.ts` (page-private) |
| `RegisterCompleteScreen.tsx` | ~207              | §18.2 — same pattern if touching file                              |
| `RegisterScreen.tsx`         | ~166              | §18.2 — optional                                                   |
| `HomePlaceholderScreen.tsx`  | ~143              | §18.2 — optional                                                   |
| `MobilePageLayout.tsx`       | ~141              | §18.3 — extract `BlockChrome`, `GridBlockBody` (already inline)    |
| `WallTicketsSection.tsx`     | ~139              | Optional §18.4 when in `wall-tickets/`                             |

**Audit tasks (start of engagement):**

- [ ] Paste updated file counts into PR.
- [ ] Paste `wc -l` for §18 large files into PR.
- [ ] Export importer list: `rg "from '@/(components|screens|grid|theme)" many_faces_mobile/src -l | sort -u`.
- [ ] Document **wall-tickets** importers (`FacePageScreen`, `MobilePageLayout`) before Phase 2b.
- [ ] Confirm `RootNavigator.tsx` screen list matches §1 inventory.
- [ ] Confirm `App.tsx` linking config still resolves `RegisterComplete` after screen moves.
- [ ] List tests under `src/screens/__tests__/` to colocate in Phase 4 (§19).
- [ ] Note Jest uses **`jest-expo`** (no committed `jest.config.cjs` today) and `babel.config.js` **`module-resolver`** maps `@/*` → `src/*` — colocated tests must still resolve `@/`.

---

## 2. Target folder layout (**required**)

### 2.1 Canonical shape (one UI unit = one folder)

**Default name:** PascalCase folder name **matches** the primary React component (same as today’s file basename).

```
src/screens/LoginScreen/
  LoginScreen.tsx
  index.ts                  # export { LoginScreen } from './LoginScreen'
  LoginScreen.test.tsx      # (optional) moved from screens/__tests__
  loginSchema.ts            # (optional) yup schema — only if extracted §18
  LoginForm.tsx             # (optional) private sub-view §18
```

**Import after migration (preferred — unchanged path shape):**

```ts
import { LoginScreen } from "@/screens/LoginScreen";
```

**Forbidden after migration:**

```
src/screens/LoginScreen.tsx    # flat screen file at screens/ root — remove
```

### 2.2 Styles on React Native (**required**)

Mobile has **no SCSS**. When colocating:

| Pattern                                           | When to use                                                                                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Inline `StyleSheet.create` in `Component.tsx`** | Default — keep at bottom of same file after move (no behavior change).                                                               |
| **`Component.styles.ts`**                         | **(optional)** When a file exceeds ~250 LOC **and** styles are large — export `styles` from sibling file; import in `Component.tsx`. |
| **Shared theme tokens**                           | Stay in `src/theme/gradientSettings.ts` (or `theme/gradientSettings/`) — not duplicated per screen.                                  |

**Do not** introduce global StyleSheet registries or change color/spacing values during this rollout.

### 2.3 Barrel `index.ts` rules

| Rule                           | Detail                                                                             |
| ------------------------------ | ---------------------------------------------------------------------------------- |
| **Per-folder `index.ts`**      | `export { LoginScreen } from './LoginScreen'` (match existing named export style)  |
| **Public API only**            | **`index.ts` exports only what other folders may import**                          |
| **No deep import requirement** | Consumers use `@/screens/LoginScreen`, not `@/screens/LoginScreen/LoginScreen.tsx` |
| **Avoid mega-barrels**         | Do **not** add `screens/index.ts` re-exporting the whole app                       |

### 2.4 `wall-tickets/` namespace (**required** — Phase 2b)

Keep a **namespace folder**; colocate each widget inside it (portal/admin pattern for feature clusters).

```
src/components/wall-tickets/
  WallTicketsSection/
    WallTicketsSection.tsx
    index.ts
  WallTicketsAdGridBlock/
    WallTicketsAdGridBlock.tsx
    index.ts
```

**Public import (after migration):**

```ts
import { WallTicketsSection } from "@/components/wall-tickets/WallTicketsSection";
```

**Re-export note:** `WallTicketsSection` today re-exports `wallTicketsQueryKeys` from `@/hooks/api/useWallTicketsListQuery` — **keep** that re-export from the colocated folder’s `index.ts` or main file; do not move the hook.

**Verify:** `find many_faces_mobile/src/components/wall-tickets -maxdepth 1 -name '*.tsx' | wc -l` → **0** after Phase 2b.

### 2.5 `theme/` (**required** — Phase 1)

```
src/theme/AnimatedShellGradient/
  AnimatedShellGradient.tsx
  index.ts
src/theme/gradientSettings.ts    # pure TS — may stay at theme/ root (§8.1)
```

### 2.6 `grid/` (**required** — Phase 3)

```
src/grid/MobilePageLayout/
  MobilePageLayout.tsx
  BlockChrome.tsx           # (optional) extracted §18.3 — not in index.ts
  GridBlockBody.tsx
  index.ts                  # export { MobilePageLayout } only
src/grid/parseGridSchema.ts
src/grid/gridTypes.ts
```

### 2.7 Passive **effects** (Phase 2)

Tiny mount-only components stay under `src/components/` as folders:

```
src/components/PushTokenRegistrationEffect/
  PushTokenRegistrationEffect.tsx
  index.ts
```

Same for `MeCapabilitiesBootstrap`, `PushNotificationResponseEffect`.

### 2.8 Grid `blocks/` **(required when implementing grid parity — §25)**

After Track A colocates `MobilePageLayout/`, new block UIs go under **`src/grid/blocks/<BlockName>/`**, not flat files under `grid/` or `components/`. See **§25** for registry and parity matrix.

### 2.9 Future `features/` **(required when implementing parity modules — §24)**

Cross-cutting modules (settings panel, messenger) use **`src/features/<area>/<Component>/`** — not flat files under `features/` or new flat `components/*.tsx`.

---

## 3. What belongs inside a UI folder (**required**)

| Belongs in folder                                               | Stays outside folder                                                        |
| --------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Primary `.tsx` + optional `*.styles.ts`                         | `src/api/**`, `src/contexts/**`, `src/hooks/api/**`                         |
| Props/types used only there (`*.types.ts`)                      | `src/utils/**` shared by multiple features                                  |
| Page-private hooks (`useFacePageHeader.ts`)                     | `src/navigation/types.ts`, `navigationRef.ts`                               |
| Private sub-components (§18) — **not** exported from `index.ts` | `src/acl/**`, `src/realtime/**`, `src/config/**`                            |
| Colocated `*.test.tsx` (§19)                                    | Central `src/**/__tests__` for **api** / **utils** unless already colocated |

**Never** move `httpClient.ts`, `authSession.ts`, or OpenAPI-shaped clients into a screen folder.

---

## 4. Import / export rules (**required**)

1. **Prefer `git mv`** for TSX/TS pairs so history is preserved.
2. **Update all importers** in the **same PR** as the move (grep `rg` before/after).
3. **Keep `@/`** — do not mass-convert to deep relative paths unless a file **inside** the same folder imports a sibling (`./LoginForm`).
4. **`index.ts` exports** — only the public component(s); query-key re-exports documented in §7.
5. **No circular imports** — if `AppShell` imports `ShellDrawer`, use folder barrels; avoid `AppShell` ↔ `ShellDrawer` mutual `index.ts` re-export loops.
6. After bulk moves, run **`node scripts/fix-mobile-colocated-imports.mjs`** if added (§17.7) — optional helper for relative path depth inside moved trees.

---

## 5. `screens/` and `navigation/` (**required**)

### 5.1 Screens

Every routable screen under `src/screens/<ScreenName>/` per §2.1.

**Importer hotspots:** `src/navigation/RootNavigator.tsx`, `src/App.tsx` (linking only references route names — usually **no** screen path change if barrels keep `@/screens/...`).

### 5.2 Do not colocate navigation wiring

| Keep at `src/navigation/` root | Reason                |
| ------------------------------ | --------------------- |
| `RootNavigator.tsx`            | Stack definitions     |
| `types.ts`                     | `AppStackParamList`   |
| `navigationRef.ts`             | Imperative navigation |

### 5.3 `AuthReconnectNavigatorEffect` **(optional)**

Today defined **inside** `RootNavigator.tsx`. **Optional** Phase 2c:

```
src/navigation/effects/AuthReconnectNavigatorEffect/
  AuthReconnectNavigatorEffect.tsx
  index.ts
```

Skip with §0.2 **N/A** if team prefers a single navigator file.

---

## 6. `theme/` subsystem (**required** — Phase 1)

- [ ] `AnimatedShellGradient/` colocated.
- [ ] `gradientSettings.ts` stays importable as `@/theme/gradientSettings` (root of `theme/` is OK).
- [ ] `AppShell` / shell imports updated.
- [ ] No visual change to gradient animation (smoke: cold start + login).

---

## 7. `wall-tickets/` namespace (**required** — Phase 2b)

- [ ] Both wall components under `src/components/wall-tickets/`.
- [ ] `FacePageScreen` and `MobilePageLayout` imports updated.
- [ ] No flat `WallTickets*.tsx` left at `components/` root.
- [ ] Hooks remain in `src/hooks/api/useWallTicketsListQuery.ts`.

---

## 8. `grid/` subsystem (**required** — Phase 3)

### 8.1 Pure modules at `grid/` / `theme/` root (**required — document in PR**)

`parseGridSchema.ts`, `gridTypes.ts`, and `gradientSettings.ts` are **not** React components. **Default:** leave them at the namespace root (`src/grid/`, `src/theme/`) so tests (`src/grid/__tests__/parseGridSchema.test.ts`) and multiple importers stay stable. **Optional:** move only when a single consumer owns the module and tests move in the same PR.

- [ ] `MobilePageLayout/` folder; `parseGridSchema.ts` / `gridTypes.ts` at `grid/` root **or** documented move per §8.1.
- [ ] §18.3 private splits optional in same PR.
- [ ] `FacePageScreen` import: `@/grid/MobilePageLayout`.
- [ ] Tests in `src/grid/__tests__/parseGridSchema.test.ts` — **keep** at `grid/__tests__` (pure parser, not a component).

---

## 9. Shell + effects (**required** — Phase 2)

**Shell (larger UI):**

`AppShell/`, `ShellDrawer/`, `MainLogo/`, `ErrorFallback/`.

**Effects (passive):**

`MeCapabilitiesBootstrap/`, `PushTokenRegistrationEffect/`, `PushNotificationResponseEffect/`.

- [ ] `App.tsx` imports updated.
- [ ] After Phase 2: `find src/components -maxdepth 1 -name '*.tsx' | wc -l` → **2** (`WallTicketsSection`, `WallTicketsAdGridBlock` still flat until Phase 2b).
- [ ] After Phase 2b: same command → **0** at `components/` root.

---

## 10. Phased delivery / PR split (**required**)

Prefer **reviewable PRs**; mobile tree is **small** — product owner may approve **2–3 PRs** instead of six.

| Phase     | Scope                                                                     | Suggested PR title                                                   |
| --------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **0.5**   | Monorepo helper scripts + verify `--imports` + optional ESLint stub — §17 | `chore(mobile): colocation helper scripts`                           |
| **1**     | `src/theme/*` §6                                                          | `refactor(mobile): colocate theme modules`                           |
| **2**     | Shell + effects §9                                                        | `refactor(mobile): colocate shell and effects`                       |
| **2b**    | `src/components/wall-tickets/*` §7                                        | `refactor(mobile): colocate wall-tickets components`                 |
| **3**     | `src/grid/MobilePageLayout` §8                                            | `refactor(mobile): colocate grid layout`                             |
| **4**     | `src/screens/*` + colocate screen tests §19 + optional §18 splits         | `refactor(mobile): colocate screens`                                 |
| **2c**    | (optional) `navigation/effects/*` §5.3                                    | `refactor(mobile): colocate navigator effects`                       |
| **Final** | ESLint §20, CI verify §17.3, **`yarn validate`** §26, docs §12            | `chore(mobile): colocation guards and docs` (may merge with Phase 4) |

**After Track A (colocation) — Track B scheduling (§23):**

| Slice                                       | Prompt §   | Suggested order                     |
| ------------------------------------------- | ---------- | ----------------------------------- |
| `yarn validate` + Jest config               | §26        | With **Final** or first small DX PR |
| Shell i18n + reduced motion                 | §27.3      | Early polish (low risk)             |
| My Submissions detail                       | §27.2      | First full user journey             |
| Grid `blocks/` registry + first real blocks | §25, §27.1 | Parallel with parity prompt         |
| `src/features/settings` (when product asks) | §24        | With settings parity slice          |

Each PR must pass **§11** for its phase (use **`yarn validate`** once §26 is merged).

**Commit hygiene:** structure-only; prefer **`git mv`**.

**Importer hotspots** (re-grep every phase): `src/App.tsx`, `src/navigation/RootNavigator.tsx`, `src/screens/**`, `src/components/**`, `src/grid/**`, `src/theme/**`.

**Dev note:** After moves, `yarn start:clear` if Metro caches stale paths.

---

## 11. Verification (**required**)

- [ ] `cd many_faces_mobile && yarn install --immutable`
- [ ] **`yarn validate`** (§26) when merged — else run `yarn typecheck`, `yarn lint`, `yarn format:check`, `yarn test` individually.
- [ ] After each phase when imports change; **full suite** before engagement exit (§19.2).
- [ ] **Grep guard** (from repo root or `many_faces_mobile/`):

```bash
# Run from many_faces_mobile/ — expectations depend on phase (see §9, §16)
find src/components -maxdepth 1 -name '*.tsx' | wc -l
#   after Phase 2  → 2 (wall tickets still flat)
#   after Phase 2b → 0
find src/components/wall-tickets -maxdepth 1 -name '*.tsx' 2>/dev/null | wc -l
#   after Phase 2b → 0
find src/screens -maxdepth 1 -name '*.tsx' | wc -l
#   after Phase 4  → 0
find src/grid -maxdepth 1 -name 'MobilePageLayout.tsx' | wc -l
#   after Phase 3  → 0
find src/theme -maxdepth 1 -name 'AnimatedShellGradient.tsx' | wc -l
#   after Phase 1  → 0
```

- [ ] `node scripts/verify-mobile-component-colocation.mjs` (and `--imports` on final branch) — §17.2.
- [ ] Manual smoke (Expo): cold start → config load → **guest** login → **Home** → open **FacePage** from config → wall page shows tickets section → **My submissions** (auth) → logout → optional register deep link `manyfaces://register/complete?hash=…` if env configured.

---

## 12. Documentation (**required**)

| Document                                                                       | Content                                                                     |
| ------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `many_faces_mobile/README.md`                                                  | Update project tree; link to `src/components/README.md` if created          |
| `many_faces_mobile/src/components/README.md`                                   | Conventions §2.1–§2.9, `wall-tickets/`; link §23–§27; verify command        |
| [docs/guides/mobile-expo-development.md](../guides/mobile-expo-development.md) | Colocation verify command; link to §23–§27 roadmap                          |
| `many_faces_mobile/docs/rest-parity-matrix.md`                                 | REST + **grid block** columns per §25.3                                     |
| `many_faces_mobile/README.md`                                                  | **Route ↔ portal URL** table per §27.4 when shipping Track B routes         |
| [docs/prompts/README.md](./README.md)                                          | Row in prompt table (maintainer)                                            |
| `.cursor/rules/mobile-component-folders.mdc`                                   | Agent rule §17.6; no flat screens; `features/` + `grid/blocks/` per §24–§25 |

**Do not** tick `[ ]` items inside this canonical prompt file in git — mirror completion in the PR.

---

## 13. Master checklist (**required** — mirror in PR)

### 13.1 Structure

- [ ] No flat `*.tsx` at `src/components/` root (except documented N/A).
- [ ] No flat screen TSX at `src/screens/` root.
- [ ] `wall-tickets/` namespace per §7.
- [ ] `MobilePageLayout/` folder; no flat `MobilePageLayout.tsx` at `grid/` root.
- [ ] Each migrated folder has `index.ts` **or** PR explains why omitted.

### 13.2 Imports

- [ ] All importers updated; `yarn typecheck` clean.
- [ ] `verify-mobile-component-colocation.mjs --imports` clean on final branch (§17.2).
- [ ] ESLint import boundaries enabled or deferred with reason (§20).

### 13.3 Scope discipline

- [ ] Zero intentional behavior / copy / API / navigation param changes.
- [ ] Shared hooks/utils remain shared per §3.
- [ ] Screen `index.ts` exports only public screen component(s).

### 13.4 Tests

- [ ] Screen tests colocated per §19.
- [ ] **§19.2** final sweep: `yarn test` green.
- [ ] API/utils tests may stay centralized.

### 13.5 Quality gates

- [ ] §11 commands green.
- [ ] PR lists phases delivered and deferred items with reason.

---

## 14. Example before / after (reference)

**Before:**

```
src/components/AppShell.tsx
src/screens/LoginScreen.tsx
src/grid/MobilePageLayout.tsx
src/theme/AnimatedShellGradient.tsx
```

**After:**

```
src/components/AppShell/
  AppShell.tsx
  index.ts
src/components/wall-tickets/WallTicketsSection/
  WallTicketsSection.tsx
  index.ts
src/screens/LoginScreen/
  LoginScreen.tsx
  LoginScreen.test.tsx
  index.ts
src/grid/MobilePageLayout/
  MobilePageLayout.tsx
  BlockChrome.tsx
  index.ts
src/theme/AnimatedShellGradient/
  AnimatedShellGradient.tsx
  index.ts
```

---

<a id="agent-engagement-exit-rule"></a>

## 15. Agent engagement exit rule (NON-NEGOTIABLE)

- **English:** Do **not** declare the task done until the **agreed track** is satisfied:
  - **Track A only:** **§13** + agreed **§16** phase(s) + **§19.2** / **§26** `yarn validate` green + colocation verify **0**.
  - **Track A + named §27 slice(s):** above **plus** every `- [ ]` in the scheduled **§27** subsection(s) implemented and tested.
    A half-moved tree (broken `@/` imports, flat screens left behind, or red Jest) is **not** acceptable.

- **Slovak:** Agent **nesmie skončiť**, kým nie je hotová **dohodnutá stopa** — Track A: §13 + §16 + testy; Track B: navyše konkrétne §27 checklisty z PR.

**Not governed by this exit rule:** optional **Phase 2c**, **§18** splits (unless in scope), **§14** examples, **entire §27** if engagement is **colocation-only** (Track A).

---

## 16. Master checklist — implementing agent (**required** — mirror in PR)

### 16.0 Preconditions

- [ ] Branch clean; `cd many_faces_mobile && yarn install --immutable` succeeds.
- [ ] §1 inventory re-run (counts in PR).
- [ ] Scope: **mobile only**, structure-only.
- [ ] Agreed phase(s) from §10 in PR title/body.

### 16.1 Phase 0.5 — tooling only **(required before bulk moves)**

- [ ] `scripts/colocate-mobile-component.mjs` (§17.1).
- [ ] `scripts/verify-mobile-component-colocation.mjs` (+ `--imports` §17.2).
- [ ] (optional) `scripts/migrate-mobile-colocate-phase.mjs` with phases `theme | shell | wall-tickets | grid | screens`.
- [ ] `.cursor/rules/mobile-component-folders.mdc` (§17.6) — include §23–§25 rules.
- [ ] (optional in 0.5 or **Final**) §26 — `yarn validate` script + `jest.config.js` — **no** UI moves in same PR as bulk colocation unless only DX.
- [ ] No component/screen files moved in this PR (scripts + rules + optional §26 only).

### 16.2 Phase 1 — `theme/`

- [ ] `AnimatedShellGradient/` + `index.ts`.
- [ ] §11 green for this PR.

### 16.3 Phase 2 — shell + effects

- [ ] `AppShell/`, `ShellDrawer/`, `MainLogo/`, `ErrorFallback/`.
- [ ] `MeCapabilitiesBootstrap/`, `PushTokenRegistrationEffect/`, `PushNotificationResponseEffect/`.
- [ ] §11 green for this PR.

### 16.4 Phase 2b — `wall-tickets/`

- [ ] Both components colocated; importers updated.
- [ ] §11 green for this PR.

### 16.5 Phase 3 — `grid/`

- [ ] `MobilePageLayout/`; optional §18.3 extractions.
- [ ] §11 green for this PR.

### 16.6 Phase 4 — `screens/`

- [ ] All **12** screens in folders.
- [ ] Tests moved from `screens/__tests__/` where they exist.
- [ ] Optional §18 splits for large auth/shell-related screens.
- [ ] §11 + §19.2 green.

### 16.7 Final — guards + docs

- [ ] `verify-mobile-component-colocation.mjs --imports` exits **0**.
- [ ] Parent `many_faces_main` CI step added §17.3 (or merged in Phase 4 if verify already green).
- [ ] §26 `yarn validate` green; `scripts/verify-ci.sh` calls `yarn validate` when §26 is in repo.
- [ ] §12 docs updated (colocation tree + pointer to §23–§27).

### 16.8 Track B — post-colocation slices **(separate PRs — §27)**

Copy the relevant §27 subsection checklist into each PR. **Do not** mix with Track A `git mv` unless explicitly approved.

- [ ] **§27.2** My Submissions detail — when scheduled.
- [ ] **§27.3** Shell i18n + reduced motion — when scheduled.
- [ ] **§27.1** Grid blocks — per block or small batch.
- [ ] **§27.4** Route ↔ portal URL table in README — when adding/rename routes in Track B.
- [x] **§24** `features/settings` scaffold + **§24.6** shell mount (`f2de1d3`); messenger / full settings tabs → parity prompt.

---

## 17. Tooling, CI, conventions

### 17.1 Helper script — `scripts/colocate-mobile-component.mjs` **(required)**

Adapt from `scripts/colocate-portal-component.mjs`:

```bash
node scripts/colocate-mobile-component.mjs AppShell [--dry-run]
node scripts/colocate-mobile-component.mjs LoginScreen --screen [--dry-run]
node scripts/colocate-mobile-component.mjs MobilePageLayout --grid [--dry-run]
node scripts/colocate-mobile-component.mjs WallTicketsSection --wall-tickets [--dry-run]
node scripts/colocate-mobile-component.mjs AnimatedShellGradient --theme [--dry-run]
node scripts/colocate-mobile-component.mjs AlbumGridBlock --grid-block [--dry-run]
node scripts/colocate-mobile-component.mjs SettingsPanel --feature settings [--dry-run]
```

Creates `Name/Name.tsx`, `index.ts`; does **not** split inline `StyleSheet` unless operator passes a separate refactor flag (out of scope).

| Flag               | Target base dir                                   |
| ------------------ | ------------------------------------------------- |
| (default)          | `src/components/`                                 |
| `--screen`         | `src/screens/`                                    |
| `--grid`           | `src/grid/` (layout only — prefer `--grid-block`) |
| `--grid-block`     | `src/grid/blocks/`                                |
| `--wall-tickets`   | `src/components/wall-tickets/`                    |
| `--theme`          | `src/theme/`                                      |
| `--feature <area>` | `src/features/<area>/`                            |

### 17.2 Verify script — `scripts/verify-mobile-component-colocation.mjs` **(required)**

Fail when flat TSX remain at:

- `many_faces_mobile/src/components/` (maxdepth 1)
- `many_faces_mobile/src/components/wall-tickets/` (maxdepth 1)
- `many_faces_mobile/src/screens/` (maxdepth 1)
- `many_faces_mobile/src/grid/MobilePageLayout.tsx` (flat layout file)
- `many_faces_mobile/src/grid/blocks/` (maxdepth 1 per block — §25)
- `many_faces_mobile/src/features/*/` (maxdepth 1 — §24, when folder exists)
- `many_faces_mobile/src/theme/AnimatedShellGradient.tsx` (flat theme component)

**`--imports` mode:** `rg` for imports that still target flat paths like `@/screens/LoginScreen.tsx` or `@/components/AppShell.tsx`.

```bash
node scripts/verify-mobile-component-colocation.mjs
node scripts/verify-mobile-component-colocation.mjs --imports
```

### 17.3 CI wiring — `many_faces_main` **(required in final colocation PR)**

Add to `.github/workflows/ci.yml` under `many_faces_mobile` job **after** verify script exists and passes on branch:

```yaml
- name: Verify mobile component folder colocation
  working-directory: many_faces_mobile
  run: node ../scripts/verify-mobile-component-colocation.mjs
```

Extend `scripts/verify-dev-stack-contracts.sh` **when** mobile scripts land — append `verify-mobile-component-colocation.mjs` and `colocate-mobile-component.mjs` to the existing colocation script list (alongside portal/admin). Until Phase 0.5 merges, the parent contract script will not mention mobile files yet.

### 17.4 `@/` alias — already present **(N/A Phase 0)**

`tsconfig.json` and `babel-plugin-module-resolver` already map `@/*` → `src/*`. **Do not** remove or rename during colocation.

### 17.5 Jest module resolution

Today the repo runs **`jest-expo`** without a committed `jest.config.cjs` (ESLint may still ignore that filename if added later). **`@/`** for tests comes from the same **`babel-plugin-module-resolver`** config as the app (`babel.config.js`). After colocation, run `yarn test` and fix any colocated test that breaks; prefer `@/screens/LoginScreen` or relative `./LoginScreen` imports.

### 17.6 Cursor rule — `.cursor/rules/mobile-component-folders.mdc` **(required)**

Short rule: new UI → folder per §2.1; no flat `src/screens/Foo.tsx`; run verify script before push; link to this prompt.

### 17.7 Optional import fixer

`scripts/fix-mobile-colocated-imports.mjs` — deepen `./` paths inside moved trees only; **do not** rewrite `@/` consumers.

---

## 18. Large screens / grid — private sub-components (**optional** per file)

Structure-only extractions; **no** logic changes.

### 18.1 Shell

`AppShell.tsx` → optional `ShellHeader.tsx`, `ShellFooter.tsx`, `OfflineBanner.tsx` in same folder; **not** exported from `index.ts`.

`ShellDrawer.tsx` → optional `DrawerMenuList.tsx`, `DrawerUserPanel.tsx`.

### 18.2 Auth screens

`LoginScreen.tsx` → optional `LoginForm.tsx` + `loginSchema.ts` (yup) when file is touched in Phase 4.

### 18.3 Grid layout

Extract existing inline `BlockChrome` and `GridBlockBody` from `MobilePageLayout.tsx` to sibling files in `MobilePageLayout/`.

### 18.4 Wall tickets

Optional `WallTicketRow.tsx` if list rendering is split — only when already editing `WallTicketsSection.tsx`.

---

## 19. Colocated tests (**required** — Phase 4)

| Today                                           | After                                                |
| ----------------------------------------------- | ---------------------------------------------------- |
| `src/screens/__tests__/LoginScreen.test.tsx`    | `src/screens/LoginScreen/LoginScreen.test.tsx`       |
| `src/screens/__tests__/RegisterScreen.test.tsx` | `src/screens/RegisterScreen/RegisterScreen.test.tsx` |

- [ ] Update test imports to match moved modules.
- [ ] Remove empty `src/screens/__tests__/` when last file moved.
- [ ] **Do not** require new tests for screens that had none.

### 19.2 Final test sweep (**required**)

- [ ] `cd many_faces_mobile && yarn test` on final branch before engagement exit.

---

## 20. Import boundaries — ESLint (**optional** in final PR)

If enabling `eslint-plugin-import` restrictions:

- Forbid imports of `@/screens/*/*.tsx` and `@/components/*/*.tsx` (deep file paths) from outside the folder.
- Allow `@/screens/LoginScreen` (barrel).

Defer with PR note if `eslint-config-expo` conflict — verify script (§17.2) is still **required**.

---

## 21. DX — README, Metro, local verify

- [ ] Document in `many_faces_mobile/README.md`:

```bash
node ../scripts/verify-mobile-component-colocation.mjs
node ../scripts/verify-mobile-component-colocation.mjs --imports
```

- [ ] **Metro / bundle (optional):** note in PR if `npx expo export` bundle size changed; not a gate unless regression > ~10% on entry chunk.
- [ ] **CI source of truth:** `many_faces_main/.github/workflows/ci.yml` job `many_faces_mobile` (submodule has no separate workflow in this monorepo layout). Optional: duplicate verify in the submodule repo only if it gains its own `ci.yml` later.

---

## 23. Rollout sequencing — colocation before parity (**required** — read before any PR)

### 23.1 Why order matters

`many_faces_mobile` is still small (~9 components, ~12 screens). [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md) will add **many** screens, grid blocks, `features/settings`, and shell tabs. If parity lands **first** as flat `src/screens/Foo.tsx` files, you pay for **two** large refactors.

### 23.2 Mandatory order (default)

| Step  | Track            | Deliverable                                                                                            |
| ----- | ---------------- | ------------------------------------------------------------------------------------------------------ |
| **1** | **A**            | Complete **§10** colocation phases (through **Final** + verify CI).                                    |
| **2** | **B — DX**       | **§26** `yarn validate` + committed Jest config (may merge with Final).                                |
| **3** | **B — polish**   | **§27.3** shell i18n + reduced motion (small, touches `AppShell/` / `ShellDrawer/` already colocated). |
| **4** | **B — journey**  | **§27.2** My Submissions detail screen.                                                                |
| **5** | **B — grid**     | **§25** + **§27.1** — `grid/blocks/` registry; replace placeholders block-by-block.                    |
| **6** | **B — features** | **§24** + parity prompt — `features/settings/`, messenger, etc.                                        |

### 23.3 Waiver

Product owner may waive step 1 for a **single** emergency parity fix — PR must state waiver and open a **colocation** ticket immediately. **Do not** waive for greenfield modules: new UI **must** use folder layout from day one (§2.1, §24).

### 23.4 Parity prompt contract (agent handoff)

When starting [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md) after Track A:

- [ ] Confirm `node scripts/verify-mobile-component-colocation.mjs` exits **0** on `main`.
- [ ] New routes only as `src/screens/<Name>/` or `src/features/<area>/<Name>/` — **never** new flat `src/screens/<Name>.tsx`.
- [ ] New grid blocks only under `src/grid/blocks/<BlockName>/` (§25).

---

## 24. Future `src/features/` namespace (**required** when adding parity modules)

Portal groups cross-cutting product areas under `many_faces_portal/src/features/` (e.g. **settings**). Mobile ships **`src/features/settings/`** (`SettingsSidePanel*`) — shell mount **§24.6**; app chrome stays in `src/components/` (`AppShell`, `ShellDrawer`).

### 24.1 Target layout (mirror portal intent)

```
src/features/
  settings/
    SettingsSidePanel/
      SettingsSidePanel.tsx
      index.ts
    SettingsSidePanelHeader/
    SettingsSidePanelBody/
```

**Do not** add flat `src/features/settings/SettingsSidePanel.tsx` at the `settings/` root.

### 24.2 What belongs in `features/` vs `screens/` vs `components/`

| Layer                      | Use for                                                                                                                                                  |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`src/screens/`**         | **Routable** full-screen destinations registered in `RootNavigator` (`FacePage`, `MySubmissions`, `Login`, …).                                           |
| **`src/features/<area>/`** | **Non-route** or **composite** UI reused across screens (settings side panel, messenger tab body, notifications list) — same role as portal `features/`. |
| **`src/components/`**      | App-wide **chrome** (`AppShell`, `MainLogo`, effects) and shared widgets (`wall-tickets/`).                                                              |

### 24.3 Colocation rules (same as §2.1)

- One primary React component = one folder + `index.ts`.
- Private hooks/types beside the feature folder; shared hooks stay in `src/hooks/api/`.
- Import via `@/features/settings/SettingsPanel` — not deep file paths.

### 24.4 Verify extension **(required when `features/` exists)**

Extend `scripts/verify-mobile-component-colocation.mjs` to fail on flat `*.tsx` at `src/features/*/` maxdepth 1 (same pattern as `components/`).

### 24.5 Checklist — first `features/` PR

- [x] Create `src/features/settings/` for the defined settings scaffold slice.
- [x] Document area in `many_faces_mobile/README.md` project layout + [`src/features/README.md`](../../many_faces_mobile/src/features/README.md).
- [x] Update verify script + `.cursor/rules/mobile-component-folders.mdc`.
- [x] No new flat TSX under `features/settings/`.

### 24.6 Settings panel — shell wiring **(completed `f2de1d3`)**

Read-only native panel opened from the header when authenticated (portal `Header` `onSettingsToggle` parity). Full tabs (profile, messenger settings, notifications, language) stay in [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md).

- [x] `AppShell` state + `SettingsSidePanel` modal/side sheet; closes drawer when opening settings.
- [x] `ShellHeader` settings control (`common:shell.openSettings`) — guests do not see it.
- [x] Mobile resx: `common.settings.*` + `common.shell.openSettings` (en/sk/cz) in `many_faces_backend` `MobileResources.*.resx`.
- [x] Tests: `SettingsSidePanel.test.tsx`, `ShellHeader.test.tsx`, `AppShell.settings.test.tsx`.
- [x] `docs/rest-parity-matrix.md` — settings row **Language + shell**.
- [x] **`LanguageSwitcher`** in `SettingsSidePanelBody` (`en`/`sk`/`cz`, `i18nextLng` persistence) — portal settings-tab subset.
- [ ] Full portal `SettingsSidePanelBody` tabs (profile, messenger, notifications) — **deferred** (parity prompt).

---

## 25. Grid `blocks/` registry — folder convention + parity matrix (**required** for grid parity)

### 25.1 Problem (as-is)

- `src/grid/parseGridSchema.ts` defines **`KNOWN_TYPES`** (`album`, `blog`, `reel`, `chatRoom`, `story`, …).
- `MobilePageLayout.tsx` implements **`ad*`** via `WallTicketsAdGridBlock` and shows a **generic placeholder** for all other types (`common:grid.blockPlaceholder` in i18n).
- Portal maps each `componentType` to a real component under `many_faces_portal/src/components/grid/`.

### 25.2 Target layout

Keep **engine** at `src/grid/` root; put **each block UI** in its own folder:

```
src/grid/
  parseGridSchema.ts
  gridTypes.ts
  MobilePageLayout/
    MobilePageLayout.tsx
    index.ts
    blockRegistry.ts          # componentType → React component (no mega switch in layout file)
  blocks/
    AlbumGridBlock/
      AlbumGridBlock.tsx
      index.ts
      useAlbumGridBlock.ts    # (optional) page-private query hook wrapper
    BlogCarouselBlock/
      ...
    AdGridBlock/              # (optional) move ad rendering out of WallTicketsAdGridBlock
      ...
```

**Naming:** PascalCase folder = primary export; match portal grid component names where possible (`AlbumGrid` → `AlbumGridBlock` on mobile is OK if documented in matrix).

### 25.3 `blockRegistry.ts` contract **(required)**

```ts
// Illustrative — implement in repo
import type { ComponentType } from "react";
import type { GridBlockRenderProps } from "@/grid/gridTypes";

export const gridBlockRegistry: Partial<
  Record<GridComponentType, ComponentType<GridBlockRenderProps>>
> = {
  ad: AdGridBlock,
  adGrid: AdGridBlock,
  adCarousel: AdGridBlock,
  // album: AlbumGridBlock — add as each block ships
};
```

- [ ] `MobilePageLayout` resolves `componentType` through **`gridBlockRegistry`**; unknown types → existing placeholder (no crash).
- [ ] **Do not** import every block from a single 2 000-line layout file — registry + lazy `import()` per block is **(optional)** for bundle size once >5 blocks ship.

### 25.4 REST + grid parity matrix **(required** — update `docs/rest-parity-matrix.md`)

Add columns to the existing table (or a second **Grid blocks** table):

| `componentType` (schema)              | Portal component (reference) | Mobile block folder                               | Status                  |
| ------------------------------------- | ---------------------------- | ------------------------------------------------- | ----------------------- |
| `ad`, `adGrid`, `adCarousel`          | wall/ad widgets              | `WallTicketsAdGridBlock` or `blocks/AdGridBlock/` | **Done** (compact list) |
| `album`, `albumGrid`, `albumCarousel` | `grid/Album*`                | `blocks/AlbumGridBlock/`                          | **Deferred**            |
| `blog`, …                             | …                            | …                                                 | **Deferred**            |
| …                                     | …                            | …                                                 | …                       |

**Convention:** **Done** = real data UI + tests for pure helpers; **Placeholder** = registry entry missing, layout shows i18n placeholder; **N/A** = type not used on mobile product.

### 25.5 Per-block PR checklist

- [ ] Block folder under `src/grid/blocks/<Name>/` with `index.ts`.
- [ ] Hook(s) in `src/hooks/api/` if shared; block-private fetch logic stays in block folder.
- [ ] Face-scoped URLs via `absoluteScopedApiUrl` / `faceScope.ts` — same rules as `wallTicketsApi.ts`.
- [ ] Capability gates via `src/acl/permissions.ts` — mirror portal before enabling create/edit.
- [ ] Update matrix row; `yarn test` + **`yarn validate`**.
- [ ] Colocated test `blocks/<Name>/<Name>.test.tsx` when block has non-trivial parsing/UI logic.

### 25.6 Relationship to `wall-tickets/`

`WallTicketsSection` (full wall page list) stays in **`src/components/wall-tickets/`**. Grid **`ad*`** slices may keep using `WallTicketsAdGridBlock` or move to `grid/blocks/AdGridBlock/` in a **structure-only** PR — document in matrix; avoid duplicate API clients.

---

## 26. `yarn validate` + committed Jest config (**required** in Final or dedicated DX PR)

### 26.1 Problem (as-is)

- `many_faces_admin` exposes **`yarn validate`** (`type-check` + `lint` + `format:check`).
- Mobile runs the same checks **separately** in CI via `scripts/verify-ci.sh` / `scripts/lint.sh` but has **no** single `validate` script.
- Jest runs via **`jest-expo`** with **no** committed `jest.config.js`; `@/` resolution depends on Babel `module-resolver` only.

### 26.2 Required `package.json` script

Add to `many_faces_mobile/package.json`:

```json
"validate": "yarn typecheck && yarn lint && yarn format:check && yarn test"
```

- [ ] `yarn validate` exits **0** locally and in CI.
- [ ] Update `many_faces_mobile/scripts/verify-ci.sh` to call **`yarn validate`** instead of duplicating individual steps (keep `expo-doctor` / audit as separate CI steps if present today).

### 26.3 Required `jest.config.js` **(required)**

Create `many_faces_mobile/jest.config.js` (adjust if repo standardizes on `.cjs`):

```js
/** @type {import('jest').Config} */
module.exports = {
  preset: "jest-expo",
  setupFilesAfterEnv: [], // add jest.setup.ts if needed later
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/src/$1",
  },
  transformIgnorePatterns: [
    "node_modules/(?!((jest-)?react-native|@react-native(-community)?)|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@unimodules/.*|unimodules|sentry-expo|native-base|react-native-svg)",
  ],
};
```

- [ ] Remove `jest.config.cjs` from ESLint **ignores** only if the file exists; add to **include** when created.
- [ ] Colocated screen tests under `src/screens/<Screen>/` still resolve `@/` after colocation.

### 26.4 CI / monorepo

- [ ] `many_faces_main` job `many_faces_mobile` still green after `verify-ci.sh` uses `yarn validate`.
- [ ] Document `yarn validate` in README **Scripts** table next to `yarn test`.

---

## 27. Post-colocation product slices (**Track B** — separate PRs)

Implement only subsections **explicitly named** in the engagement or PR title. Each slice must pass **§26** and update docs listed in **§12**.

### 27.1 Grid blocks — implement registry + first real blocks

**Goal:** Replace placeholder tiles with real read-only (then interactive) grid blocks per **§25**.

**Reference (portal):**

- `many_faces_portal/src/components/PageGridLayout.tsx`
- `many_faces_portal/src/components/grid/*`

**Minimum first batch (product default — adjust in PR if waived):**

| Priority | Types                                          | Rationale                   |
| -------- | ---------------------------------------------- | --------------------------- |
| P1       | `blog`, `blogGrid`, `blogCarousel`             | Common face home content    |
| P1       | `album`, `albumGrid`, `albumCarousel`          | Same                        |
| P2       | `reel`, `reelGrid`, `reelCarousel`             | Media-heavy                 |
| P2       | `story`, `storyGrid`, `storyCarousel`          | Stories route synergy       |
| P3       | `chatRoom`, `chatRoomGrid`, `chatRoomCarousel` | Depends on §27.5 SignalR UI |

**Checklist:**

- [ ] `src/grid/MobilePageLayout/blockRegistry.ts` (or equivalent) wired.
- [ ] At least **one** non-`ad*` block **Done** in matrix (§25.4).
- [ ] `FacePageScreen` smoke: face page with `gridSchema` showing real block, not only placeholder.
- [ ] Tests for block pure helpers; no snapshot-only tests.

**Out of scope here:** Admin grid **editing** (stays in `many_faces_admin`); **Quill** in RN (see parity prompt §2.3).

---

### 27.2 My Submissions — detail screen + navigation

**Goal:** User can open a submission from the list and see creator-safe detail (portal: detail / moderation copy without leaking internal reviewer notes).

**As-is:**

- `MySubmissionsScreen.tsx` — grouped list via `contentModeration.ts`.
- `myContentSubmissionsApi.ts` + `useMyContentSubmissions` — list endpoint only.
- Matrix: **detail / `?edit=1` / resubmit deferred**.

**Target routes (`AppStackParamList`):**

```ts
MySubmissionDetail: {
  submissionId: string;
} // or number — match API id type
```

**Target layout:**

```
src/screens/MySubmissionDetailScreen/
  MySubmissionDetailScreen.tsx
  index.ts
  MySubmissionDetailScreen.test.tsx   # (required) happy + 404/403 paths
```

**Behavior (v1 — read-only):**

- [ ] Tap row on `MySubmissionsScreen` → `navigate('MySubmissionDetail', { submissionId })`.
- [ ] Fetch single submission if API exists; else reuse list payload + find by id (document choice in PR).
- [ ] Show pipeline status, content type, title/summary fields allowed for **creator** (reuse `creatorSafeReason` / portal field policy).
- [ ] Guest / wrong capability → sign-in or “not available” copy — no raw API errors.
- [ ] Register screen on **guest and auth** stacks if product requires (mirror `MySubmissions` today).

**v2 (defer unless PR scope says otherwise):** `?edit=1`, resubmit, delete — track under [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md).

**Tests:**

- [ ] RTL test: list navigation pushes detail route with param.
- [ ] API module test if new `fetchMyContentSubmission(id)` added.

**Docs:**

- [ ] Update `rest-parity-matrix.md` creator row to **Detail read path Done**.
- [ ] **§27.4** route table row for detail.

---

### 27.3 Shell polish — i18n, accessibility, reduced motion

**Goal:** Shell matches portal quality bar for copy and motion before adding more screens.

**Known gaps (fix in `AppShell/`, `ShellDrawer/`, `HomePlaceholderScreen/` after colocation):**

| Location                           | Issue                                                 | Fix                                                                                               |
| ---------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `HomePlaceholderScreen.tsx`        | Hardcoded **"Sign in"**, **"Register"** button labels | `t('home.signIn')`, `t('home.register')` in `common` namespace (+ `sk`/`cz` via localization API) |
| Same                               | `accessibilityLabel="Open sign in"` hardcoded English | `t('home.signInA11y')`                                                                            |
| `AppShell.tsx` / `ShellDrawer.tsx` | Reanimated drawer / gradient motion always on         | Respect **`AccessibilityInfo.isReduceMotionEnabled()`** (and listen for changes)                  |
| `AnimatedShellGradient.tsx`        | Continuous animation                                  | Disable or shorten loop when reduce motion enabled                                                |

**Implementation notes:**

- [ ] Use **`useReducedMotion()`** from `react-native-reanimated` **or** `AccessibilityInfo` — pick one pattern and use consistently in shell + theme.
- [ ] When reduce motion: drawer open/close → `duration: 0` or instant layout; gradient → static first color from `gradientSettings`.
- [ ] No change to business routes or API calls — copy + motion only.
- [ ] `yarn test` — add tests for any extracted `useShellMotionPolicy` pure helper if logic is non-trivial.

**Checklist:**

- [ ] No user-visible English hardcoded strings remain on **Home** auth buttons (grep `Sign in` / `Register` in `src/screens` / `src/components`).
- [ ] Manual test: iOS **Settings → Accessibility → Motion → Reduce Motion** → reload app → drawer/gradient respect setting.
- [ ] Portal reference for shell copy: `many_faces_portal` header/home — align keys where sensible, do not rename keys unnecessarily.

---

### 27.4 Route ↔ portal URL mapping table (**required** when shipping Track B routes)

[mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md) §2.3 requires documenting browser URL vs navigation state.

Add subsection **`## Navigation vs portal URLs`** to `many_faces_mobile/README.md`:

| Portal path pattern (example)               | Mobile route name    | Notes                                   |
| ------------------------------------------- | -------------------- | --------------------------------------- |
| `/:lang/:faceIndex` (home)                  | `Home`               | Config-driven page list                 |
| `/:lang/:faceIndex/login`                   | `Login`              | Guest stack                             |
| `/:lang/:faceIndex/register`                | `Register`           | When `faceOffersRegisterPage`           |
| `/:lang/:faceIndex/register/complete?hash=` | `RegisterComplete`   | `linking` config in `App.tsx`           |
| Face page by stable id                      | `FacePage`           | `{ pageId: number }` — not path segment |
| Portal **My submissions**                   | `MySubmissions`      |                                         |
| Portal submission detail                    | `MySubmissionDetail` | After §27.2                             |

- [ ] Table updated whenever `AppStackParamList` or portal routes change.
- [ ] Deep links documented (`manyfaces://`, `RegisterComplete` today).

---

### 27.5 Deferred here (track in parity prompt, not §27 default scope)

| Item                                       | Track in                                                                                           |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| SignalR messenger / chat room / AI chat UI | [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md) §10 |
| `features/settings` shell + language picker | **Done** — §24.6 (`f2de1d3` + language switcher)                                                 |
| `features/settings` full portal tabs       | [mobile-portal-feature-parity-agent-prompt.md](./mobile-portal-feature-parity-agent-prompt.md) §13 |
| Full API client class port (`ApiClient`)   | Parity §3 — mobile uses `httpClient` + `faceScope` today                                           |
| E2E (Maestro / Detox)                      | Separate engagement                                                                                |

---

## 28. Explicit non-goals (summary)

- **Shared auth form** (`LoginScreen` + `RegisterScreen`) — feature PR after colocation; may live in `src/features/auth/` or shared `components/` only if product specifies.
- **Design system** primitives (`Button`, `Input`) — not required for colocation or §27.
- **Implementing all grid types in one PR** — use §25.5 per-block PRs.
- **Mixing Track A `git mv` with §27 behavior changes** — forbidden unless PR title states combined scope.
- **Expo Router migration** — out of scope (Phase 1 decision stands).
