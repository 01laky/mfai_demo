# React Hooks plugin — full `recommended` / compiler rules rollout (agent prompt) (**required** brief — see body for **`(required)`** items)

**Purpose:** Move **`fe_demo`** and **`admin_demo`** from the **minimal** ESLint hooks surface (`react-hooks/rules-of-hooks` + `react-hooks/exhaustive-deps` only) toward the **full** `eslint-plugin-react-hooks` **`flat.recommended`** (or **`flat['recommended-latest']`**) preset **safely**, in controlled phases, with measurable violation counts, refactors, and green **`yarn validate` / `yarn test` / `yarn build`**. Use this document as a **copy-paste agent brief**.

**Checklists:** Trailing `[ ]` deliverable lists are **PR templates**—tick there, not by default in this file ([docs/prompts/README.md](./README.md)).

**(required)** Any agent run using this brief must satisfy **every** **`(required)`** item in **§§3–8** (and **§1.3**, **§2**, **§5** where they apply) before merge unless the task owner explicitly waives a bullet **in writing** in the same PR.

**Scope:** `fe_demo`, `admin_demo` only (Yarn 4, ESLint 10, flat config). **(required)** Stay inside this scope unless the task expands it. Out of scope: `be_demo`, `ai_demo`, changing the **canary vs stable** pin for `eslint-plugin-react-hooks` unless a separate task explicitly upgrades peers (see [eslint10-react-hooks-peer-yarn-agent-prompt.md](./eslint10-react-hooks-peer-yarn-agent-prompt.md)).

**Prerequisite context (repo today):** Both SPAs pin an **exact** `eslint-plugin-react-hooks` **canary** for ESLint **10** peer alignment; `eslint.config.js` registers the plugin but **does not** extend `reactHooks.configs.flat.recommended`, because that preset enables **many** React Compiler–oriented rules at once (e.g. `react-hooks/set-state-in-effect`), which previously produced **dozens** of errors on this codebase. This prompt is the **migration path** from that intentional subset to full coverage. **(required)** Do not contradict this baseline in a PR without documenting the new target preset and re-running **§3**.

---

## 1. Why this migration exists (product + upstream) (**required** reading)

### 1.1 What upstream ships today (verify on your run day) (**required**)

**(required)** On the day of the PR, re-open the links below; do **not** rely on cached assumptions if npm or the changelog moved.

