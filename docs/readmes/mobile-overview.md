# Mobile app overview (`many_faces_mobile`)

Extended narrative for the **Expo / React Native** client. Submodule README (commands, Mermaid, env): [`../../many_faces_mobile/README.md`](../../many_faces_mobile/README.md).

## Role

- **Same API spine** as [`many_faces_portal`](../../many_faces_portal/README.md): `GET /api/faces/config`, OAuth2 password + refresh, face-scoped REST, `GET /api/me/capabilities`.
- **Not** in root `docker-compose.dev.yml` — run on the host (`yarn start`) or EAS when you add release trains.
- **Never** talks to Elasticsearch, push worker, or mailer directly — only `many_faces_backend` REST (+ SignalR infrastructure for future hub UI).

## Component folder colocation (delivered)

Each UI unit lives in its own directory (`ComponentName/ComponentName.tsx` + `index.ts`):

| Namespace         | Examples                                                       |
| ----------------- | -------------------------------------------------------------- |
| `src/screens/`    | `LoginScreen/`, `FacePageScreen/`, `MySubmissionsScreen/`, `MySubmissionDetailScreen/`, `ProfileMeScreen/` |
| `src/components/` | `AppShell/`, `ShellDrawer/`, `wall-tickets/*`                  |
| `src/grid/`       | `MobilePageLayout/`, `blocks/*`, `parseGridSchema.ts`          |
| `src/theme/`      | `AnimatedShellGradient/`                                       |
| `src/features/`   | `settings/` — panel in `AppShell` (`LanguageSwitcher`, sign out) |

**Verify** (from monorepo root):

```bash
node scripts/verify-mobile-component-colocation.mjs
node scripts/verify-mobile-component-colocation.mjs --imports
```

**Spec:** [`docs/prompts/fe-mobile-component-folder-colocation-agent-prompt.md`](../prompts/fe-mobile-component-folder-colocation-agent-prompt.md) · **Cursor:** [`.cursor/rules/mobile-component-folders.mdc`](../../.cursor/rules/mobile-component-folders.mdc) · **In-repo READMEs:** [`many_faces_mobile/src/components/README.md`](../../many_faces_mobile/src/components/README.md), [`src/features/README.md`](../../many_faces_mobile/src/features/README.md).

## Quality gates

```bash
cd many_faces_mobile
yarn validate
./scripts/verify-ci.sh --quick
```

Parent CI: colocation script → `verify-ci.sh` (see [`development.md`](../guides/development.md)).

## Parity tracking

- REST / grid matrix: [`many_faces_mobile/docs/rest-parity-matrix.md`](../../many_faces_mobile/docs/rest-parity-matrix.md)
- Portal ↔ mobile routes: [`many_faces_mobile/docs/portal-route-parity.md`](../../many_faces_mobile/docs/portal-route-parity.md)
- Contributor guide: [`mobile-expo-development.md`](../guides/mobile-expo-development.md)
- Phase 2+ behaviour spec: [`mobile-portal-feature-parity-agent-prompt.md`](../prompts/mobile-portal-feature-parity-agent-prompt.md)

## Related monorepo docs

| Topic                       | Guide                                                                          |
| --------------------------- | ------------------------------------------------------------------------------ |
| Push / FCM                  | [`push-notifications-local-dev.md`](../guides/push-notifications-local-dev.md) |
| Static i18n                 | [`static-localization-and-i18n.md`](../guides/static-localization-and-i18n.md) |
| My submissions / moderation | [`ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md) |
| Grid schema (web + mobile)  | [`grid-schema-and-page-layout.md`](../guides/grid-schema-and-page-layout.md)   |
