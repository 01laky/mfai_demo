# Brand assets — favicon (portal + admin) and mobile app icons — Agent Prompt

**Language:** All **new** prose you add to the codebase (README snippets, guide updates, script comments, PR description) must be **English**.

**Mission:** Unify the **Many Faces kitsune mask** brand mark across **`many_faces_portal`**, **`many_faces_admin`**, and **`many_faces_mobile`** by treating **`many_faces_mobile/assets/logo-raster-source.png`** as the **canonical raster source** for this engagement. From that file:

1. Generate and **wire browser favicons** (and related touch/manifest icons where appropriate) for **portal** and **admin**, replacing the default **Vite** placeholder (`/vite.svg`).
2. Regenerate **Expo / native app icon assets** for **mobile** using the existing mobile icon pipeline, then ensure **`app.config.ts`** continues to reference the updated files.
3. **Apply changes immediately** in running local dev: restart the **Docker FE stacks** (portal + admin) and refresh **mobile** dev clients so operators can **see** the new icons without guessing.

**(required)** Start at **§0** before editing assets; complete **§12** (master checklist) while implementing; finish **§9** (verification) and **§10** (deliverables) before requesting review.

**Non-goals (explicit):**

- **Not** redesigning the logo, changing colors, or replacing the inline SVG in `MainLogo.tsx` unless a **confirmed visual bug** forces a tiny alignment fix (document before/after screenshots).
- **Not** changing store listing screenshots, marketing site, or email templates in this pass.
- **Not** committing unrelated refactors in portal/admin/mobile.
- **Not** deleting **`assets/logo-raw.svg`** or the mobile **`yarn icons:export`** pipeline — they remain the **vector → raster** path when artwork changes in the future.

---

## 0. Compliance — read every part (**required**)

### 0.1 Labels (**required** — use consistently in PR text)

| Label | Meaning |
| ----- | ------- |
| **(required)** | Must be satisfied before merge, or **explicitly deferred** in the PR with reason and follow-up issue. |
| **(required — if _condition_)** | Mandatory whenever _condition_ is true. |
| **(optional)** | Nice-to-have; skip only with written deferral. |

### 0.2 Section coverage (**required** — copy into PR and tick)

| § | Expectation | Status (✓ / N/A) | If N/A, reason |
| - | ----------- | ---------------- | -------------- |
| **§1** | Canonical source understood | ✓ | |
| **§2** | Current-state inventory | ✓ | |
| **§3** | Portal favicon | ✓ | |
| **§4** | Admin favicon | ✓ | |
| **§5** | Mobile icons | ✓ | |
| **§6** | Asset governance / scripts | ✓ | |
| **§7** | Stack restart & visual verification | ✓ | |
| **§8** | Anti-patterns | ✓ | |
| **§9** | Verification commands | ✓ | |
| **§10** | Deliverables | ✓ | |
| **§12** | Master checklist | ✓ | |

**(required)** **§9** and **§10** must be ✓ for every PR. **§12** inner boxes must be ✓ or N/A with one-line reason.

---

## 1. Canonical source asset (**required**)

### 1.1 Single raster source of truth

| Property | Value |
| -------- | ----- |
| **Path** | `many_faces_mobile/assets/logo-raster-source.png` |
| **Role** | **Canonical raster** for favicon + mobile icon generation in **this** prompt |
| **Do not** | Re-rasterize from SVG for portal/admin unless the committed PNG is missing, corrupt, or provably stale vs `logo-raw.svg` |

### 1.2 Related assets (context only — do not conflate)

| Path | Role |
| ---- | ---- |
| `many_faces_mobile/assets/logo-raw.svg` | Vector source; feeds `yarn icons:export` → `logo-raster-source.png` when artwork changes |
| `many_faces_mobile/assets/logo.svg` | Legacy/alternate Sharp input (see `pad-app-icons.mjs` fallback order) |
| `many_faces_portal/src/components/MainLogo.tsx` | Inline SVG in the app chrome — **separate** from favicon files; should remain visually consistent with the mask |
| `many_faces_portal/public/vite.svg` | **Placeholder** today — **replace** as browser tab icon |
| `many_faces_admin/public/vite.svg` | Same placeholder — **replace** |

