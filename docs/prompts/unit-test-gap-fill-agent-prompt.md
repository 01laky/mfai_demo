# Unit-test gap fill — monorepo (agent prompt)

**Purpose:** Systematically **add and strengthen automated tests** across **`fe_demo`**, **`admin_demo`**, **`be_demo`**, **`ai_demo`**, and **repo scripts** where coverage is thin or risk is high — **without** making **component render / DOM snapshot testing** the primary strategy. Use this document as a **copy-paste agent brief** for one or a series of PRs.

**Non-goals (explicit):**

- **Not** the main effort: full **React Testing Library** tree walks, pixel-perfect UI snapshots, or “render whole page and assert text” suites unless the task owner explicitly expands scope.
- **Not** replacing **E2E** (Cypress, Playwright); this prompt targets **fast unit / narrow integration** tests.
- **Not** changing product behavior unless a test reveals a **confirmed bug** (then fix + test in the same PR with clear commit separation if the team prefers).

**Allowed / encouraged test shapes:**

- **Pure functions** in `*.ts` (no React): routing math, JWT parsing, env validation, ACL matrices, grid layout calculators, DTO mappers.
- **Hook tests** with **minimal** providers (`MemoryRouter`, `QueryClientProvider`, wrapper context) asserting **returned values / side effects on mocks**, not full component trees.
- **API adapter tests** with `fetch` / `axios` mocked — assert URL, method, headers, and error mapping.
- **C#** unit + narrow integration tests following existing **`BeDemo.Api.Tests`** patterns (`WebApplicationFactory`, auth headers, etc.).

---

## 1. Baseline inventory (**required** before writing tests)

**(required)** For each submodule touched, record:

