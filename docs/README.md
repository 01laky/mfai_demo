# Documentation hub (`docs/`)

Všetka **centrálna** dokumentácia monorepa **`_mfai_demo`** je tu. **Submodule README** ostávajú v `be_demo/`, `fe_demo/`, … — index nájdeš v [`readmes/README.md`](./readmes/README.md).

**Prečo priečinky:** [STRUCTURE.md](./STRUCTURE.md) (krátky návrh oproti len `components` / `prompts` / `readmes`).

---

## [`guides/`](./guides/) — referenčné návody (EN + nástroje)

| Document | Contents |
|----------|----------|
| [development.md](./guides/development.md) | CI, Node/Python, Husky/commitlint, root skripty (`ci-local.sh`, `lint-all.sh`, …), chyby API v prehliadači, testy, mriežka na face home, odkazy. |
| [authentication-and-sessions.md](./guides/authentication-and-sessions.md) | OAuth2, JWT, `rememberMe`, konfigurácia, FE/admin, testy. |
| [acl-and-capabilities.md](./guides/acl-and-capabilities.md) | Permission keys, `GET …/api/me/capabilities`, gates, file map, integration users, test index. |
| [api-oauth-stories-curl.md](./guides/api-oauth-stories-curl.md) | OAuth2 + Stories cez **curl**. |
| [wall-tickets.md](./guides/wall-tickets.md) | Wall tickets API, moderácia, Redis worker. |
| [chat-rooms-testing-and-operations.md](./guides/chat-rooms-testing-and-operations.md) | Face chat rooms — testy a prevádzka. |
| [security-crypto-sockets.md](./guides/security-crypto-sockets.md) | TLS, JWT kľúče, WebSockets backlog. |
| [dev-https.md](./guides/dev-https.md) | Lokálne HTTPS certy (`dev/`), porty, Docker. |
| [git-submodules.md](./guides/git-submodules.md) | Nastavenie a práca so submodulmi. |
| [husky-setup.md](./guides/husky-setup.md) | Husky / hooks (historický návod). |
| [boilerplate-checklist.md](./guides/boilerplate-checklist.md) | Checklist šablóny. |
| [proposal-mfai-demo-state.md](./guides/proposal-mfai-demo-state.md) | Návrh / stav (archív). |

---

## [`components/`](./components/) — hotové stavebné celky

Krátke karty **čo to je** a **kde to je v kóde**; detail ostáva v `guides/`.

| Document | Contents |
|----------|----------|
| [acl-capabilities-module.md](./components/acl-capabilities-module.md) | ACL katalóg, capabilities API, FE/admin `src/acl/`. |

*(Pridávaj ďalšie súbory podľa rovnakého vzoru.)*

---

## [`prompts/`](./prompts/) — prompty pre AI

| Document | Contents |
|----------|----------|
| [super-admin-api.md](./prompts/super-admin-api.md) | Analýza SUPER_ADMIN-only API, MVP, **copy-paste prompt** na implementáciu. |

---

## [`readmes/`](./readmes/) — README index + SK prehľady

| Document | Contents |
|----------|----------|
| [README.md](./readmes/README.md) | Odkazy na README jednotlivých submodulov + tento priečinok. |
| [fe-demo-overview-sk.md](./readmes/fe-demo-overview-sk.md) | Prehľad `fe_demo` (SK). |
| [admin-demo-overview-sk.md](./readmes/admin-demo-overview-sk.md) | Prehľad `admin_demo` (SK). |
| [authentication-and-sessions-sk.md](./readmes/authentication-and-sessions-sk.md) | Auth / JWT / relácie (SK). |
| [redis-subrepo-sk.md](./readmes/redis-subrepo-sk.md) | Submodule `redis_demo` (SK). |

---

## Externé / koreň repa

| Path | Contents |
|------|----------|
| [`../README.md`](../README.md) | Hlavný vstup monorepa (skrátený), quick start. |
| [`../be_demo/STORIES_API.md`](../be_demo/STORIES_API.md) | Referencia Stories API. |

**Nové dokumenty:** preferuj `guides/` (referencia), `components/` (katalóg), `prompts/` (AI), alebo `readmes/` (SK / index). Aktualizuj tento hub a prípadne [`guides/development.md`](./guides/development.md).