### 1.3 Visual intent (implementation constraints)

The raster depicts a **symmetrical kitsune (fox) mask**: white face, red forehead stripes and cheek marks, black eye cutouts, pointed ears, transparent (or black) exterior depending on export. When scaling to **16×16** favicon sizes:

- Preserve **recognizable ears + forehead stripes**; avoid cropping the chin off.
- Prefer **slight inner padding** (same philosophy as mobile `pad-app-icons.mjs`, ~72% safe zone on 1024 canvas) so circular/squircle masks do not clip ears.
- Use **transparent** PNG / ICO backgrounds for browser tab favicons (mask only, no white plate). Native **app icon** (`icon.png`) may keep a white canvas for iOS home-screen masks.

---

## 2. Baseline inventory (**required** before generating files)

**(required)** Record in the PR (table or bullets):

### 2.1 Portal (`many_faces_portal`)

- `index.html` — today: `<link rel="icon" type="image/svg+xml" href="/vite.svg" />`
- `public/` — today: only `vite.svg` (no `favicon.ico`, no PNG sizes)
- Dev Docker: `fe-demo-dev` + `fe-demo-proxy` (host **9081** HTTPS, **9080** HTTP) per root `docker-compose.dev.yml`

### 2.2 Admin (`many_faces_admin`)

- `index.html` — today: `<link rel="icon" type="image/svg+xml" href="/vite.svg" />`, title `Admin Demo`
- `public/` — today: only `vite.svg`
- Dev Docker: `admin-demo-dev` (host **8082** HTTPS) per root `docker-compose.dev.yml`

### 2.3 Mobile (`many_faces_mobile`)

- `app.config.ts` — `icon: './assets/icon.png'`, `splash.image: './assets/splash-icon.png'`, Android `adaptiveIcon.foregroundImage: './assets/adaptive-icon.png'`, `web.favicon: './assets/favicon.png'`
- Scripts (already present):
  - `yarn icons:export` → `scripts/export-logo-transparent-png.mjs` (SVG → `logo-raster-source.png`, Playwright/resvg)
  - `yarn icons:pad` → `scripts/pad-app-icons.mjs` (reads **`logo-raster-source.png` first**)
  - `yarn icons:rebuild` → `icons:export` + `icons:pad`
- **This prompt:** regenerate **`icon.png`**, **`adaptive-icon.png`**, **`splash-icon.png`**, **`favicon.png`** from the **existing** `logo-raster-source.png` via **`yarn icons:pad`** (run `icons:rebuild` only if SVG changed).

---

## 3. Portal — favicon generation and wiring (**required**)

### 3.1 Output files (**required**)

Place under **`many_faces_portal/public/`** (Vite serves `public/` at site root):

| File | Size / format | Purpose |
| ---- | ------------- | ------- |
| `favicon.ico` | 16, 32, 48 multi-size ICO **or** single 32×32 | Legacy browsers, default tab icon |
| `favicon-32x32.png` | 32×32 PNG | Modern browsers |
| `favicon-16x16.png` | 16×16 PNG | Modern browsers |
| `apple-touch-icon.png` | 180×180 PNG | iOS home-screen bookmark |
| **(optional)** `favicon.svg` | SVG trace or simplified mark | Only if you can keep file size small; **not required** if PNG/ICO set is complete |

**(required)** Source pixels: read from  
`../many_faces_mobile/assets/logo-raster-source.png`  
(relative to portal repo) **or** copy once into `many_faces_portal/public/brand/logo-raster-source.png` and document sync policy in PR — **prefer a small reproducible script** over manual one-off ImageMagick.

