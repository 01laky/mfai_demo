# Mobile (`many_faces_mobile`) — Expo development guide

This guide is the **human-facing** counterpart to the agent prompt [`docs/prompts/mobile-phase1-foundation-agent-prompt.md`](../prompts/mobile-phase1-foundation-agent-prompt.md). It tells you **how to start**, which monorepo contracts the app must follow, and where to look in the web frontend for parity.

## 1. Role in the monorepo

- **Submodule path:** `many_faces_mobile/` (git submodule `many_faces_mobile` in `many_faces_main`).
- **Remote:** `https://github.com/01laky/many_faces_mobile.git`.
- **Stack:** Expo (React Native), TypeScript. It is **not** started by `docker-compose.dev.yml`; run it on the host (Expo Go or simulator).
- **Backend parity:** Same API surface as `many_faces_portal` for phase-1 scope — especially `GET /api/faces/config` and OAuth2 token flows documented in [`authentication-and-sessions.md`](./authentication-and-sessions.md).

## 2. Prerequisites

| Requirement | Notes |
| ----------- | ----- |
| **Node** | Use **`.nvmrc`** inside `many_faces_mobile` (aligned with monorepo root, currently **22.14+**). |
| **npm** | Default for Expo scaffold (`package-lock.json`). CI must use `npm ci`. |
| **Watchman** (macOS) | Recommended for Metro file watching. |
| **Xcode** | For iOS Simulator. |
| **Android Studio / SDK** | For Android emulator (optional). |
| **Expo Go** (physical device) | Install from App Store / Play Store; phone and dev machine must reach Metro (LAN or tunnel). |

## 3. First-time setup (local)

From the **monorepo root**:

```bash
git submodule update --init --recursive
cd many_faces_mobile
nvm use   # or: nvm install && nvm use
npm install
```

Copy environment template:

```bash
cp .env.example .env
# Required: EXPO_PUBLIC_API_BASE_URL (and OAuth2 demo keys if you changed backend clients)
```

`EXPO_PUBLIC_*` keys are read at bundle time via `app.config.ts` → `expo.extra` (see `src/config/env.ts`).

Start Metro:

```bash
npm run start
```

Then press `i` / `a` / scan QR for Expo Go. For HTTPS dev API from a device, you may need a tunnel or a machine-reachable host (document limitations in the mobile README).

## 4. Parity reference (web frontend)

Implementers should mirror behaviour and data contracts, not necessarily file names:

| Concern | Where in `many_faces_portal` |
| ------- | ------------------------------ |
| Faces + pages config | `src/api/config/getFacesConfig.ts`, `src/api/types/facesConfig.ts`, `src/contexts/FaceConfigContext.tsx` |
| Dynamic route ideas | `src/routes/useFaceRouteEntries.ts`, `src/routes/facePagePaths.ts` |
| Guest vs authenticated | `src/components/GuestRoute.tsx`, `src/components/ProtectedRoute.tsx` |
| Login form + validation | `src/pages/LoginPage.tsx`, `src/contexts/AuthContext.tsx` |
| Header / gradient shell | `src/components/Header.tsx`, `src/styles/AnimatedGradient.scss` (mobile uses `expo-linear-gradient` + parsed JSON) |

## 5. Quality gates (after phase-1 tooling lands)

From `many_faces_mobile/`:

```bash
npm run lint
npm run format:check
npm run typecheck
npm test
npx expo-doctor
```

Parent CI runs the same matrix under **`many_faces_mobile`** in `many_faces_main/.github/workflows/ci.yml`, and this submodule has a standalone **`.github/workflows/ci.yml`** for pushes to the mobile repo alone. Root orchestration also calls **`./many_faces_mobile/lint.sh`** from **`scripts/lint-all.sh`** and **`npm test`** from **`scripts/test-all.sh`** when the directory exists.

## 6. Git / submodule workflow (short)

1. Work on a **branch** inside `many_faces_mobile` (e.g. `feature/mobile-phase1-auth`).
2. **Commit and push** the submodule to `many_faces_mobile` `main` (or open a PR on that repo if you enable branch protection).
3. In **`many_faces_main`**, commit the **updated submodule pointer** (gitlink) so CI and teammates resolve the same SHA.

Details: [`git-submodules.md`](./git-submodules.md).

## 7. Related documentation

- [`development.md`](./development.md) — monorepo scripts, `ci-local.sh`, Node versions.
- [`authentication-and-sessions.md`](./authentication-and-sessions.md) — OAuth2 / JWT for login parity.
- [`ai-assisted-content-approval.md`](./ai-assisted-content-approval.md) — full-stack moderation story (mobile README should reference for product context; phase-1 mobile does **not** implement grid moderation UI).

## 8. Troubleshooting

| Symptom | Check |
| ------- | ----- |
| Metro cannot reach API from phone | Same Wi‑Fi, correct `EXPO_PUBLIC_*` host, firewall, or use Expo tunnel. |
| TLS errors to local `https://localhost:8001` | Device may not trust dev cert; use LAN IP + dev cert trust or HTTP-only dev URL if supported. |
| Stale submodule | `git submodule update --init --recursive` from monorepo root. |

When in doubt, update **`many_faces_mobile/README.md`** with the exact commands and env vars your team uses after phase-1 lands.