From **`eslint-plugin-react-hooks` v7.x** ([npm readme](https://www.npmjs.com/package/eslint-plugin-react-hooks), [CHANGELOG 7.0.0](https://github.com/facebook/react/blob/main/packages/eslint-plugin-react-hooks/CHANGELOG.md)):

- **(required)** **`recommended`** (flat: `reactHooks.configs.flat.recommended`) bundles **Rules of Hooks** plus **React Compiler–aligned** lint rules (not only `rules-of-hooks` + `exhaustive-deps`).
- **(required)** **`recommended-latest`** (flat: `reactHooks.configs.flat['recommended-latest']`) is described on npm as **bleeding-edge** experimental compiler rules on top of `recommended` — use only when the team explicitly wants **latest** compiler diagnostics.

**(required)** The React docs describe the **compiler rules** family and the philosophy of **gradual** cleanup: [ESLint Plugin React Hooks — recommended rules](https://react.dev/reference/eslint-plugin-react-hooks#recommended-rules) (same content structure as `beta.reactjs.org` reference pages).

**Agent rule:** Do **not** assume rule names or severities from memory. **(required)** For the **resolved** `eslint-plugin-react-hooks` version in each SPA, dump the preset’s rule table (see §3.2) and treat that as the source of truth for the PR.

### 1.2 Relationship to React Compiler (**required** context)

These rules surface patterns the **React Compiler** may flag or optimize around. The React team’s framing: you do **not** need to fix every violation immediately to ship; tightening lint is a **progressive** quality investment ([same reference section](https://react.dev/reference/eslint-plugin-react-hooks#recommended-rules)).

**(required)** If the PR intentionally leaves **`warn`**-level violations in tree to merge, the PR description **(required)** states why and links the follow-up that will drive them to **`error`** / zero-warnings per **§3.1**.

### 1.3 `eslint-plugin-react-hooks` vs `eslint-plugin-react-compiler` (**required** awareness)

**(required)** Treat **`eslint-plugin-react-hooks`** (`recommended` / compiler-aligned rules in that plugin) as **this prompt’s** primary scope.

**(required)** Do **not** add **`eslint-plugin-react-compiler`** (or other compiler ESLint integrations) in the same PR series **unless** the task explicitly says so. If the team **does** add it: **(required)** read upstream docs ([React Compiler — Installation](https://react.dev/learn/react-compiler/installation) — ESLint plugin section, [npm: `eslint-plugin-react-compiler`](https://www.npmjs.com/package/eslint-plugin-react-compiler)) and **(required)** attach a **duplicate-rule matrix** (hooks plugin rule id ↔ compiler plugin rule id) so overlapping diagnostics are not configured twice at **`error`** without intent.

**(required)** Default for this monorepo: finish **`eslint-plugin-react-hooks`** preset rollout **first**; any compiler-plugin adoption is a **separate** decision and PR.

---

## 2. Strategy matrix (**required** — pick one primary approach per PR series)

**(required)** Document the chosen row (**S1**, **S2**, **S2b**, **S3**, or **S4**) in the PR description. If the series mixes strategies (e.g. **S2** then converge to full preset), **(required)** state the sequence and the PR in which each phase ends.

| Approach                                              | When to use                                             | Shape of work                                                                                                                                                                                                                                                                                                                                     |
| ----------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **S1 — Big-bang preset**                              | Small codebase or few violations after a spike          | **(required)** Flip config to `reactHooks.configs.flat.recommended` (or `recommended-latest`), fix all errors in one or few commits.                                                                                                                                                                                                              |
| **S2 — Rule-by-rule** (**default** for this monorepo) | Many violations; need reviewable PRs                    | **(required)** Enable **one** new rule at a time (start **`warn`**, then **`error`**), merge, repeat. Optionally group related rules (e.g. purity + immutability).                                                                                                                                                                                |
| **S2b — Preset + temporary downgrades (inverse)**     | Many violations; want full picture fast, then peel away | **(required)** Enable **`flat.recommended`** (or target preset) **globally**, set the **noisiest** rules to **`warn`** or scoped **`off`** (with ticket + removal date per §5.3), merge, then **remove overrides** rule-by-rule. **(required)** Document in the PR that **S2b** is the primary strategy and attach the override list with owners. |
| **S3 — Path-scoped rollout**                          | Violations concentrated in modules (e.g. `src/pages/`)  | **(required)** Base config uses full preset; **`files`/`ignores`** overrides downgrade or disable specific rules in legacy folders until cleaned.                                                                                                                                                                                                 |
| **S4 — Preset + selective disables**                  | Third-party patterns (tables, forms) need time          | **(required)** Keep preset; **narrow** `eslint-disable-next-line` with **ticket ID** + **owner** (forbidden: file-wide disable of `react-hooks/*`).                                                                                                                                                                                               |

**(required)** **Forbidden:** `eslint-disable` entire files for `react-hooks/*` without a linked issue and removal date. **(required)** **Forbidden:** lowering `exhaustive-deps` to `off` “to unblock” the compiler rollout (fix deps or use documented `additionalHooks` / ref patterns).

---

## 3. Investigation (**required** before edits)

### 3.1 CI and local lint parity (**required**)

**(required)** For **each** of `fe_demo` and `admin_demo`, locate **every** place lint runs (not only `yarn lint`):

- **(required)** Search monorepo and SPA roots: `.github/workflows/**/*.yml`, `package.json` scripts (`lint`, `validate`, `test`, husky / lint-staged if present), and any root orchestration scripts.
- **(required)** Record the **exact** ESLint invocation CI uses (e.g. plain `eslint`, `eslint --max-warnings 0`, extra args, env vars).
- **(required)** Record whether **warnings** fail CI (`--max-warnings 0` or equivalent). If yes, **(required)** treat **`warn`** on `react-hooks/*` the same as **`error`** for merge (or **(required)** document a temporary team exception in the PR and cross-link the follow-up issue in **§6** workflow notes).
- **(required)** Confirm the **same file globs** are linted in CI as locally (no CI-only `eslint src` while local lints `cypress` / tests unless that split is **documented** and intentional).

**(required)** Attach a short **“Lint parity”** subsection to the PR (commands + warn policy + glob notes).

### 3.2 Dump rules from the **installed** preset (**required**)

**(required)** From each SPA root, run:

```bash
node --input-type=module -e "
import rh from 'eslint-plugin-react-hooks';
const rec = rh.configs?.flat?.recommended;
const latest = rh.configs?.flat?.['recommended-latest'];
function rules(cfg) {
  if (!cfg) return null;
  const arr = Array.isArray(cfg) ? cfg : [cfg];
  for (const c of arr) {
    if (c && typeof c === 'object' && c.rules) return c.rules;
  }
  return null;
}
console.log('--- recommended ---');
console.log(JSON.stringify(rules(rec), null, 2));
console.log('--- recommended-latest ---');
console.log(JSON.stringify(rules(latest), null, 2));
"
```

**(required)** Attach output to the PR. If `recommended-latest` is `undefined` or circular, **(required)** document that and do **not** use it without a workaround.

### 3.3 Baseline violation counts (**required**)

**(required)** On a **throwaway branch** or locally (do not merge with thousands of unfixed errors):

1. **(required)** Temporarily switch config to the target preset (see §5 template).
2. **(required)** Run:

```bash
yarn lint 2>&1 | tee /tmp/eslint-full-react-hooks.txt
```

**(required)** Produce a **table**: rule id → error count **and** rule id → warning count (if warnings appear). **(required)** Prefer the **machine-readable** path: run ESLint with **`-f json`**, save stdout to a file, then aggregate with **§3.7** (or an equivalent script you attach to the PR). **(required)** Attach the table to the PR. This table drives **S2** / **S2b** ordering (fix highest-signal or highest-count first, per team policy).

### 3.4 Map hotspots (**required**)

**(required)** From the JSON or text report, list **top 10 files** by violation count for the **first** rule you plan to enable (or for the **largest-count** rule in **S2b**). This prevents random file hopping.

### 3.5 Resolved flat config debugging (`eslint --print-config`) (**required**)

**(required)** For **at least one** representative file per SPA (e.g. one `src/` screen, one test file if tests are linted), run:

```bash
yarn exec eslint --print-config path/to/File.tsx
```

**(required)** Skim the resolved **`rules`** (and their severities) for every `react-hooks/*` key to confirm **merge order** (e.g. Prettier last, overrides visible). **(required)** If a rule’s severity disagrees with `eslint.config.js`, fix config order **before** mass refactors.

### 3.6 File-class coverage audit (`src` vs tests vs Storybook vs e2e) (**required**)

**(required)** From each SPA’s `eslint.config.js` (and any imported flat configs), build a **table** (in the PR body or attachment):

| File class (examples)                       | Included by lint? | Same `react-hooks/*` severity as `src/`? | Notes / ticket |
| ------------------------------------------- | ----------------- | ---------------------------------------- | -------------- |
| Application `src/**`                        |                   |                                          |                |
| Unit / integration tests (`**/*.test.*`, …) |                   |                                          |                |
| `__tests__/**`, `vitest` setup files        |                   |                                          |                |
| Storybook / `.stories.*` (if present)       |                   |                                          |                |
| Cypress / Playwright / e2e (if present)     |                   |                                          |                |

**(required)** If a class is **excluded**, say so explicitly. **(required)** If a class is **included** but should temporarily use **lower** severity for `react-hooks/*`, document **S3**-style overrides with ticket + removal date — do **not** silently widen `ignores` on production code to hide violations.

### 3.7 Appendix: aggregate `eslint -f json` by `ruleId` (**required** format)

**(required)** Produce counts using **JSON** output (adjust paths to each SPA’s lint target if different from `.`):

```bash
yarn exec eslint . -f json --no-error-on-unmatched-pattern > /tmp/eslint-out.json 2>/tmp/eslint-stderr.txt || true
node --input-type=module -e "
import { readFileSync } from 'node:fs';
const raw = readFileSync('/tmp/eslint-out.json', 'utf8');
let results;
try { results = JSON.parse(raw); } catch (e) {
  console.error('Parse failed — ensure eslint printed a single JSON array to stdout');
  process.exit(1);
}
const byRule = Object.create(null);
const byFile = Object.create(null);
for (const file of results) {
  const fp = file.filePath || '';
  for (const m of file.messages || []) {
    const id = m.ruleId || '(no rule id)';
    byRule[id] = (byRule[id] || 0) + 1;
    byFile[fp] = (byFile[fp] || 0) + 1;
  }
}
const rh = Object.entries(byRule).filter(([k]) => k.startsWith('react-hooks/'));
rh.sort((a, b) => b[1] - a[1]);
console.log('--- react-hooks/* counts ---');
for (const [k, v] of rh) console.log(k + '\t' + v);
const topFiles = Object.entries(byFile).sort((a, b) => b[1] - a[1]).slice(0, 15);
console.log('--- top files (all rules) ---');
for (const [k, v] of topFiles) console.log(v + '\t' + k);
"
```

**(required)** If `eslint` exits non-zero because of errors, still capture **`eslint-out.json`** when possible (the `|| true` above is only to allow the shell pipeline to continue — fix the underlying config if JSON is empty). **(required)** Attach the **`react-hooks/*`** table (and top-files list) to the PR.

---

## 4. Rule-by-rule remediation playbook (hints + web anchors) (**required** when fixing)

**(required)** For **every** PR that changes application code to satisfy **`react-hooks/*`** (or adjusts disables), use the subsection below that matches the **rule id** you touch; prefer **react.dev** links over ad-hoc patterns.

Use the official lint reference pages under **`https://react.dev/reference/eslint-plugin-react-hooks/lints/`** (replace `set-state-in-effect` in the path with the rule slug). Below: **practical** patterns that recur in SPAs like this monorepo.

### 4.1 `react-hooks/set-state-in-effect` (usually the largest bucket) (**required** when this rule is in scope)

- **Official:** [set-state-in-effect](https://react.dev/reference/eslint-plugin-react-hooks/lints/set-state-in-effect) — synchronous `setState` inside `useEffect` forces extra render passes; prefer **deriving during render**, **event handlers**, **`useLayoutEffect` + DOM measurement**, or **async** flows where the setState is not synchronous in the effect body’s first tick.
- **React guide:** [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — loading flags driven only by props/data, “sync state to props” anti-patterns, fetching with race handling (prefer **TanStack Query** patterns already in the repo).
- **Known friction:** [facebook/react#34743](https://github.com/facebook/react/issues/34743) — community discussion on “overly strict” cases (`mounted` / `isClient` patterns). **(required)** **Do not** dismiss the rule repo-wide; **(required)** prefer **documented** refactors (e.g. `useSyncExternalStore` for hydration/client-only UI where appropriate — see issue discussion and React docs).

**Hints (implementation) — (required)** apply when fixing this rule:

- **(required)** **Data fetching:** If `useEffect` + `setState` loads server data, migrate toward **`useQuery`** / **`useMutation`** with stable keys so effects do not duplicate client cache state.
- **(required)** **Derived lists:** `setItems(data?.items ?? [])` in an effect → usually **`const items = data?.items ?? []`** (or `useMemo` only if expensive).
- **(required)** **“Reset when id changes”:** Prefer **`key={id}`** on child component or compare during render / reset in the **same** effect using a pattern from React docs instead of unconditional synchronous sets scattered across effects.

### 4.2 `react-hooks/set-state-in-render` (**required** when this rule is in scope)

- **(required)** **Official:** [set-state-in-render](https://react.dev/reference/eslint-plugin-react-hooks/lints/set-state-in-render) — unconditional setState during render → infinite loops; **conditional** updates tied to previous render have a documented pattern.

### 4.3 `react-hooks/exhaustive-deps` (already `warn` — tighten carefully) (**required** when this rule is in scope)

- **(required)** Do **not** “fix” by blindly adding unstable function references; use **`useCallback`**, **move functions inside `useEffect`**, or **extract** stable helpers.
- **(required)** For intentional omissions, use **inline comment** with **reason** (not empty eslint-disable). Prefer `additionalHooks` / `settings` from plugin docs when effect-like hooks are custom ([rules-of-hooks options](https://react.dev/reference/eslint-plugin-react-hooks/lints/rules-of-hooks#options)).

### 4.4 `react-hooks/incompatible-library` (admin tables, third-party) (**required** when this rule is in scope)

- **(required)** **Official:** [incompatible-library](https://react.dev/reference/eslint-plugin-react-hooks/lints/incompatible-library) — libraries that fight memoization/compiler assumptions.
- **(required)** **Practical:** `@tanstack/react-table` + hooks often triggers warnings; fixes may be **upgrading** table major, **wrapping** table instance creation in `useMemo`, or **scoped** disable on the **single** line that creates the table with a ticket reference.

### 4.5 `react-hooks/refs` / `react-hooks/static-components` / `react-hooks/purity` / `react-hooks/immutability` (**required** when any of these rules is in scope)

- **(required)** Prefer **stable component definitions** (no inline `function Child()` inside render).
- **(required)** Avoid **mutating props** or shared module-level objects during render.
- **(required)** **Refs:** read/write timing must match React’s expectations (no ref reads for rendering decisions unless pattern is documented safe).

### 4.6 `react-hooks/unsupported-syntax` (often `warn`) (**required** when this rule is in scope)

- **(required)** Track **parser** / syntax features incompatible with compiler analysis; may require **refactor** (e.g. certain patterns in HOCs) or waiting on plugin updates.

### 4.7 `react-hooks/use-memo`, `preserve-manual-memoization`, `globals`, `gating`, `config`, `error-boundaries`, `component-hook-factories` (**required** when any of these rules is in scope)

- **(required)** Treat as **compiler hygiene**; fix together with team **performance** goals. When unsure, enable at **`warn`** first and collect signal.

### 4.8 Community plugins cross-check (**required** awareness before adding plugins)

- **`@eslint-react/eslint-plugin`** documents overlapping concepts (e.g. hooks-extra rules). **(required)** Use **only** as reading material unless the team explicitly adds another plugin — **(required)** avoid duplicate conflicting rules ([example rule doc](https://eslint-react.xyz/docs/rules/hooks-extra-no-direct-set-state-in-use-effect)).

---

## 5. ESLint config mechanics (flat config) (**required** when editing config)

### 5.1 Merge order (**required**)

When introducing `reactHooks.configs.flat.recommended`:

- **(required)** Keep **`eslint-config-prettier` last** in the `extends` / flat array so it can override formatting conflicts.
- **(required)** Ensure **`typescript-eslint`** configs and **`eslint-plugin-react-refresh`** remain compatible; **(required)** re-run `yarn lint` after reordering.

### 5.2 Example: **S2** single-rule overlay (**required pattern**)

**(required)** Keep the repo’s current explicit plugin registration **or** switch to `extends: [..., reactHooks.configs.flat.recommended]` **and** override one rule:

```js
// Illustrative — adapt to defineConfig([...]) structure in repo
{
  files: ['**/*.{ts,tsx}'],
  rules: {
    'react-hooks/set-state-in-effect': 'warn',
  },
}
```

### 5.3 Example: **S3** path override (**required pattern** when using path overrides)

```js
{
  files: ['src/legacy/**/*.{ts,tsx}'],
  rules: {
    'react-hooks/set-state-in-effect': 'off', // TRACK-123: remove by 20YY-MM-DD
  },
}
```

**(required)** Any `off` override must carry **`TRACK-*` / issue URL** and a **removal deadline** in the same PR or linked issue body.

### 5.4 `eslint-plugin-react-hooks` version change — preset diff gate (**required**)

**(required)** Any PR that **changes** the resolved version of `eslint-plugin-react-hooks` (canary bump, stable migration, yarn resolution change): **(required)** run **§3.2** (preset dump) on **old** and **new** version (two columns or two attached files). **(required)** Summarize in the PR: **added** rules, **removed** rules, **severity** changes in the preset. **(required)** Do **not** merge a version bump without that diff — silent preset drift breaks **S2** / **S2b** plans.

---

## 6. Implementation workflow (**required**)

1. **(required)** Complete **§3** investigations for **both** SPAs; attach all §3 tables and dumps (including **§3.1** lint parity, **§3.7** JSON aggregates when used).
2. **(required)** Choose **S1**, **S2**, **S2b**, **S3**, or **S4** (series may mix, e.g. **S2** then full preset — document the sequence in the PR).
3. **(required)** **Operational PR constraints:** keep each PR **reviewable** — **(required)** state in the PR **maximum scope** the team used for that step (e.g. cap **~15 files** or **one rule family** per PR unless **S1** explicitly approved). **(required)** Define **rollback**: reverting the PR must restore the **previous** `eslint.config.js` hooks block (one revert = green CI).
4. **(required)** **Lint cache / timing:** if the SPA uses **`eslint --cache`** or a committed/ignored `.eslintcache`, **(required)** delete the cache after **any** `eslint.config.js` change that affects `react-hooks/*`, then re-run lint. **(required)** Record **wall-clock** `yarn lint` duration **before** and **after** the rollout step in the PR (rough seconds is enough) so severe regressions are visible.
5. **(required)** Implement in **`fe_demo`**, run **`yarn lint` → `yarn validate` → `yarn test` → `yarn build`** using the **same** warn/error policy as **§3.1** (if CI is `--max-warnings 0`, local validation **(required)** must match before merge).
6. **(required)** Mirror in **`admin_demo`** (same rule set and severities unless a **documented** SPA-specific exception exists in the PR).
7. **(required)** **`reportUnusedDisableDirectives`:** run a cleanup pass before declaring the series done — **(required)** enable ESLint’s **`reportUnusedDisableDirectives`** for at least one full `yarn lint` on a throwaway branch **or** run the supported CLI flag if the repo’s ESLint version exposes it, and **(required)** remove stale `eslint-disable` comments introduced or orphaned by refactors. **(required)** If the repo already sets this in config, **(required)** ensure the rollout PR leaves **zero** unused directive reports.
8. **(required)** Update **`docs/guides/development.md`** subsection on hooks if the **default** preset for new code changes.
9. **(required)** Submodule commits + parent pointer bump per team rules.

---

## 7. Verification (**required**)

- [ ] **(required)** **§3.1 lint parity:** CI vs local commands and **warnings** policy documented; no undocumented glob mismatch.
- [ ] **(required)** **`yarn lint`** with **zero errors** and warnings policy **matching §3.1** (**(required)** zero warnings if CI uses `--max-warnings 0` or equivalent).
- [ ] **(required)** **`yarn validate`**, **`yarn test`**, **`yarn build`** in **both** SPAs.
- [ ] **(required)** No new **blanket** `eslint-disable` for `react-hooks/*`.
- [ ] **(required)** **Preset dump** (**§3.2**) attached for the **`eslint-plugin-react-hooks`** version you shipped; if the version changed in the PR, **(required)** **§5.4** old vs new preset diff attached.
- [ ] **(required)** **§3.5** `--print-config` spot-check done for representative files (both SPAs if both touched).
- [ ] **(required)** **§3.6** file-class table present and matches `eslint.config.js`.
- [ ] **(required)** **§6.4** lint cache invalidated after config edits; before/after lint timing noted in the PR.
- [ ] **(required)** **§6.7** unused directive / `reportUnusedDisableDirectives` pass complete with no remaining unused-disable noise from this series.

---

## 8. Deliverables (**required**)

- [ ] **(required)** PR description states **S1 / S2 / S2b / S3 / S4** choice, sequence if mixed, and **rule rollout order** (for **S2**) or **override list with tickets** (for **S2b** / **S3** / **S4**).
- [ ] **(required)** **§3.1** lint parity notes (commands, CI files referenced, warn policy).
- [ ] **(required)** Baseline vs final violation table from **§3.3** / **§3.7** (or “N/A — **S1** big-bang” with a single full-run attachment).
- [ ] **(required)** **§3.6** file-class coverage table.
- [ ] **(required)** Links to **react.dev** rule pages for the top 3 rules touched.
- [ ] **(required)** **§1.3:** explicit sentence “No `eslint-plugin-react-compiler` in this PR” **or** duplicate-rule matrix if compiler plugin was in scope.
- [ ] **(required)** Screenshots or notes **if** UI behavior changed; **(required)** state explicitly “N/A — no UI change” when there were no UI changes.

---

## 9. References (bookmark for the agent) (**required** normative hierarchy)

**(required)** **§3.2** (installed preset dump) and **§3.7** (JSON aggregates) **outrank** prose in this doc and in external links if they disagree. **(required)** Follow **§§7–8** for merge gates even when a blog or older doc suggests otherwise.

- **(required)** [npm: eslint-plugin-react-hooks](https://www.npmjs.com/package/eslint-plugin-react-hooks) — `recommended` vs `recommended-latest`, flat config snippets.
- **(required)** [CHANGELOG (react package)](https://github.com/facebook/react/blob/main/packages/eslint-plugin-react-hooks/CHANGELOG.md) — breaking preset changes (e.g. v7.0.0 config slimming).
- **(required)** [React: ESLint plugin overview](https://react.dev/reference/eslint-plugin-react-hooks) — recommended rules list + philosophy.
- **(required)** Per-rule docs: `https://react.dev/reference/eslint-plugin-react-hooks/lints/<rule-name>`
- **(required)** [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
- **(required)** [set-state-in-effect discussion](https://github.com/facebook/react/issues/34743)
- **(required)** Peer / canary context for this monorepo: [eslint10-react-hooks-peer-yarn-agent-prompt.md](./eslint10-react-hooks-peer-yarn-agent-prompt.md), `fe_demo/docs/eslint-plugin-react-hooks-peer.md`, `admin_demo/docs/eslint-plugin-react-hooks-peer.md`
- **(required)** [React Compiler — Installation](https://react.dev/learn/react-compiler/installation) — ESLint plugin vs **`eslint-plugin-react-hooks`** (**§1.3**).
- **(required)** [npm: `eslint-plugin-react-compiler`](https://www.npmjs.com/package/eslint-plugin-react-compiler)

---

## 10. Author hints (**required** when applicable — not a substitute for **§4** / **react.dev**)

1. **(required)** **Prefer `warn` → `error` escalations** for rules that touch >20 files; it keeps CI mergeable and still surfaces in editors.
2. **(required)** **Group refactors by _cause_** (all “derive instead of effect-sync” together) rather than by folder — reviewers learn the pattern once.
3. **(required)** **`useLayoutEffect`** is not “escape hatch for all DOM” — use only when **`useEffect` causes visible flicker** and document why ([React docs on useLayoutEffect](https://react.dev/reference/react/useLayoutEffect)).
4. **(required)** **TanStack Query:** prefer **`isLoading` / `data` from query** over duplicating that state in `useState` + `useEffect`.
5. **(required)** **Tables (`useReactTable`):** memoize **column defs** and **data** references; avoid recreating columns inline in render when enabling compiler rules.
6. **(required)** **`react-refresh/only-export-components`:** contexts folder may stay special-cased — do not break the existing `eslint.config.js` second block when editing hooks rules.
7. **(required)** **Cypress / e2e:** if lint config `ignores` cypress, ensure new rules do not accidentally apply to files that should stay excluded.
8. **(required)** After full preset adoption, **re-evaluate** whether any **`eslint-disable-next-line react-hooks/incompatible-library`** added earlier are still needed (admin demo removed some when rules were off — they may return under full preset).
9. **(required)** **`recommended-latest`:** treat as **volatile**; pin plugin version already exact in this repo — still re-run **§3.2** (preset dump) on every bump (**§5.4**).
10. **(required)** If the team hits a **dead end** on a rule (plugin false positive), open an **upstream issue** with minimal repro before permanent disable.
