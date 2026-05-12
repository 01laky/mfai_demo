# ESLint 10 × `eslint-plugin-react-hooks` peer mismatch — investigation & fix (agent prompt)

**Purpose:** Remove **Yarn peer-resolution warnings** (and future hard failures) in **`fe_demo`** and **`admin_demo`** after upgrading to **ESLint 10**, while keeping **`eslint-plugin-react-hooks`** and the **flat config** working. Use this document as a **copy-paste agent brief**: investigate, pick a strategy, implement in **both** SPAs, run **`yarn validate`** / **`yarn test`** / **`yarn build`**, commit in **submodule repos**, bump parent submodule pointers per team rules.

**Checklists:** The `[ ]` rows in **§7** (and similar) are **PR / audit evidence templates**—tick in the PR or issue, not by default in this canonical file ([docs/prompts/README.md](./README.md)).

**Scope:** `fe_demo`, `admin_demo` (Yarn **4.12**). Out of scope: `be_demo` (dotnet), `ai_demo` (Python).

---

## 0. Compliance (**required** — entire document)

- The agent **must** treat **§§0–8** as normative: **every** subsection, bullet, table, command block, strategy rule, **§7** checklist row, and **§8** link rule applies. **Nothing in this prompt is optional.**
- Where this file shows **(required)**, that repeats the global rule for emphasis at the point of work.
- Skipping any step is a **failed** run.
- If registry or lockfile state **differs** from examples (new stable release, renamed presets, new Yarn codes), **(required)** document the **actual versions and outputs** you observed and still complete the **same decision process** (matrix §1.1, strategies §4).

---

## 1. Background (why this exists)

- **`typescript-eslint`** (e.g. **8.58.x**) declares `peerDependencies.eslint` including **`^10.0.0`** — aligned with ESLint 10 (verify with **`npm view`** using the range from each SPA’s `package.json` — §2.2).
- **`eslint-plugin-react-hooks`:**
  - **`@latest`** (e.g. **7.0.1**): `peerDependencies.eslint` historically ends at **`^9.0.0`** — **no** declared **`^10.0.0`**. That produces Yarn **`YN0060`** / **`YN0086`** when the workspace uses ESLint 10.
  - **`@canary`**: upstream has merged **ESLint 10** into the plugin’s declared peer range; **`npm view eslint-plugin-react-hooks@canary peerDependencies`** is part of §2.2 — the canary line **may** include **`|| ^10.0.0`** while stable lags (**(required)** confirm on the day of the run, not from memory).
- **Yarn Berry** (`yarn install`) reports peer diagnostics when the **declared** peer graph disagrees with the resolved tree. Install can still succeed; **lint can still run** — the graph remains **officially inconsistent** until versions align, and CI or a future Yarn/plugin release **can** harden behavior.

**Upstream (**required** reading for PR context — cite in investigation notes):**