### 3.2 Generation approach (**required**)

**(required — pick one, document in PR):**

- **A (preferred):** Add `many_faces_portal/scripts/generate-favicon.mjs` (Node + **`sharp`**, devDependency) that:
  - Accepts `--source` defaulting to `../../many_faces_mobile/assets/logo-raster-source.png`
  - Writes all files in §3.1 with padding/background rules from §1.3
  - Exposed as `"favicon:generate": "node ./scripts/generate-favicon.mjs"` in `package.json`
- **B:** Add a **monorepo** script `scripts/generate-brand-favicons.mjs` that writes into **both** `many_faces_portal/public/` and `many_faces_admin/public/` in one command.

**(required)** Do **not** hand-edit binary icons without a script — reviewers must be able to regenerate from `logo-raster-source.png`.

### 3.3 `index.html` updates (**required**)

Update **`many_faces_portal/index.html`** `<head>`:

- Remove or stop referencing `/vite.svg` as the primary icon.
- Add, at minimum:

```html
<link rel="icon" href="/favicon.ico" sizes="any" />
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png" />
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png" />
<link rel="apple-touch-icon" href="/apple-touch-icon.png" />
```

- **(optional)** `<link rel="manifest" href="/site.webmanifest" />` only if you add a minimal manifest — not required for dev favicon parity.

**(required)** Leave `vite.svg` in `public/` only if something else still references it; otherwise delete or add a comment in PR why it remains.

### 3.4 Cache busting note

Browsers cache favicons aggressively. After deploy, verify with **hard refresh** (Ctrl+Shift+R / Cmd+Shift+R) or a private window. Mention this in PR test notes.

---

## 4. Admin — favicon generation and wiring (**required**)

### 4.1 Parity with portal (**required**)

**(required)** Admin receives the **same** favicon file set and `index.html` link tags as portal (§3.1–3.3), under **`many_faces_admin/public/`**.

### 4.2 `index.html` title (**required — if product agrees)**

Today: `<title>Admin Demo</title>`. **(optional)** Rename to `Many Faces Admin` to match `VITE_APP_NAME` in compose — only if consistent with existing admin branding; otherwise **leave title** and change **icons only**.

### 4.3 Shared script (**required — if using approach B from §3.2)**

One generator invocation must update **both** SPAs so portal and admin never drift.

---

## 5. Mobile — app icon regeneration (**required**)

### 5.1 Regenerate from canonical raster (**required**)

From `many_faces_mobile/`:

```bash
corepack enable
yarn install --immutable   # if needed
yarn icons:pad             # reads logo-raster-source.png first
```

**(required)** Confirm outputs updated (git diff non-empty for at least `assets/icon.png` and `assets/adaptive-icon.png` if source changed):

- `assets/icon.png` (1024×1024, white background, padded mask)
- `assets/adaptive-icon.png` (1024×1024, transparent background)
- `assets/splash-icon.png` (same as icon per current script)
- `assets/favicon.png` (Expo web — update if `pad-app-icons.mjs` does not touch it; **extend script** to write `favicon.png` from the same padded raster if missing)

### 5.2 `app.config.ts` (**required**)

**(required)** Verify paths still valid (no change expected unless you rename files):

- `icon: './assets/icon.png'`
- `splash.image: './assets/splash-icon.png'`
- `android.adaptiveIcon.foregroundImage: './assets/adaptive-icon.png'`
- `web.favicon: './assets/favicon.png'`

### 5.3 Native / Expo dev refresh (**required**)

Mobile is **not** in root `docker-compose.dev.yml` for the app shell. After icon changes:

```bash
cd many_faces_mobile
yarn start:clear    # or: expo start --clear
```

**(required — if testing on device/simulator):** Document that **iOS Simulator / Android emulator** may need app reinstall to pick up icon changes; Expo Go uses its own icon — **standalone/dev client** shows `icon.png`.

---

