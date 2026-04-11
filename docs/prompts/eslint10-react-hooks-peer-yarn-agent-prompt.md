# ESLint 10 × `eslint-plugin-react-hooks` peer mismatch — investigation & fix (agent prompt)

**Purpose:** Remove **Yarn peer-resolution warnings** (and future hard failures) in **`fe_demo`** and **`admin_demo`** after upgrading to **ESLint 10**, while keeping **`eslint-plugin-react-hooks`** and the **flat config** (`eslint.config.js`) working. Use this document as a **copy-paste agent brief**: investigate, pick a strategy, implement in **both** SPAs, run **`yarn validate`** / **`yarn test`** / **`yarn build`**, commit in **submodule repos**, bump parent submodule pointers if needed.

**Scope:** `fe_demo`, `admin_demo` (Yarn **4.12**). Out of scope: `be_demo` (dotnet), `ai_demo` (Python).

---

## 1. Background (why this exists)

- **`typescript-eslint`** (e.g. **8.58.x**) declares `peerDependencies.eslint` including **`^10.0.0`** — aligned with ESLint 10.
- **`eslint-plugin-react-hooks`** (stable **7.0.1** and current **canary** lines checked **2026-04-11**) still declare:
  - `eslint: '^3.0.0 || ^4.0.0 || … || ^8.0.0-0 || ^9.0.0'`
  - i.e. **no `^10.0.0`** in the published peer range.
- **Yarn Berry** (`yarn install`) reports **`YN0060`** / **`YN0086`** when the workspace pins **ESLint 10** but a plugin’s **declared** peer range does not include 10. Install may still succeed; **lint can work** in practice because the plugin often runs on ESLint 10 APIs — but the graph is **officially inconsistent** and may break on the next Yarn or plugin release.

**Repos today (baseline):** both apps use roughly:

- `eslint`: **^10.2.0**
- `@eslint/js`: **^10.0.1**
- `eslint-plugin-react-hooks`: **^7.0.1**
- `typescript-eslint`: **^8.58.x**
- Flat config imports: `eslint-plugin-react-hooks` → `reactHooks.configs.flat.recommended` (see `fe_demo/eslint.config.js`; mirror in `admin_demo` if present).

---

## 2. Investigation checklist (agent must run and record)

Run from **monorepo root** unless noted. Capture **stdout** for the PR or paste into the task comment.

### 2.1 Reproduce Yarn peer diagnostics

```bash
cd fe_demo && yarn install --immutable 2>&1 | tee /tmp/yarn-fe-peer.txt
cd ../admin_demo && yarn install --immutable 2>&1 | tee /tmp/yarn-admin-peer.txt
```

- Note **`YN0060`** lines naming **`eslint`** vs **`eslint-plugin-react-hooks`** (and any other peers).
- For each hash Yarn prints, run:
  - `yarn explain peer-requirements <pXXXXXX>` (optional; clarifies which package imposes which peer).

### 2.2 Confirm registry metadata (npm)

```bash
npm view eslint@version
npm view eslint-plugin-react-hooks@version peerDependencies
npm view typescript-eslint@8.58.1 peerDependencies
```

- Record whether **`eslint-plugin-react-hooks@latest`** (or chosen canary) **still** omits `^10.0.0` in `peerDependencies.eslint`.
- If a **newer** `eslint-plugin-react-hooks` appears with `^10` in peers, **prefer upgrading the plugin** over `packageExtensions` (see §4.1).

### 2.3 Confirm ESLint actually runs on ESLint 10

```bash
cd fe_demo && yarn lint 2>&1 | tail -30
cd ../admin_demo && yarn lint 2>&1 | tail -30
```

- If rules crash (e.g. unknown rule API), capture stack trace — may force **Strategy B** (pin ESLint 9) until upstream fixes.

### 2.4 Full SPA gates

```bash
cd fe_demo && yarn validate && yarn test && yarn build
cd ../admin_demo && yarn validate && yarn test && yarn build
```

---

## 3. Root cause summary (for the PR description)

| Layer                             | Finding                                                                                                                                  |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **typescript-eslint 8.x**         | Supports **ESLint 8 / 9 / 10** per its `peerDependencies`.                                                                               |
| **eslint-plugin-react-hooks 7.x** | Published **peer** range ends at **ESLint 9**; **ESLint 10** is outside declared compatibility.                                          |
| **Yarn 4**                        | Strict peer reporting → **warnings** today; risk of **errors** if policy tightens or a plugin version narrows peers.                     |
| **Runtime**                       | Hooks plugin often **works** on ESLint 10 despite peers — but that is **unsupported** until the React team updates `package.json` peers. |