- React issue: [facebook/react#35758 — ESLint 10 not in `eslint-plugin-react-hooks` peers](https://github.com/facebook/react/issues/35758)
- Landed fix (peer + tests/fixtures): [facebook/react#35720 — Add ESLint v10 support](https://github.com/facebook/react/pull/35720) (merge subject **can** differ; **published** tags are decided by **`npm view`**, not by PR title alone).

**Repos today (`fe_demo` / `admin_demo` — verify with each `package.json` and §2.2):** ESLint **10**, `@eslint/js` **^10.0.x**, `typescript-eslint` **^8.58.x**, and an **exact** **`eslint-plugin-react-hooks` canary** pin (**strategy A2** shipped in submodules) until stable `@latest` lists **`^10.0.0`** for `eslint` in peers. Submodule rationale: `docs/eslint-plugin-react-hooks-peer.md` in each SPA.

- Flat config **can** live in `eslint.config.js`, `eslint.config.mjs`, `eslint.config.cjs`, `eslint.config.ts`, `eslint.config.mts`, or `eslint.config.cts` — **(required)** apply **§2.6** to **whichever filename exists** in each SPA. **(required)** After any `eslint-plugin-react-hooks` version change, align plugin registration and rules with that version’s published API — **§2.6** (today: explicit **`rules-of-hooks`** + **`exhaustive-deps`** instead of full canary `flat.recommended`).

---

## 1.1 Strategy decision matrix (**required**)

**(required)** Pick **exactly one primary** strategy for the PR (**A1**, **A2**, **B**, or **C**). **(required)** Document the chosen cell in the PR description (minimum **one sentence**) and attach **all** investigation outputs from §2.

| Situation                                                                                                                                                        | Primary strategy            | Notes                                                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm view eslint-plugin-react-hooks@latest peerDependencies` includes **`^10.0.0`** (or equivalent) for a **stable** version the team ships                      | **A1 — stable upgrade**     | Bump to that stable in **both** SPAs; no Yarn `packageExtensions`.                                                                                                                                                                                                          |
| Stable **does not** include ESLint 10 **but** `npm view eslint-plugin-react-hooks@canary peerDependencies` does, and the team ships canary on the lint toolchain | **A2 — canary bridge**      | **(required)** Pin **exact** canary version (no `^` / `~`, no floating `canary` tag range). **(required)** PR text per §4.1.2. **Do not** combine with **C** for the same gap unless §4.4 exception applies.                                                                |
| Team refuses canary **and** refuses `packageExtensions`, and needs a clean peer graph **now**                                                                    | **B — pin ESLint 9**        | **(required)** Align `eslint`, `@eslint/js`, `typescript-eslint` per `npm view` peers. **(required)** Verify no ESLint-10-only reliance — §4.2.                                                                                                                             |
| Team keeps ESLint 10, stable has no `^10` peer, **A2** is rejected (policy), **`packageExtensions` are allowed**                                                 | **C — `packageExtensions`** | **(required)** Version-scoped extension per §4.3; follow-up issue; **§§2.6–2.8** (flat config, **`yarn lint`**, full gates) **must** pass.                                                                                                                                  |
| Team keeps ESLint 10, **both** `@latest` and `@canary` lack ESLint 10 in peers **on the run day**, **A2** and **C** are both rejected                            | **Escalation — stop**       | **(required)** Do **not** fake peers. **(required)** PR or issue documents the blocker (paste §2.2 outputs), pick **B** after stakeholder decision **or** wait for upstream/canary policy change. **(required)** Do not merge a broken peer graph while claiming ESLint 10. |

**Matrix coverage rule (**required**):** If no row matches exactly, **(required)** treat that as **Escalation — stop** until stakeholders assign **B**, **C**, or **A2** policy in writing in the PR thread.

---

## 2. Investigation checklist (**required** — run and record)

**(required)** Run from **monorepo root** unless a step says `cd` into a SPA. **(required)** Save **every** command’s stdout/stderr for the PR or task attachment (files under `/tmp/` or CI artifacts are fine).

### 2.1 Reproduce Yarn peer diagnostics (**required**)

```bash
cd fe_demo && yarn install --immutable 2>&1 | tee /tmp/yarn-fe-peer.txt
cd ../admin_demo && yarn install --immutable 2>&1 | tee /tmp/yarn-admin-peer.txt
```

**(required)** In **both** log files, search and record:

- **Every** line containing **`YN0060`**, **`YN0086`**, **or** any other **`YN00xx`** line the Yarn release prints that refers to **peer** / **peerDependencies** / “incorrectly met” (copy the **exact** code Yarn emitted).
- **(required)** One summary table in the PR: **Yarn code → requesting package → requested peer → subject package** (as far as the log line exposes).

**(required)** Explain peer requirements:

1. **(required)** Run `yarn explain peer-requirements` **with no hash** from each SPA root after the failing install. **(required)** If the command errors or prints nothing useful, **(required)** state that fact verbatim in the PR.
2. **(required)** For **each** hash printed beside a peer warning or failure line, run `yarn explain peer-requirements <pXXXXXX>` from the **same** SPA root:

```bash
yarn explain peer-requirements <pXXXXXX>
```

**(required)** Attach the **full** stdout for **each** hash (complete tree, not the first line). **(required)** Conclude whether **only** `eslint-plugin-react-hooks` is involved or **other** packages mis-declare `eslint` for v10.

### 2.2 Confirm registry metadata — hooks, ESLint, typescript-eslint (**required**)

**Do not** use the invalid literal `npm view eslint@version`. **(required)** Use the **semver range strings** from each SPA’s `package.json` inside quoted `npm view` selectors.

**(required)** From **`fe_demo`** (repeat the entire block from **`admin_demo`**):

```bash
cd fe_demo
npm view eslint-plugin-react-hooks@latest version peerDependencies
npm view eslint-plugin-react-hooks@canary version peerDependencies
ESLINT_RANGE=$(node -p "require('./package.json').devDependencies.eslint || require('./package.json').dependencies?.eslint || ''")
TS_ESLINT_RANGE=$(node -p "require('./package.json').devDependencies['typescript-eslint'] || require('./package.json').dependencies?.['typescript-eslint'] || ''")
npm view "eslint@${ESLINT_RANGE}" version peerDependencies
npm view "typescript-eslint@${TS_ESLINT_RANGE}" peerDependencies
```

**(required)** If `ESLINT_RANGE` or `TS_ESLINT_RANGE` is empty, **(required)** stop and document the missing key; **(required)** fix `package.json` in that SPA before continuing.

**(required)** Record in prose in the PR:

- Whether **`@latest`** includes **`^10.0.0`** (or equivalent) in `peerDependencies.eslint`.
- Whether **`@canary`** includes **`^10.0.0`** (or equivalent).
- **Exact** version strings returned for `@latest` and `@canary` on the run day.

**Rule (**required**):** If **`@latest`** already includes ESLint 10 in peers, **(required)** implement **A1** before **A2** or **C**.

### 2.3 Scan the whole ESLint peer graph in both SPAs (**required**)

**(required)** For **`fe_demo/package.json`** and **`admin_demo/package.json`**:

1. **(required)** List **every** `devDependency` and **`dependency`** whose **name** is `eslint`, starts with `@eslint/`, equals `typescript-eslint`, starts with `@typescript-eslint/`, **contains** the substring `eslint-plugin`, or matches `eslint-config-*`.
2. **(required)** For **each** listed package that declares or inherits a peer on `eslint`, run `npm view` for its **workspace range**:

```bash
npm view "<pkg>@<range-from-package.json>" peerDependencies
```

**(required)** For **scoped** package names (`@scope/name`), **(required)** keep the **double quotes** around the `package@range` argument so the shell does not strip `@`.

**(required)** List **every** package (including but not limited to `eslint-plugin-react-hooks`) whose peer range **excludes** ESLint **10** while the SPA pins ESLint 10. **(required)** Plan upgrades or the **same** matrix strategy class for **each** — **(required)** do not silence only `react-hooks` while another package still triggers **`YN0060`**.

### 2.4 Yarn linker / mode record (**required**)

**(required)** In **each** SPA, open **`.yarnrc.yml`** (or confirm absence). **(required)** Record in the PR: `nodeLinker`, `pnpMode`, and **any** key containing `peer` (verbatim key names and values if present). **(required)** One sentence stating how that setting relates to install strictness for this investigation (PnP vs `node-modules`).

### 2.5 Lockfile sanity — single effective `eslint` (**required**)

**(required)** After `yarn install` in each SPA:

- **(required)** Run `yarn why eslint` from that SPA root **or** grep `yarn.lock` for `eslint@npm:`; **(required)** record **how many** distinct resolved `eslint` versions appear and **why** (duplicate majors are a **red flag** — document).
- **(required)** Branch A — If this repo’s documented maintenance process **includes** a dedupe step (README, `package.json` script, or internal docs), **(required)** run that **exact** command and **(required)** attach the lockfile diff summary.
- **(required)** Branch B — If there is **no** documented dedupe step, **(required)** do **not** invent a new dedupe habit in this PR; **(required)** document duplicate `eslint` instances and whether they are intentional.

### 2.6 Flat config alignment after `eslint-plugin-react-hooks` changes (**required**)

**Triggers (**required**):** Whenever `eslint-plugin-react-hooks` **resolved version** changes (strategies **A1**, **A2**, **C** with bump, or transitive resolution change).

**(required)** In **both** SPAs:

1. **(required)** Open every flat config file that exists: `eslint.config.js`, `eslint.config.mjs`, `eslint.config.cjs`, `eslint.config.ts`, `eslint.config.mts`, `eslint.config.cts`.
2. **(required)** Compare imports and presets to the **npm readme for the resolved version** of `eslint-plugin-react-hooks` ([npm package page](https://www.npmjs.com/package/eslint-plugin-react-hooks)).
3. **(required)** Update the config so presets and exports match that version’s API.
4. **(required)** Run **`yarn lint`** (§2.7) and prove **zero** config import errors.

### 2.7 Confirm ESLint runs (**required**)

```bash
cd fe_demo && yarn lint 2>&1 | tee /tmp/yarn-fe-lint.txt
cd ../admin_demo && yarn lint 2>&1 | tee /tmp/yarn-admin-lint.txt
```

**(required)** If a rule or engine crashes, **(required)** capture the **full** stack trace and **(required)** either pivot to **B** or adjust plugin versions per matrix — **(required)** do not merge green `yarn install` with red **`yarn lint`**.

### 2.8 Full SPA gates (**required**)

```bash
cd fe_demo && yarn validate && yarn test && yarn build
cd ../admin_demo && yarn validate && yarn test && yarn build
```

---

## 3. Root cause summary (**required** for the PR description)

**(required)** Copy the table below into the PR. **(required)** Adjust cell wording only where §2 outputs force a more precise sentence than the template.

| Layer                                              | Finding                                                                                                     |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **typescript-eslint**                              | Supported `eslint` majors per **`npm view`** for the **range from `package.json`** — §2.2.                  |
| **`eslint-plugin-react-hooks` stable (`@latest`)** | Peer range per **`npm view`** on PR day — **can** end at ESLint 9 until stable publishes widened peers.     |
| **`eslint-plugin-react-hooks` canary (`@canary`)** | Peer range per **`npm view`** — **can** include ESLint 10 before stable; **A2** needs explicit policy.      |
| **Other eslint plugins / configs**                 | **Any** peer omitting ESLint 10 produces the same Yarn warning class — §2.3 is **mandatory**.               |
| **Yarn 4**                                         | Peer diagnostics surface inconsistent graphs; future Yarn **can** tighten.                                  |
| **Runtime vs declared**                            | Lint **can** run on ESLint 10 while peers disagree — still **unsupported** until upstream metadata matches. |

---

## 4. Solution strategies (**required** — pick one primary per PR)

### 4.0 Forbidden workarounds (**required**)

**(required)** Do **not** use **`package.json` → `resolutions`**, **`pnpm.overrides`**, or **npm `overrides`** in this task to rewrite upstream `eslint` peer declarations. **(required)** Use **only** strategies **A1**, **A2**, **B**, or **C** (or **Escalation** per §1.1).

### 4.1 Strategy A — Upgrade `eslint-plugin-react-hooks`

#### 4.1.1 **A1 — Stable upgrade** (**required** when the matrix assigns A1)

- **When:** §2.2 shows `@latest` peers include ESLint **10**.
- **(required)** Bump `eslint-plugin-react-hooks` in **`fe_demo/package.json`** and **`admin_demo/package.json`** to that stable; **(required)** `yarn install`; **(required)** re-run **§§2.1, 2.4–2.8**.

#### 4.1.2 **A2 — Canary bridge** (**required** details when the matrix assigns A2)

- **When:** Stable lacks ESLint 10 in peers **and** `@canary` includes it **and** stakeholders accept canary for lint.
- **(required)** Steps:
  1. Set `eslint-plugin-react-hooks` to an **exact** canary version (no range operators on the canary string).
  2. **(required)** PR description must contain: **risk** (pre-release), **removal trigger** (re-check `npm view …@latest` includes `^10.0.0`), **owner or issue ID** for removal.
  3. **(required)** Declare automation: **Dependabot/Renovate ignore** for this dependency until stable **or** a documented manual bump cadence — pick **one** and name it in the PR.
  4. **(required)** Re-run **§§2.1, 2.4–2.8**.

### 4.2 Strategy B — Pin ESLint to 9.x (**required** when the matrix assigns B)

- **(required)** Set `eslint` to a **9.x** release compatible with **all** plugins per §2.3 `npm view` results.
- **(required)** Align **`@eslint/js`** to **9.x** per [ESLint documentation](https://eslint.org/docs/latest/).
- **(required)** Align **`typescript-eslint`** to a release whose peers still include ESLint **9** — verify with `npm view`.
- **(required)** Read [Migrate to ESLint 10.0.0](https://eslint.org/docs/latest/use/migrate-to-10.0.0) and **(required)** list in the PR **any** reverted ESLint-10-only behavior you remove from configs or scripts.
- **(required)** Re-run **§§2.1, 2.4–2.8**.

### 4.3 Strategy C — Yarn `packageExtensions` (**required** when the matrix assigns C)

- **(required)** Edit **`.yarnrc.yml`** in **each** SPA. **(required)** Use a **version-scoped** package key matching the **resolved** `eslint-plugin-react-hooks` version from the lockfile:

```yaml
# (required) Issue URL for removal when A1 is possible:
packageExtensions:
  "eslint-plugin-react-hooks@<RESOLVED_VERSION>":
    peerDependencies:
      eslint: "^9.0.0 || ^10.0.0"
```

**(required)** Replace `<RESOLVED_VERSION>` with the exact semver Yarn resolves. **(required)** Follow [Yarn `packageExtensions`](https://yarnpkg.com/configuration/yarnrc#packageExtensions) syntax.

- **(required)** Open a **follow-up issue**; **(required)** paste its ID in the PR.
- **(required)** Add **one paragraph** in submodule **README** or **`docs/`** stating why the extension exists and the removal condition (`.yarnrc.yml` YAML `#` comments satisfy this when the issue URL is in that comment).
- **(required)** Re-run **§§2.1, 2.4–2.8**.
- **Risk note (**required** acknowledgment in PR):** Yarn **will not** surface that specific peer skew for the locator you patched — **§2.7–2.8** are the enforcement layer. **(required)** The list at [`yarnpkg-extensions` sources](https://github.com/yarnpkg/berry/blob/master/packages/yarnpkg-extensions/sources/index.ts) is **context for upstream patterns** — **(required)** do **not** copy entries blindly; prefer **A1** when it exists.

### 4.4 Anti-patterns (**required** avoidance)

- **Do not** combine **B** with **C** without a **PR-thread** stakeholder exception sentence.
- **Do not** combine **A2** with **C** for the **same** `react-hooks` ↔ `eslint` gap.
- **Do not** leave **`eslint-plugin-react-hooks`** on a **floating** `canary` / `next` / `latest` **range** that resolves to different digests over time.
- **Do not** change **only one** SPA — **`fe_demo`** and **`admin_demo`** **must** share the **same** primary strategy and **compatible** version pins.

---

## 5. Implementation steps (**required** — after matrix choice)

1. **(required)** Apply changes in **`fe_demo`**; **(required)** run **`yarn install`** locally so **`yarn.lock`** matches CI’s **`yarn install --immutable`**.
2. **(required)** Mirror **identical policy** in **`admin_demo`** (`eslint`, `@eslint/js`, `typescript-eslint`, `eslint-plugin-react-hooks`, `.yarnrc.yml` / absence thereof).
3. **(required)** Execute **§§2.6–2.8** after edits.
4. **(required)** If **A2**: satisfy **§4.1.2** item-for-item in the PR text.
5. **(required)** If **C**: satisfy **§4.3** item-for-item including README/docs and issue ID.
6. **(required)** Commit in **`fe_demo`** and **`admin_demo`** per submodule rules.
7. **(required)** Parent **`many_faces_main`:** if this work must publish new submodule tips, **(required)** commit updated submodule SHAs **in the same delivery** as documented by the team. **(required)** If parent pointers **do not** change, **(required)** state **“parent submodule SHAs unchanged”** in the PR with the reason (e.g. “docs-only parent”, “release train next week”).

---

## 6. Verification & CI (**required**)

- **(required)** Local **§2.8** **green** in **both** SPAs.
- **(required)** Confirm CI workflows for `fe_demo` / `admin_demo` still run `yarn install --immutable`, `yarn validate`, `yarn test`, `yarn build`.
- **(required)** On the **post-fix** `yarn install --immutable` log (CI artifact or local `tee` file), run:

```bash
grep -E 'YN0060|YN0086' /path/to/install.log; echo "exit:$?"
```

- **(required)** Outcome must be **one** of:
  - **Zero** matching lines — **(required)** PR states **“peer warning grep: clean”**.
  - **One or more** matching lines — **(required)** PR states **“peer warning grep: residual”** and **(required)** for **each** residual line **(required)** attach the matching **`yarn explain peer-requirements <hash>`** full output proving each residual is either **outside this task’s scope** with written justification **or** tracked as a **new** matrix item with owner.

- **(required)** Copy **verbatim** into the PR **every** `.yarnrc.yml` key in each SPA that contains `peer`, `pnp`, `install`, or `nodeLinker` (full stanza) so future strict-peer CI changes are auditable.

---

## 7. Deliverables (**required** checklist)

Use this section as the **merge gate**. **(required)** Every row below is satisfied or explicitly marked **N/A** with a **one-line** reason tied to evidence (e.g. “Escalation — no code merge”). **N/A without reason** is a failed run.

### 7.1 Global / compliance

- [ ] **§0** — Full normative compliance: no subsection of **§§1.1–8** skipped; no bullet in **§§2–6** skipped unless the row’s **N/A** rule applies.
- [ ] **§1 — upstream context** — PR body or investigation appendix cites **both** [facebook/react#35758](https://github.com/facebook/react/issues/35758) and [facebook/react#35720](https://github.com/facebook/react/pull/35720) **or** states **N/A** with reason (e.g. Escalation-only doc issue with same links in the issue body).
- [ ] **§1.1 — matrix & rationale** — Chosen cell (**A1** / **A2** / **B** / **C**) **or** **Escalation — stop**; **minimum one-sentence** rationale in the PR description; **or** Escalation row: pasted **§2.2** `npm view` outputs + stakeholder or **B** decision **quoted or linked** from the PR thread.
- [ ] **§1.1 — matrix coverage** — If the situation was ambiguous, PR contains the **Matrix coverage rule** outcome (Escalation until policy in thread, or the row chosen after stakeholder text).

### 7.2 Investigation artifacts (**both** `fe_demo` and `admin_demo` unless **N/A**)

- [ ] **§2 (shell logs)** — For **each** SPA, attachments or repo paths proving stdout/stderr for: **`yarn install --immutable`** (§2.1), full **§2.2** `npm view` block (same script as in §2.2), **`yarn lint`** (§2.7), **`yarn validate && yarn test && yarn build`** (§2.8).
- [ ] **§2.1 — `YN*` inventory** — Every peer-related **`YN00xx`** line from both install logs copied into the PR (or appendix file); plus the **summary table**: Yarn code → requesting package → requested peer → subject (as log exposes).
- [ ] **§2.1 — `yarn explain peer-requirements` (no hash)** — Full stdout from **each** SPA root after install; if the command **errors** or is empty, PR contains the **verbatim** error/empty output **and** the sentence required by §2.1.
- [ ] **§2.1 — `yarn explain peer-requirements` (per hash)** — Full tree output for **every** hash used in conclusions, from the correct SPA root; **plus** explicit PR conclusion: **only** `eslint-plugin-react-hooks` vs **list of other** packages mis-declaring `eslint` for v10.
- [ ] **§2.2 — registry** — Complete pasted output of the §2.2 shell block for **`fe_demo`** and again for **`admin_demo`** (two blocks); prose answers for `@latest` / `@canary` ESLint 10 inclusion and **exact** version strings; if `ESLINT_RANGE` / `TS_ESLINT_RANGE` was empty, PR documents the fix before merge **or** **Escalation** with blocker text.
- [ ] **§2.3 — dependency list** — Table or bullet list: **every** package name matching §2.3 rules from each `package.json` (fe + admin); **every** `npm view "<pkg>@<range>" peerDependencies` line run (scoped names quoted); **per-package** note whether ESLint 10 is allowed by peers while SPA pins ESLint 10; **remediation** row (upgrade / B / C / already OK) for each exclusion.
- [ ] **§2.4 — linker record** — For each SPA: `.yarnrc.yml` path or **“absent”**; verbatim `nodeLinker`, `pnpMode`, every key whose name contains **`peer`**; **plus** the **one sentence** linking linker mode to install strictness (PnP vs `node-modules`).
- [ ] **§2.5 — lockfile** — Count of distinct resolved `eslint` versions (from `yarn why eslint` or `yarn.lock` grep) + explanation; **Branch A** (dedupe command + lockfile diff summary) **or** **Branch B** (explicit “no documented dedupe” + duplicate analysis) for **each** SPA.

### 7.3 Config, root cause, strategies

- [ ] **§2.6 — flat config** — For **each** SPA: for every existing `eslint.config.{js,mjs,cjs,ts,mts,cts}`, either diff showing alignment to resolved `eslint-plugin-react-hooks` **or** PR subsection **“Flat config N/A”** with **shell proof** (e.g. `ls -la eslint.config.*` output) that only non-hook files exist **and** hook preset unchanged is justified.
- [ ] **§3 — root cause table** — The §3 markdown table is **copied into the PR**; cells adjusted only where §2 forced new wording (per §3 instructions).
- [ ] **§4.0 — forbidden workarounds** — PR contains an explicit sentence: **no** `package.json` → `resolutions`, **no** `pnpm.overrides`, **no** npm `overrides` were used to patch **`eslint`** peer declarations for this task.
- [ ] **§4.4 — anti-patterns** — PR states compliance with all §4.4 bullets **or** **one** PR-thread stakeholder exception (quoted) **only** for the allowed **B + C** case; **A2 + C** same-gap combination must **not** appear without being rejected in review.

### 7.4 Strategy-specific (**N/A** with reason if that strategy was not chosen)

- [ ] **A1 only** — Stable `eslint-plugin-react-hooks` version written in PR; both `package.json` files updated; re-run evidence for §§2.1, 2.4–2.8 attached.
- [ ] **A2 only** — Exact canary version string (no `^`/`~` on canary); PR contains risk, removal trigger, owner/issue ID; automation choice (**Dependabot/Renovate ignore** vs **manual cadence**) named; follow-up issue link; re-run evidence for §§2.1, 2.4–2.8 attached.
- [ ] **B only** — Final pinned **`eslint`**, **`@eslint/js`**, **`typescript-eslint`** versions listed in PR (each SPA); link or paste of **Migrate to ESLint 10.0.0** review; **bulleted list** of any ESLint-10-only configs/scripts reverted; re-run evidence for §§2.1, 2.4–2.8 attached.
- [ ] **C only** — Both `.yarnrc.yml` `packageExtensions` stanzas pasted; `<RESOLVED_VERSION>` matches lockfile; follow-up issue ID; README/docs paragraph **or** YAML `#` issue URL comment; PR includes §4.3 **risk acknowledgment** sentence about peer masking; re-run evidence for §§2.1, 2.4–2.8 attached.
- [ ] **Escalation only** — No fraudulent peer metadata; blocker evidence (§2.2 outputs) attached; thread shows **B** adoption or wait decision; **N/A** rows in 7.4 marked for A1/A2/C with reason “strategy not chosen”.

### 7.5 Repo / CI / references

- [ ] **`yarn.lock`** — Committed in **every** SPA where `package.json` or `.yarnrc.yml` changed; if no lockfile change, PR states why (e.g. “no resolution delta”).
- [ ] **§6 — CI workflow parity** — PR lists the workflow **file paths or job names** (e.g. under `.github/workflows/`) for **`fe_demo`** and **`admin_demo`** that run `yarn install --immutable`, `yarn validate`, `yarn test`, and `yarn build`; **(required)** confirm those steps are still present after the change **or** include the **same PR** updating the workflow when a step was renamed/removed.
- [ ] **§5 — submodule commits** — Links or commit SHAs for **`fe_demo`** and **`admin_demo`** containing the dependency/config changes.
- [ ] **§5.7 — parent repo** — Either parent **`many_faces_main`** submodule pointer commit in this delivery **or** exact sentence **“parent submodule SHAs unchanged”** with reason from §5.7.
- [ ] **§6 — CI / grep** — `grep -E 'YN0060|YN0086'` (or project-equivalent) run on **post-fix** install log for **each** SPA; **exit code** recorded; outcome **clean** vs **residual** with §6 rules satisfied (including every **`yarn explain`** for residual lines).
- [ ] **§6 — `.yarnrc.yml` audit stanzas** — Verbatim copy in PR of **every** key in each SPA’s `.yarnrc.yml` whose key name contains **`peer`**, **`pnp`**, **`install`**, or **`nodeLinker`** (full key + value); if none, PR states **“no such keys”** per SPA.
- [ ] **§8 — References consulted** — PR section lists **every** §8 URL the agent opened for the chosen strategy (titles allowed); list **must** match what was actually used (cross-check against strategy: e.g. **C** requires Yarn `packageExtensions` doc link present).

---

## 8. References (**required** bookmarks for the agent)

**(required)** Open **every** link in §8 that applies to the chosen strategy (**A1** / **A2** / **B** / **C** / escalation) at least once during the task. **(required)** The PR **must** list those URLs (or their page titles) under a heading such as **“References consulted”**.

- Yarn **`packageExtensions`:** [Yarn docs — `packageExtensions`](https://yarnpkg.com/configuration/yarnrc#packageExtensions)
- Yarn PnP migration (boundary / extension philosophy): [Yarn — To go further: PnP](https://yarnpkg.com/migration/pnp)
- Yarn peer UX context: [yarnpkg/berry PR #6205](https://github.com/yarnpkg/berry/pull/6205)
- Upstream extension patterns (**context — no blind copy**): [`yarnpkg-extensions` sources](https://github.com/yarnpkg/berry/blob/master/packages/yarnpkg-extensions/sources/index.ts)
- ESLint v10 migration (for **B** and for detecting 10-only features): [Migrate to ESLint 10.0.0](https://eslint.org/docs/latest/use/migrate-to-10.0.0)
- React issue: [facebook/react#35758](https://github.com/facebook/react/issues/35758)
- React PR: [facebook/react#35720](https://github.com/facebook/react/pull/35720)
- npm: [`eslint-plugin-react-hooks`](https://www.npmjs.com/package/eslint-plugin-react-hooks)
- Repo flat configs: `fe_demo/eslint.config.*`, `admin_demo/eslint.config.*`
- Related audit prompt: [monorepo-dependency-audit-and-upgrade-agent-prompt.md](./monorepo-dependency-audit-and-upgrade-agent-prompt.md)
- After peers are aligned: [react-hooks-compiler-rules-rollout-agent-prompt.md](./react-hooks-compiler-rules-rollout-agent-prompt.md) (full `recommended` / compiler rules rollout)
