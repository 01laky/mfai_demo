# Component: mobile ↔ portal parity

**Purpose:** Track which REST/SignalR/grid behaviours exist on **`many_faces_mobile`** vs **`many_faces_portal`**.

**Primary artifacts:** [`many_faces_mobile/docs/rest-parity-matrix.md`](../../many_faces_mobile/docs/rest-parity-matrix.md), [`portal-route-parity.md`](../../many_faces_mobile/docs/portal-route-parity.md), [`mobile-expo-development.md`](../guides/mobile-expo-development.md), [`readmes/mobile-overview.md`](../readmes/mobile-overview.md).

**Structure / colocation:** [`many_faces_mobile/src/components/README.md`](../../many_faces_mobile/src/components/README.md), [`src/features/README.md`](../../many_faces_mobile/src/features/README.md), `node scripts/verify-mobile-component-colocation.mjs` (monorepo root), [`.cursor/rules/mobile-component-folders.mdc`](../../.cursor/rules/mobile-component-folders.mdc).

**Prompts:** [`mobile-phase1-foundation-agent-prompt.md`](../prompts/mobile-phase1-foundation-agent-prompt.md), [`fe-mobile-component-folder-colocation-agent-prompt.md`](../prompts/fe-mobile-component-folder-colocation-agent-prompt.md) (**implemented**), [`mobile-portal-feature-parity-agent-prompt.md`](../prompts/mobile-portal-feature-parity-agent-prompt.md) (remaining behaviour).
