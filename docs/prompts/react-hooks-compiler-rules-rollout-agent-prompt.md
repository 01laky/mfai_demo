# React Hooks plugin — full `recommended` / compiler rules rollout (agent prompt)

**Purpose:** Move **`fe_demo`** and **`admin_demo`** from the **minimal** ESLint hooks surface (`react-hooks/rules-of-hooks` + `react-hooks/exhaustive-deps` only) toward the **full** `eslint-plugin-react-hooks` **`flat.recommended`** (or **`flat['recommended-latest']`**) preset **safely**, in controlled phases, with measurable violation counts, refactors, and green **`yarn validate` / `yarn test` / `yarn build`**. Use this document as a **copy-paste agent brief**.

**Scope:** `fe_demo`, `admin_demo` only (Yarn 4, ESLint 10, flat config). Out of scope: `be_demo`, `ai_demo`, changing the **canary vs stable** pin for `eslint-plugin-react-hooks` unless a separate task explicitly upgrades peers (see [eslint10-react-hooks-peer-yarn-agent-prompt.md](./eslint10-react-hooks-peer-yarn-agent-prompt.md)).

**Prerequisite context (repo today):** Both SPAs pin an **exact** `eslint-plugin-react-hooks` **canary** for ESLint **10** peer alignment; `eslint.config.js` registers the plugin but **does not** extend `reactHooks.configs.flat.recommended`, because that preset enables **many** React Compiler–oriented rules at once (e.g. `react-hooks/set-state-in-effect`), which previously produced **dozens** of errors on this codebase. This prompt is the **migration path** from that intentional subset to full coverage.

---

## 1. Why this migration exists (product + upstream)

### 1.1 What upstream ships today (verify on your run day)