## 6. Asset governance and documentation (**required**)

### 6.1 Single-source workflow (document in PR + short README note)

**(required)** Add or update a short subsection (pick one location):

- `many_faces_mobile/README.md` — **Brand assets** section, **or**
- `docs/guides/development.md` — one paragraph + link to generator scripts

Must state:

1. **Vector edits** → `assets/logo-raw.svg` → `yarn icons:export` → `logo-raster-source.png`
2. **Mobile icons** → `yarn icons:pad` (or `yarn icons:rebuild`)
3. **Portal + admin favicons** → `yarn favicon:generate` (or monorepo script name you add)
4. **Order when mask artwork changes:** export → pad (mobile) → generate favicons (web) → restart FE stacks

### 6.2 Do not duplicate unbounded copies

**(required)** Portal/admin `public/` may contain **generated** binaries only. The **canonical** `logo-raster-source.png` stays in **mobile** unless the team later moves it to `many_faces_main/assets/` (out of scope here).

---

## 7. Restart dev stacks and visual verification (**required**)

### 7.1 Docker FE restart (**required**)

From **`many_faces_main`** repository root (after favicon files exist on disk):

**(required — preferred full cycle):**

```bash
./scripts/restart-all-dev.sh
```

**(required — minimal FE-only alternative** if backend/data must stay up):

```bash
docker compose -f docker-compose.dev.yml restart fe-demo-dev fe-demo-proxy admin-demo-dev
```

If icons still look stale (rare with bind mounts), recreate FE containers:

```bash
docker compose -f docker-compose.dev.yml up -d --force-recreate fe-demo-dev fe-demo-proxy admin-demo-dev
```

### 7.2 Visual checks (**required**)

| Surface | URL | What to verify |
| ------- | --- | -------------- |
| Portal | `https://localhost:9081/` (or `http://localhost:9080/`) | Browser tab shows **kitsune mask**, not Vite logo |
| Admin | `https://localhost:8082/` | Same favicon as portal |
| Mobile web | Expo web URL from `yarn web` | `favicon.png` in tab |
| Mobile native | Installed dev build / simulator | Home-screen icon shows padded mask |

**(required)** Attach **screenshots** (tab bar + home screen) to PR or note “verified locally” with browser names.

### 7.3 `MainLogo` consistency (**required — visual spot check**)

Open portal header: inline `MainLogo` SVG should still **match** the favicon silhouette. If favicon and header clearly disagree, stop and reconcile (re-export raster or adjust padding constants) before merge.

---

## 8. Anti-patterns and rejection criteria (**required**)

Reject implementations that:

- Use **unrelated** stock icons, emojis, or Vite defaults in `index.html` after this work.
- Commit **only** `index.html` changes without binary favicon files (broken tabs in fresh clone).
- Point favicon `href` at a path **outside** `public/` without Vite configuration.
- Regenerate `logo-raster-source.png` from SVG **without** noting artwork change (unnecessary noise in diff).
- Run **`restart-all-dev.sh`** on a machine where the operator did not expect **full stack** downtime — document in PR if you used FE-only restart instead.
- Break **`yarn icons:pad`** or mobile CI by adding Sharp options that fail on Linux CI (test `many_faces_mobile` job if icons change).

---

## 9. Verification commands (**required**)

Run from repo root unless noted:

```bash
# Mobile (if assets or scripts touched)
cd many_faces_mobile && yarn icons:pad && yarn test && yarn lint && yarn typecheck

# Portal (if added generator)
cd many_faces_portal && yarn favicon:generate && yarn lint && yarn typecheck && yarn build

# Admin (if added generator)
cd many_faces_admin && yarn favicon:generate && yarn lint && yarn typecheck && yarn build

# Optional monorepo quick gate
./scripts/lint-all.sh    # if FE submodules changed
```

**(required)** `yarn build` for each touched SPA must succeed (favicon files copied into `dist/` via `public/`).