---

## 4. Solution strategies (pick one per PR; document the choice)

### 4.1 Strategy A — **Upgrade `eslint-plugin-react-hooks`** (first choice)

- **When:** `npm view eslint-plugin-react-hooks peerDependencies` shows **`^10.0.0`** (or equivalent) for a stable version you are willing to ship.
- **Action:** Bump `eslint-plugin-react-hooks` in **`fe_demo/package.json`** and **`admin_demo/package.json`**, `yarn install`, re-run §2.4.
- **Pros:** No Yarn overrides; **supported** graph. **Cons:** Depends on upstream release schedule.

### 4.2 Strategy B — **Pin ESLint to 9.x** (conservative)

- **When:** Team wants **zero** peer skew; can accept staying on ESLint 9 until react-hooks declares 10.
- **Action:** Set `eslint` to **^9.57** (or latest 9.x), align **`@eslint/js`** to the **9.x** line per ESLint docs, align **`typescript-eslint`** to a version that still supports ESLint 9 (check its peer range for the chosen minor). Re-run NCU cautiously.
- **Pros:** Matches **all** current plugin peers. **Cons:** Gives up ESLint **10**-specific features and changelog; may need to revisit later.

### 4.3 Strategy C — **Yarn `packageExtensions`** (pragmatic bridge)

- **When:** You want to **keep ESLint 10** now, and **Strategy A** is not available yet.
- **Action:** In **each** SPA repo, add to **`.yarnrc.yml`** (create if missing):

```yaml
packageExtensions:
  eslint-plugin-react-hooks@*:
    peerDependencies:
      eslint: ">=9.0.0 <11.0.0"
```

- Tweak the range if you prefer exactly `^9.0.0 || ^10.0.0` instead of a band.
- **Pros:** Clears **YN0060** for this mismatch; keeps ESLint 10. **Cons:** **Overrides upstream’s declared contract** — add a **comment in `.yarnrc.yml`** and a **calendar follow-up** (issue) to remove the extension when **Strategy A** lands.
- **Risk:** If the plugin truly breaks on ESLint 10 in a future release, CI will not warn via peers — **§2.3** / **§2.4** are mandatory.

**Do not** combine B and C without reason (pick one primary strategy).

---

## 5. Implementation steps (after strategy choice)

1. Apply changes in **`fe_demo`**; run **`yarn install`** (immutable in CI; locally may use `yarn install` to refresh lockfile).
2. Mirror the **same** policy in **`admin_demo`** (same `eslint` / `@eslint/js` / extensions / lockfile discipline).
3. Run **`yarn validate`**, **`yarn test`**, **`yarn build`** in both.
4. If **`packageExtensions`** used: add **one paragraph** to `fe_demo` / `admin_demo` **README** or internal **`docs/`** (submodule) explaining why it exists and when to remove it — or a `//` block comment above the YAML key if your team allows comments in `.yarnrc.yml`.
5. **Commit** in **`fe_demo`** and **`admin_demo`** (separate commits or one PR per repo, per team rules).
6. Parent **`_mfai_demo`:** update **submodule SHAs** if your release process requires it.

---

## 6. Verification & CI

- Local: §2.4 must be **green**.
- **GitHub Actions:** jobs `fe_demo` / `admin_demo` already run `yarn install --immutable`, `yarn validate`, `yarn test`, `yarn build` — ensure **no new peer warnings** are treated as errors (if you later set `enableStrictSsl` / peer policies, re-verify).
- Optional: grep CI logs for `YN0060` / `YN0086` before vs after.

---

## 7. Deliverables

- [ ] Investigation notes (§2) attached to PR or issue.
- [ ] Chosen strategy (A / B / C) documented in PR description with **one-sentence** rationale.
- [ ] **`fe_demo`** + **`admin_demo`** updated consistently; **`yarn.lock`** committed.
- [ ] **`yarn validate` / `yarn test` / `yarn build`** green in both.
- [ ] If Strategy C: follow-up **issue ID** or dated note to remove `packageExtensions` when react-hooks supports ESLint 10 in peers.

---

## 8. References (for the agent)

- Yarn **`packageExtensions`:** [Yarn docs — `packageExtensions`](https://yarnpkg.com/configuration/yarnrc#packageExtensions)
- ESLint **flat config** (`eslint.config.js`) in repo: `fe_demo/eslint.config.js`
- Related monorepo audit: [monorepo-dependency-audit-and-upgrade-agent-prompt.md](./monorepo-dependency-audit-and-upgrade-agent-prompt.md) (toolchain / NCU context)