1. **Existing tests:** list `**/__tests__/**`, `**/*.test.ts`, `**/*.test.tsx`, `**/*Tests.cs`, `**/test_*.py`.
2. **High-churn / high-risk source dirs** touched in the last N months (git log) — prioritize those if time-boxed.
3. **Coverage tool (optional but valuable):** if the stack already supports it, run one pass (e.g. Vitest `--coverage`, Coverlet for .NET) and attach **before**/**after** numbers for the PR series.

**(required)** Attach the inventory table to the first PR of the series (or to a tracking issue).

---

## 2. Priority matrix (P0 → P2)

Use **P0** first. Do **not** start **P2** until **P0** for the chosen app is addressed or explicitly deferred in writing.

| Tier   | Meaning                                              | Examples                                                                                          |
| ------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **P0** | Security, auth, data loss, wrong tenant/face routing | JWT/session helpers, face-prefixed API base URL logic, ACL/capabilities parsing, admin auth hooks |
| **P1** | User-visible correctness, money/time, pagination     | List filters, grid layout math, React Query cache keys, error toast mapping                       |
| **P2** | Hygiene, DX, scripts                                 | Logger format, i18n key helpers, `scripts/*.sh` smoke tests                                       |

---

## 3. `fe_demo` — recommended targets (no render-first)

### 3.1 Routing and URL construction (**P0**)

**Why:** Wrong path ⇒ wrong API prefix or wrong face ⇒ severe bugs.

**Targets (illustrative — verify paths on your branch):**

- `src/hooks/useLocalizedLink.ts`, `useLocalizedNavigate.ts` — logic combines `getTranslatedRoute`, URL `lang`, guest vs authenticated, `selectedFace.index`. Prefer **extract** `buildLocalizedPath({...})` into `src/utils/localizedPath.ts` (or similar) and **unit test** the pure function with matrix cases:
  - guest + selected public face ⇒ path includes `/${lang}/${faceIndex}/...`
  - authenticated ⇒ `/${lang}/...` without duplicate face
  - missing `lang` in URL ⇒ fallback to `currentLanguage`
  - empty / root paths, trailing slashes (normalize once, test behavior)

- `src/api/faceApiRouting.ts` (and related) — extend beyond existing `__tests__/facePathRouting.test.ts`:
  - pathnames with **double slashes**, encoded characters, unknown first segment, `/api/oauth2/...` excluded from face rules
  - cache invalidation of internal sets if i18n keys change (if applicable)

**Edge cases (required in test names or comments):**

- All supported languages from `supportedLanguages`.
- Second path segment in **static route list** vs real **face index** ambiguity.

### 3.2 Cryptography / token utilities (**P0**)

**Targets:**

- `src/utils/jwtUtils.ts` (or equivalent) — expiry, malformed base64, missing segments, clock skew assumptions documented in tests.

**Forbidden:** embedding real production secrets; use **fixtures** only.

### 3.3 Configuration (**P0 / P1**)

**Targets:**

- `src/config/env.ts` — validation, defaults, “build fails fast” vs “runtime warning” policy **as coded**.

### 3.4 Async data hooks and cancellation (**P1**)

**Targets:**

- `src/hooks/useWallHostViewer.ts` — `enabled` toggles, unmount during in-flight request, `token` / `faceId` transitions.
- Thin wrappers around **fetch** for domain modules under `src/api/**` (hand-written clients, not only OpenAPI codegen if present).

**Technique:** `vi.fn` global `fetch`, or small wrapper `requestJson` tested once.

### 3.5 Deterministic layout math (**P1**)

**Targets:**

- e.g. `src/utils/computeAlbumGridLayout.ts` (and siblings) — property-style tests or tables: width/height → `{ cols, rows, tilePx, itemsPerPage }` with **min/max** clamps, zero/negative dimensions.

### 3.6 Contexts — extract then test (**P0 / P1**)

**Targets:**

- `AuthContext`, `FaceConfigContext`, `MessengerContext` — **do not** snapshot the provider. Extract:
  - `loadAuthStateFromStorage(storage, deps)` → pure or injectable
  - `syncTokenFromReactQuery(...)` → pure
  - reducers for messenger message list (dedupe, ordering)

Unit-test extracted modules; keep context as thin wiring.

### 3.7 ACL / capabilities (**P0** — extend existing)

**Targets:**

- `src/acl/__tests__/permissions.test.ts` — add rows for **every** capability key the backend can emit; regression when OpenAPI / DTO adds fields.

### 3.8 i18n helpers (**P2**)

If custom helpers exist beyond `routeTranslations` (already tested), mirror the same style in `src/utils/__tests__/`.

---

## 4. `admin_demo` — recommended targets

### 4.1 React Query API hooks (**P0 / P1**)

**Parity rule:** every `src/hooks/api/use*.ts` should have a sibling `__tests__/use*.test.ts` **unless** the hook is a one-line pass-through (document the exception in PR).

**Known gap pattern:** `usePageTypesApi.ts` — add tests analogous to `usePagesApi.test.ts` / `useFacesApi.test.ts`:

- happy path returns data shape
- error path surfaces `Error` / message used by UI
- `queryKey` stability (no accidental refetch storms)

### 4.2 ACL (**P0**)

Extend `src/acl/__tests__/permissions.test.ts` when backend adds roles.

### 4.3 API core (**P1**)

**Targets:**

- `src/api/config.ts`, `core/request.ts`, `ApiError` mapping — table-driven tests: status codes → user-visible or loggable outcome.

### 4.4 Logger (**P2**)

`src/utils/__tests__/logger.test.ts` — extend only if logger behavior is non-trivial (PII redaction, levels).

---

## 5. `be_demo` — where to add tests (incremental)

**Context:** `BeDemo.Api.Tests` already contains broad **OAuth/JWT/refresh/security/SignalR** coverage including many `*Edge*` / `*Boundary*` files. This prompt’s value is **closing holes**, not duplicating happy paths.

**(required)** For each PR:

1. Grep `BeDemo.Api/Controllers` and `BeDemo.Api/Services` (and `Hubs`) for **public surface changed** in the same release.
2. If a controller lacks a `*ControllerTests.cs` sibling scenario, add **minimal** tests: authZ (401/403), validation (400), success shape.

**Specific follow-ups:**

- **`OAuthJwksController`** — if not fully covered by `OAuthJwksTests.cs`, add cases for **cache**, **invalid key id**, **rotation** semantics the API promises.
- **New services** — rule: new `Services/FooService.cs` ships with **`FooServiceTests.cs`** or a referenced issue explaining deferral.

---

## 6. `ai_demo`

**Targets:**

- `pytest` modules — expand beyond smoke: gRPC error status, invalid protobuf, timeout behavior (where mocked).

**(required)** If adding network tests, mark **hermetic** (no real external calls) or skip in CI with explicit env gate documented in `ai_demo/README.md`.

---

## 7. Monorepo `scripts/`

**P2** — only if scripts gate CI:

- `scripts/check-mermaid-docs.sh` — golden input/output files in `scripts/__fixtures__/` or `docs/__test__/` with a tiny runner.
- `scripts/ci-local.sh` — document “not unit tested” vs add dry-run mode testable in bash **bats** (team choice).

---

## 8. Implementation standards (**required**)

### 8.1 Naming and placement

- **Vitest:** colocate `__tests__/*.test.ts` next to module or mirror `src/foo.ts` → `src/foo.test.ts` **only** if the repo already uses that pattern; **prefer existing** `fe_demo` / `admin_demo` layout.
- **.NET:** keep `BeDemo.Api.Tests` project; file names `ThingUnderTestTests.cs`.

### 8.2 Assertions

- Prefer **exact** expected strings for URLs and error codes where stable.
- Avoid **over-mocking** internal implementation details; mock **IO boundaries** (network, `localStorage`, `Date` only when unavoidable).

### 8.3 Flakiness

- Use **fake timers** (`vi.useFakeTimers`) only in tests that need them; always **restore** in `afterEach`.
- Async: **`await waitFor`** with explicit timeout only when needed; prefer **`expect.poll`**-style patterns Vitest supports or retry helper consistent with repo.

### 8.4 Language

- Match existing test file language (**English** descriptions in `be_demo`; match SPA test file language already in use).

---

## 9. Verification (**required**)

- [ ] `fe_demo`: `yarn test` (and `yarn validate` if the PR touches linted code).
- [ ] `admin_demo`: `yarn test` and `yarn validate`.
- [ ] `be_demo`: `dotnet test BeDemo.Api.Tests` (or solution test command used in CI).
- [ ] `ai_demo`: `pytest` (or documented subset).
- [ ] No **new** `eslint-disable` for test code except rare flakiness with **issue link** + removal date.

---

## 10. Deliverables (**required**)

- [ ] PR description lists **P-tier** addressed and **modules** touched.
- [ ] New tests map to **risk** (one short paragraph).
- [ ] If coverage tool run: **before/after** snippet or “not measured — time-boxed”.
- [ ] Submodule + parent bump policy respected if multiple repos change.

---

## 11. Anti-patterns (**forbidden** without task owner approval)

- Huge **RTL** trees for every page.
- Copy-pasting **200-line** mock setups per test — extract **factories** (`makeQueryClient()`, `makeRouterWrapper()`).
- Tests that assert **implementation** (private function call order) instead of **observable outcome**.
- **Real** calls to production APIs or real JWTs in CI.

---

## 12. Reference templates in this monorepo

Study and **mirror style**, not necessarily file length:

- `fe_demo/src/api/__tests__/facePathRouting.test.ts`
- `fe_demo/src/acl/__tests__/permissions.test.ts`
- `fe_demo/src/utils/__tests__/routeTranslations.test.ts`
- `admin_demo/src/hooks/api/__tests__/usePagesApi.test.ts` (and siblings)
- `be_demo/BeDemo.Api.Tests/JwtValidationEdgeTests.cs`, `RefreshTokenEdgeCaseTests.cs`, `SecurityEdgeCaseTests.cs` — structure for edge naming and arrange/act/assert

---

## 13. Optional series plan (for PM / agent sequencing)

| PR # | Scope                                      | Apps                 |
| ---- | ------------------------------------------ | -------------------- |
| 1    | Pure routing + JWT + env                   | `fe_demo`            |
| 2    | `useWallHostViewer` + one hand-written API | `fe_demo`            |
| 3    | Hook parity (`usePageTypesApi` + gaps)     | `admin_demo`         |
| 4    | BE service/controller gap close            | `be_demo`            |
| 5    | `ai_demo` gRPC edge + script smoke         | `ai_demo`, `scripts` |

Adjust order if security incidents dictate **P0** elsewhere first.

---

## 14. References

- Vitest: [https://vitest.dev/](https://vitest.dev/)
- Testing Library guidance (use sparingly per this prompt): [https://testing-library.com/docs/react-testing-library/intro/](https://testing-library.com/docs/react-testing-library/intro/)
- xUnit + ASP.NET Core testing: [https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- Related strict security + tests prompt: [security-hardening-full-stack-edge-tests-agent-prompt.md](./security-hardening-full-stack-edge-tests-agent-prompt.md)