**(required)** After restart (§7), manual tab-icon check on portal **and** admin.

---

## 10. Deliverables (**required**)

1. **Portal:** `public/favicon*` + `apple-touch-icon.png` + updated `index.html` + generator script + `package.json` script entry.
2. **Admin:** same file set + updated `index.html`.
3. **Mobile:** regenerated `assets/icon.png`, `adaptive-icon.png`, `splash-icon.png` (and `favicon.png` if applicable) from `logo-raster-source.png`.
4. **Docs:** short “Brand assets” workflow (§6.1).
5. **PR description:** §0.2 table, before/after screenshots, exact restart command used, confirmation that canonical source path was `many_faces_mobile/assets/logo-raster-source.png`.

**Submodule commits:** If you touch `many_faces_portal`, `many_faces_admin`, or `many_faces_mobile`, commit **inside each submodule** and bump pointers in `many_faces_main` per [`docs/guides/git-submodules.md`](../guides/git-submodules.md).

---

## 11. Submodule / monorepo touch matrix

| Repo | Expected changes |
| ---- | ---------------- |
| `many_faces_mobile` | Regenerated PNGs; possibly extend `pad-app-icons.mjs` for `favicon.png`; README note |
| `many_faces_portal` | `public/` favicons, `index.html`, generator script |
| `many_faces_admin` | `public/` favicons, `index.html`, generator script (or shared root script only) |
| `many_faces_main` | Submodule pointer bumps; optional `docs/guides/development.md` blurb; **optional** root script wrapper |

---

## 12. Final checklist — tasks for the implementing agent

**Policy:** Leave boxes **unchecked `[ ]` in this file** per [`docs/prompts/README.md`](./README.md). Copy into PR and tick there.

### Canonical source and inventory

- [x] Confirm `many_faces_mobile/assets/logo-raster-source.png` exists and matches intended kitsune mask artwork.
- [x] Complete §2 inventory in PR (portal/admin `index.html`, `public/`, mobile `app.config.ts`, scripts).
- [x] Decide generator placement (portal script **vs** monorepo script) and document in PR.

### Portal (`many_faces_portal`)

- [x] Add reproducible favicon generator reading `logo-raster-source.png`.
- [x] Write `public/favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png` (and optional extras).
- [x] Update `index.html` favicon `<link>` tags; remove primary dependency on `/vite.svg`.
- [x] Run `yarn build`; confirm `dist/` contains favicon assets.
- [x] Visual check at `https://localhost:9081/` (or `http://localhost:9080/`) after stack restart.

### Admin (`many_faces_admin`)

- [x] Generate same favicon set under `public/`.
- [x] Update `index.html` favicon links (and title only if §4.2 applies).
- [x] Run `yarn build`; confirm `dist/` contains favicon assets.
- [x] Visual check at `https://localhost:8082/` after stack restart.

### Mobile (`many_faces_mobile`)

- [x] Run `yarn icons:pad` (or `yarn icons:rebuild` if SVG changed) from `logo-raster-source.png`.
- [x] Verify `app.config.ts` icon paths still correct.
- [x] Run `yarn test`, `yarn lint`, `yarn typecheck`.
- [x] `yarn start:clear` (or document simulator reinstall) and verify icon on target platform.

### Dev stack restart (**required**)

- [x] Restart FE stacks: `./scripts/restart-all-dev.sh` **or** `docker compose -f docker-compose.dev.yml restart fe-demo-dev fe-demo-proxy admin-demo-dev` (document which).
- [x] Hard-refresh browser / private window — confirm new tab icons on portal and admin.

### Documentation and monorepo

- [x] Add §6.1 brand-asset workflow to mobile README or `docs/guides/development.md`.
- [x] Commit submodule(s); bump `many_faces_main` submodule pointers if applicable.
- [x] PR includes §0.2 coverage table, screenshots, and verification commands from §9.

---

**End of prompt.**