From **`eslint-plugin-react-hooks` v7.x** ([npm readme](https://www.npmjs.com/package/eslint-plugin-react-hooks), [CHANGELOG 7.0.0](https://github.com/facebook/react/blob/main/packages/eslint-plugin-react-hooks/CHANGELOG.md)):

- **`recommended`** (flat: `reactHooks.configs.flat.recommended`) bundles **Rules of Hooks** plus **React Compiler–aligned** lint rules (not only `rules-of-hooks` + `exhaustive-deps`).
- **`recommended-latest`** (flat: `reactHooks.configs.flat['recommended-latest']`) is described on npm as **bleeding-edge** experimental compiler rules on top of `recommended` — use only when the team explicitly wants **latest** compiler diagnostics.

The React docs describe the **compiler rules** family and the philosophy of **gradual** cleanup: [ESLint Plugin React Hooks — recommended rules](https://react.dev/reference/eslint-plugin-react-hooks#recommended-rules) (same content structure as `beta.reactjs.org` reference pages).

**Agent rule:** Do **not** assume rule names or severities from memory. **(required)** For the **resolved** `eslint-plugin-react-hooks` version in each SPA, dump the preset’s rule table (see §3.1) and treat that as the source of truth for the PR.

### 1.2 Relationship to React Compiler

These rules surface patterns the **React Compiler** may flag or optimize around. The React team’s framing: you do **not** need to fix every violation immediately to ship; tightening lint is a **progressive** quality investment ([same reference section](https://react.dev/reference/eslint-plugin-react-hooks#recommended-rules)).

---

## 2. Strategy matrix (pick one primary approach per PR series)

Document the chosen row in the PR description.

| Approach                                              | When to use                                            | Shape of work                                                                                                                                       |
| ----------------------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **S1 — Big-bang preset**                              | Small codebase or few violations after a spike         | Flip config to `reactHooks.configs.flat.recommended` (or `recommended-latest`), fix all errors in one or few commits.                               |
| **S2 — Rule-by-rule** (**default** for this monorepo) | Many violations; need reviewable PRs                   | Enable **one** new rule at a time (start **`warn`**, then **`error`**), merge, repeat. Optionally group related rules (e.g. purity + immutability). |
| **S3 — Path-scoped rollout**                          | Violations concentrated in modules (e.g. `src/pages/`) | Base config uses full preset; **`files`/`ignores`** overrides downgrade or disable specific rules in legacy folders until cleaned.                  |
| **S4 — Preset + selective disables**                  | Third-party patterns (tables, forms) need time         | Keep preset; **narrow** `eslint-disable-next-line` with **ticket ID** + **owner** (forbidden: file-wide disable of `react-hooks/*`).                |

**Forbidden:** `eslint-disable` entire files for `react-hooks/*` without a linked issue and removal date. **Forbidden:** lowering `exhaustive-deps` to `off` “to unblock” the compiler rollout (fix deps or use documented `additionalHooks` / ref patterns).

---

## 3. Investigation (**required** before edits)

### 3.1 Dump rules from the **installed** preset (**required**)

From each SPA root:

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

### 3.2 Baseline violation counts (**required**)

**(required)** On a **throwaway branch** or locally (do not merge with thousands of unfixed errors):

1. Temporarily switch config to the target preset (see §5 template).
2. Run:

```bash
yarn lint 2>&1 | tee /tmp/eslint-full-react-hooks.txt
```

**(required)** Produce a **table**: rule id → error count (parse from ESLint output or run `eslint . -f json` and aggregate with a small script). This table drives **S2** ordering (fix highest-signal or highest-count first, depending on team policy).

### 3.3 Map hotspots (**required**)

**(required)** From the JSON or text report, list **top 10 files** by violation count for the **first** rule you plan to enable. This prevents random file hopping.

---

## 4. Rule-by-rule remediation playbook (hints + web anchors)

Use the official lint reference pages under **`https://react.dev/reference/eslint-plugin-react-hooks/lints/`** (replace `set-state-in-effect` in the path with the rule slug). Below: **practical** patterns that recur in SPAs like this monorepo.

### 4.1 `react-hooks/set-state-in-effect` (usually the largest bucket)

- **Official:** [set-state-in-effect](https://react.dev/reference/eslint-plugin-react-hooks/lints/set-state-in-effect) — synchronous `setState` inside `useEffect` forces extra render passes; prefer **deriving during render**, **event handlers**, **`useLayoutEffect` + DOM measurement**, or **async** flows where the setState is not synchronous in the effect body’s first tick.
- **React guide:** [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — loading flags driven only by props/data, “sync state to props” anti-patterns, fetching with race handling (prefer **TanStack Query** patterns already in the repo).
- **Known friction:** [facebook/react#34743](https://github.com/facebook/react/issues/34743) — community discussion on “overly strict” cases (`mounted` / `isClient` patterns). **Do not** dismiss the rule repo-wide; prefer **documented** refactors (e.g. `useSyncExternalStore` for hydration/client-only UI where appropriate — see issue discussion and React docs).

**Hints (implementation):**

- **Data fetching:** If `useEffect` + `setState` loads server data, migrate toward **`useQuery`** / **`useMutation`** with stable keys so effects do not duplicate client cache state.
- **Derived lists:** `setItems(data?.items ?? [])` in an effect → usually **`const items = data?.items ?? []`** (or `useMemo` only if expensive).
- **“Reset when id changes”:** Prefer **`key={id}`** on child component or compare during render / reset in the **same** effect using a pattern from React docs instead of unconditional synchronous sets scattered across effects.

### 4.2 `react-hooks/set-state-in-render`

- **Official:** [set-state-in-render](https://react.dev/reference/eslint-plugin-react-hooks/lints/set-state-in-render) — unconditional setState during render → infinite loops; **conditional** updates tied to previous render have a documented pattern.

### 4.3 `react-hooks/exhaustive-deps` (already `warn` — tighten carefully)

- Do **not** “fix” by blindly adding unstable function references; use **`useCallback`**, **move functions inside `useEffect`**, or **extract** stable helpers.
- For intentional omissions, use **inline comment** with **reason** (not empty eslint-disable). Prefer `additionalHooks` / `settings` from plugin docs when effect-like hooks are custom ([rules-of-hooks options](https://react.dev/reference/eslint-plugin-react-hooks/lints/rules-of-hooks#options)).

### 4.4 `react-hooks/incompatible-library` (admin tables, third-party)

- **Official:** [incompatible-library](https://react.dev/reference/eslint-plugin-react-hooks/lints/incompatible-library) — libraries that fight memoization/compiler assumptions.
- **Practical:** `@tanstack/react-table` + hooks often triggers warnings; fixes may be **upgrading** table major, **wrapping** table instance creation in `useMemo`, or **scoped** disable on the **single** line that creates the table with a ticket reference.

### 4.5 `react-hooks/refs` / `react-hooks/static-components` / `react-hooks/purity` / `react-hooks/immutability`

- Prefer **stable component definitions** (no inline `function Child()` inside render).
- Avoid **mutating props** or shared module-level objects during render.
- **Refs:** read/write timing must match React’s expectations (no ref reads for rendering decisions unless pattern is documented safe).

### 4.6 `react-hooks/unsupported-syntax` (often `warn`)

- Track **parser** / syntax features incompatible with compiler analysis; may require **refactor** (e.g. certain patterns in HOCs) or waiting on plugin updates.

### 4.7 `react-hooks/use-memo`, `preserve-manual-memoization`, `globals`, `gating`, `config`, `error-boundaries`, `component-hook-factories`

- Treat as **compiler hygiene**; fix together with team **performance** goals. When unsure, enable at **`warn`** first and collect signal.

### 4.8 Optional cross-check: community plugins

- **`@eslint-react/eslint-plugin`** documents overlapping concepts (e.g. hooks-extra rules). Use **only** as reading material unless the team explicitly adds another plugin — avoid duplicate conflicting rules ([example rule doc](https://eslint-react.xyz/docs/rules/hooks-extra-no-direct-set-state-in-use-effect)).

---

## 5. ESLint config mechanics (flat config)

### 5.1 Merge order (**required**)

When introducing `reactHooks.configs.flat.recommended`:

- Keep **`eslint-config-prettier` last** in the `extends` / flat array so it can override formatting conflicts.
- Ensure **`typescript-eslint`** configs and **`eslint-plugin-react-refresh`** remain compatible; re-run `yarn lint` after reordering.

### 5.2 Example: **S2** single-rule overlay (**required pattern**)

Keep the repo’s current explicit plugin registration **or** switch to `extends: [..., reactHooks.configs.flat.recommended]` **and** override one rule:

```js
// Illustrative — adapt to defineConfig([...]) structure in repo
{
  files: ['**/*.{ts,tsx}'],
  rules: {
    'react-hooks/set-state-in-effect': 'warn',
  },
}
```

### 5.3 Example: **S3** path override

```js
{
  files: ['src/legacy/**/*.{ts,tsx}'],
  rules: {
    'react-hooks/set-state-in-effect': 'off', // TRACK-123: remove by 20YY-MM-DD
  },
}
```

**(required)** Any `off` override must carry **`TRACK-*` / issue URL** and a **removal deadline** in the same PR or linked issue body.

---

## 6. Implementation workflow (**required**)

1. **(required)** Complete §3 investigations for **both** SPAs; attach tables.
2. **(required)** Choose **S1–S4** (series may use **S2** then converge to full preset).
3. **(required)** Implement in **`fe_demo`**, run **`yarn lint` → `yarn validate` → `yarn test` → `yarn build`**.
4. **(required)** Mirror in **`admin_demo`** (same rule set and severities unless a **documented** SPA-specific exception exists).
5. **(required)** Update **`docs/guides/development.md`** subsection on hooks if the **default** preset for new code changes.
6. **(required)** Submodule commits + parent pointer bump per team rules.

---

## 7. Verification (**required**)

- [ ] **`yarn lint`** with **zero errors** (warnings policy: align with CI — if CI uses `--max-warnings 0`, **zero warnings** too).
- [ ] **`yarn validate`**, **`yarn test`**, **`yarn build`** in **both** SPAs.
- [ ] No new **blanket** `eslint-disable` for `react-hooks/*`.
- [ ] **Preset dump** (§3.1) attached for the version you shipped.

---

## 8. Deliverables (**required**)

- [ ] PR description states **S1–S4** choice and **rule rollout order** (for **S2**).
- [ ] Baseline vs final violation table (or “N/A — S1 big-bang”).
- [ ] Links to **react.dev** rule pages for the top 3 rules touched.
- [ ] Screenshots or notes only if UI behavior changed (most PRs will not need them).

---

## 9. References (bookmark for the agent)

- [npm: eslint-plugin-react-hooks](https://www.npmjs.com/package/eslint-plugin-react-hooks) — `recommended` vs `recommended-latest`, flat config snippets.
- [CHANGELOG (react package)](https://github.com/facebook/react/blob/main/packages/eslint-plugin-react-hooks/CHANGELOG.md) — breaking preset changes (e.g. v7.0.0 config slimming).
- [React: ESLint plugin overview](https://react.dev/reference/eslint-plugin-react-hooks) — recommended rules list + philosophy.
- Per-rule docs: `https://react.dev/reference/eslint-plugin-react-hooks/lints/<rule-name>`
- [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
- [set-state-in-effect discussion](https://github.com/facebook/react/issues/34743)
- Peer / canary context for this monorepo: [eslint10-react-hooks-peer-yarn-agent-prompt.md](./eslint10-react-hooks-peer-yarn-agent-prompt.md), `fe_demo/docs/eslint-plugin-react-hooks-peer.md`, `admin_demo/docs/eslint-plugin-react-hooks-peer.md`

---

## 10. Author hints (experience notes — not a substitute for docs)

1. **Prefer `warn` → `error` escalations** for rules that touch >20 files; it keeps CI mergeable and still surfaces in editors.
2. **Group refactors by _cause_** (all “derive instead of effect-sync” together) rather than by folder — reviewers learn the pattern once.
3. **`useLayoutEffect`** is not “escape hatch for all DOM” — use only when **`useEffect` causes visible flicker** and document why ([React docs on useLayoutEffect](https://react.dev/reference/react/useLayoutEffect)).
4. **TanStack Query:** prefer **`isLoading` / `data` from query** over duplicating that state in `useState` + `useEffect`.
5. **Tables (`useReactTable`):** memoize **column defs** and **data** references; avoid recreating columns inline in render when enabling compiler rules.
6. **`react-refresh/only-export-components`:** contexts folder may stay special-cased — do not break the existing `eslint.config.js` second block when editing hooks rules.
7. **Cypress / e2e:** if lint config `ignores` cypress, ensure new rules do not accidentally apply to files that should stay excluded.
8. After full preset adoption, **re-evaluate** whether any **`eslint-disable-next-line react-hooks/incompatible-library`** added earlier are still needed (admin demo removed some when rules were off — they may return under full preset).
9. **`recommended-latest`:** treat as **volatile**; pin plugin version already exact in this repo — still re-run §3.1 on every bump.
10. If the team hits a **dead end** on a rule (plugin false positive), open an **upstream issue** with minimal repro before permanent disable.
