# Unit-test gap fill — monorepo (agent prompt)

**Purpose:** Systematically **add and strengthen automated tests** across **`fe_demo`**, **`admin_demo`**, **`be_demo`**, **`ai_demo`**, and **repo scripts** where coverage is thin or risk is high — **without** making **component render / DOM snapshot testing** the primary strategy. Use this document as a **copy-paste agent brief** for one or a series of PRs.

**(required)** Start at **§0** (compliance checklist and labels) before writing tests; complete **§15** (master checklist) while implementing; finish **§9** and **§10** before requesting review.

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

## 0. Compliance — read every part (**required**)

**(required)** Complete **§0** first, then **§1–§12** and **§15** for **every submodule** this PR touches — do not skip subsections for a touched app unless **§0.2** marks **N/A** with a valid reason (see collapse rule below). **§13** is **optional** sequencing only. **§14.1** is a **required** skim of links relevant to your stack; **§14.2** is **required — if** the PR intersects security hardening, dependency majors, or documentation diagrams.

### 0.1 Labels (**required** — use consistently in PR text)

| Label                           | Meaning                                                                                                             |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **(required)**                  | Must be satisfied before merge, or **explicitly deferred** in the PR description with approver and follow-up issue. |
| **(required — if _condition_)** | Mandatory whenever _condition_ is true (e.g. submodule touched, file class exists).                                 |
| **(optional)**                  | Out of default scope; skip only with written deferral.                                                              |

### 0.2 Section coverage checklist (**required** — copy into PR description and tick)

Replace ✓ / N/A honestly. For every **N/A**, add **one short reason** (e.g. “no `fe_demo` files changed”). For a **full line-by-line** execution list aligned to every subsection of this prompt, complete **§15** as well (same ✓ / N/A discipline).

| §          | Expectation                                                                       | Status (✓ / N/A) | If N/A, reason |
| ---------- | --------------------------------------------------------------------------------- | ---------------- | -------------- |
| **§1**     | Inventory                                                                         |                  |                |
| **§2**     | P0→P2 discipline                                                                  |                  |                |
| **§3**     | `fe_demo` — entire section read; subsections implemented **or** N/A per row below |                  |                |
| **§3.1**   | Routing / URL                                                                     |                  |                |
| **§3.2**   | JWT / crypto utils                                                                |                  |                |
| **§3.3**   | `env` config                                                                      |                  |                |
| **§3.4**   | Async hooks / `useAuthApi` / TanStack v5                                          |                  |                |
| **§3.4.1** | OpenAPI vs hand-written clients                                                   |                  |                |
| **§3.5**   | Layout math                                                                       |                  |                |
| **§3.6**   | Contexts — extract & test                                                         |                  |                |
| **§3.7**   | ACL / capabilities                                                                |                  |                |
| **§3.8**   | i18n helpers                                                                      |                  |                |
| **§3.9**   | SignalR / `EventSource`                                                           |                  |                |
| **§4**     | `admin_demo` — entire section read; **§4.1–§4.4** implemented **or** N/A          |                  |                |
| **§5**     | `be_demo` + **§5.1–§5.3**                                                         |                  |                |
| **§6**     | `ai_demo` + **§6.1**                                                              |                  |                |
| **§7**     | `scripts/`                                                                        |                  |                |
| **§8**     | **§8.1–§8.15** (all read; apply sub-bullets per touched stack)                    |                  |                |
| **§9**     | Verification commands                                                             |                  |                |
| **§10**    | Deliverables                                                                      |                  |                |
| **§11**    | Anti-patterns acknowledged                                                        |                  |                |
| **§12**    | Reference templates opened / mirrored                                             |                  |                |
| **§13**    | Series plan (optional)                                                            |                  |                |
| **§14**    | External + related prompts                                                        |                  |                |
| **§15**    | Master checklist (**§15**) — full execution list                                  |                  |                |

**(required)** **§9** and **§10** must be ✓ (no N/A) for every PR. **§15**: every **subsection §15.1–§15.16** must be **✓** (all applicable inner checkboxes done) or **N/A** once with reason (e.g. **`§15.5` N/A — no `fe_demo` changes**); do not leave subsection headers ambiguous.

**(required — if whole app untouched)** You may collapse **§3** / **§4** / **§5** / **§6** / **§7** to a **single** row **N/A** with reason **`no {fe_demo|admin_demo|be_demo|ai_demo|scripts} changes`** instead of filling each subsection row — but **any app that _is_ touched** must use the granular rows for that app.

---

## 1. Baseline inventory (**required** before writing tests)

**(required)** For each submodule touched, record:

1. **Existing tests:** list `**/__tests__/**`, `**/*.test.ts`, `**/*.test.tsx`, `**/*Tests.cs`, `**/test_*.py`.
2. **High-churn / high-risk source dirs** touched in the last N months (git log) — prioritize those if time-boxed.
3. **Coverage tool (optional but valuable):** if the stack already supports it, run one pass (e.g. Vitest `--coverage`, Coverlet for .NET) and attach **before**/**after** numbers for the PR series.

**(required)** Attach the inventory table to the first PR of the series (or to a tracking issue).

---

## 2. Priority matrix (P0 → P2) (**required**)

**(required)** Use **P0** first. Do **not** start **P2** until **P0** for the chosen app is addressed or explicitly deferred in writing.

| Tier   | Meaning                                              | Examples                                                                                          |
| ------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **P0** | Security, auth, data loss, wrong tenant/face routing | JWT/session helpers, face-prefixed API base URL logic, ACL/capabilities parsing, admin auth hooks |
| **P1** | User-visible correctness, money/time, pagination     | List filters, grid layout math, React Query cache keys, error toast mapping                       |
| **P2** | Hygiene, DX, scripts                                 | Logger format, i18n key helpers, `scripts/*.sh` smoke tests                                       |

---

## 3. `fe_demo` — recommended targets (**required** read for any `fe_demo` test PR; no render-first)

**(required)** If this PR changes **`fe_demo`** tests or testable modules, read **§3.1–§3.9** and satisfy **§0.2** rows for `fe_demo`. If **`fe_demo` is untouched**, mark **§3** (and **§3.1–§3.9** or the collapsed **§3** row per **§0.2** rule) **N/A** with reason **`no fe_demo changes`**.

### 3.1 Routing and URL construction (**required — P0**)

**Why:** Wrong path ⇒ wrong API prefix or wrong face ⇒ severe bugs.

**Targets (illustrative — verify paths on your branch):**

- `src/hooks/useLocalizedLink.ts`, `useLocalizedNavigate.ts` — logic combines `getTranslatedRoute`, URL `lang`, guest vs authenticated, `selectedFace.index`. Prefer **extract** `buildLocalizedPath({...})` into `src/utils/localizedPath.ts` (or similar) and **unit test** the pure function with matrix cases:
  - guest + selected public face ⇒ path includes `/${lang}/${faceIndex}/...`
  - authenticated ⇒ `/${lang}/...` without duplicate face
  - missing `lang` in URL ⇒ fallback to `currentLanguage`
  - empty / root paths, trailing slashes (normalize once, test behavior)
  - **`navigate` vs `replace`:** if the hook exposes options (`replace`, `state`), assert the **mocked** `navigate` / `history` receives the correct second argument and that `buildLocalizedPath` output is the first argument (no double-encoding of query/hash).
  - **Preserve query/hash:** when input path carries `?` or `#`, tests must lock current behavior (strip vs preserve) so refactors do not silently drop search params.
  - **Hook-level smoke (optional, still not render-first):** if you keep logic inside the hook, wrap with `MemoryRouter` + minimal `FaceConfigContext` stub and assert **`useLocalizedNavigate` returns a function** that calls `navigate` with the built path — still avoid full page render; cap at one small wrapper per file.

- `src/api/faceApiRouting.ts` (and related) — extend beyond existing `__tests__/facePathRouting.test.ts`:
  - pathnames with **double slashes**, encoded characters, unknown first segment, `/api/oauth2/...` excluded from face rules
  - cache invalidation of internal sets if i18n keys change (if applicable)

**Edge cases (required in test names or comments):**

- All supported languages from `supportedLanguages`.
- Second path segment in **static route list** vs real **face index** ambiguity.

### 3.2 Cryptography / token utilities (**required — P0**)

**Targets:**

- `src/utils/jwtUtils.ts` (or equivalent) — expiry, malformed base64, missing segments, clock skew assumptions documented in tests.

**Forbidden:** embedding real production secrets; use **fixtures** only.

### 3.3 Configuration (**required — P0 / P1**)

**Targets:**

- `src/config/env.ts` — validation, defaults, “build fails fast” vs “runtime warning” policy **as coded**.

### 3.4 Async data hooks and cancellation (**required — P1**)

**Targets:**

- `src/hooks/useWallHostViewer.ts` — `enabled` toggles, unmount during in-flight request, `token` / `faceId` transitions.
- Thin wrappers around **fetch** for domain modules under `src/api/**` (hand-written clients, not only OpenAPI codegen if present).
- **`src/hooks/api/useAuthApi.ts` (parity with `admin_demo`):** same expectations as admin hook tests — login/register/refresh/logout paths, **error surfaces** (`Error` message or mapped shape), **`queryKey` parts** stable when `userId` / `faceId` / token presence changes, and **no duplicate in-flight** mutations where the code intends to dedupe. Add `__tests__/useAuthApi.test.ts` if missing.

**Technique:** `vi.fn` global `fetch`, or small wrapper `requestJson` tested once. See **§8.5** for when to prefer **MSW** instead.

**TanStack Query v5 (required knowledge for hook tests):**

- Prefer **`gcTime`** in test setup where the codebase migrated from v4 `cacheTime`; do not copy stale snippets from older docs.
- Default **`staleTime`** is often `0` — tests that count fetches must not assume implicit dedupe unless `staleTime` is set in the hook or `QueryClient` default options.
- Use **`queryClient.setQueryData`** / **`invalidateQueries`** in arrange steps; assert **`queryClient.getQueryState`** or **mocked `fetch` call count** for refetch behavior.
- For mutations, assert **`onSuccess` / `onSettled`** side effects on mocks (e.g. token written to storage adapter) without relying on internal `mutationFn` variable names.

### 3.4.1 OpenAPI-generated clients vs hand-written adapters (**required — P1**; **N/A** only if `src/api/**` has no hand-written network layer)

- If `src/api/**` mixes **generated** OpenAPI clients and **hand-written** `fetch` helpers, **hand-written** URL assembly and error mapping **must** have direct unit tests.
- For generated code: do **not** snapshot the whole generated file; instead test **your** thin wrapper (base URL, auth header injection, `unwrap` / error mapper) or rely on contract tests (**§5.3**) if the team adopts them.
- When OpenAPI spec changes, extend tests that assert **DTO field presence** only for fields the UI **depends on** (avoid brittle “every key” assertions on large objects).

### 3.5 Deterministic layout math (**required — P1**; **N/A** only if no layout/grid utilities exist in tree)

**Targets:**

- e.g. `src/utils/computeAlbumGridLayout.ts` (and siblings) — **table-driven** tests: width/height → `{ cols, rows, tilePx, itemsPerPage }` with **min/max** clamps, zero/negative dimensions.
- **Property-style / fuzz (optional, P1 when math is security- or money-adjacent):** use `fast-check` or a small loop over randomized **bounded** inputs (seed logged in comment on failure) to assert **invariants**: e.g. `cols * tilePx ≤ width + epsilon`, `itemsPerPage ≥ 1`, monotonicity where required. Keep runs fast (<100 ms per file); shrink failing cases to a minimal repro and add a **regression row** to the static table.

### 3.6 Contexts — extract then test (**required — P0 / P1**)

**Targets:**

- `AuthContext`, `FaceConfigContext`, `MessengerContext` — **do not** snapshot the provider. Extract:
  - `loadAuthStateFromStorage(storage, deps)` → pure or injectable
  - `syncTokenFromReactQuery(...)` → pure
  - reducers for messenger message list (dedupe, ordering)

Unit-test extracted modules; keep context as thin wiring.

### 3.7 ACL / capabilities (**required — P0** — extend existing)

**Targets:**

- `src/acl/__tests__/permissions.test.ts` — add rows for **every** capability key the backend can emit; regression when OpenAPI / DTO adds fields.

### 3.8 i18n helpers (**required — P2**; **N/A** if no custom i18n helpers beyond already-tested `routeTranslations`)

If custom helpers exist beyond `routeTranslations` (already tested), mirror the same style in `src/utils/__tests__/`. **(required — if helpers exist)** add or extend tests.

### 3.9 Realtime: SignalR / `EventSource` / streaming hooks (**required — P1** if app uses realtime; **N/A** otherwise)

**Targets:** any hook or service under `src/**` that wraps `@microsoft/signalr` or `EventSource`.

**Approach:**

- **Do not** spin a real server in unit tests. Inject a **fake hub connection** interface (`start`, `on`, `off`, `invoke`, `state`) and assert **handlers are registered**, **cleanup on unmount** (`off` / `stop`), and **reconnect policy** (e.g. backoff flags) at the boundary.
- For **`EventSource`**, `vi.stubGlobal('EventSource', MockEventSource)` with a minimal class that supports `onmessage` / `onerror` / `close` and record which URL was opened.
- If the app uses **shared connection singletons**, reset module state between tests (`vi.resetModules` + dynamic import) only when unavoidable — prefer **injectable factory** in source to avoid flakiness.

---

## 4. `admin_demo` — recommended targets (**required** read for any `admin_demo` test PR)

**(required)** If this PR changes **`admin_demo`** tests or testable modules, read **§4.1–§4.4** and satisfy **§0.2** rows for `admin_demo`. If **`admin_demo` is untouched**, mark **§4** **N/A** with **`no admin_demo changes`**.

### 4.1 React Query API hooks (**required — P0 / P1**)

**Parity rule:** every `src/hooks/api/use*.ts` should have a sibling `__tests__/use*.test.ts` **unless** the hook is a one-line pass-through (document the exception in PR).

**TanStack Query v5:** same bullets as **§3.4** (`gcTime`, `staleTime`, mutation side effects). Share **`makeQueryClient()`** factory (**§8.6**) between admin and fe tests where patterns align.

**Known gap pattern:** `usePageTypesApi.ts` — add tests analogous to `usePagesApi.test.ts` / `useFacesApi.test.ts`:

- happy path returns data shape
- error path surfaces `Error` / message used by UI
- `queryKey` stability (no accidental refetch storms)

### 4.2 ACL (**required — P0**)

Extend `src/acl/__tests__/permissions.test.ts` when backend adds roles.

### 4.3 API core (**required — P1**)

**Targets:**

- `src/api/config.ts`, `core/request.ts`, `ApiError` mapping — table-driven tests: status codes → user-visible or loggable outcome.

### 4.4 Logger (**required — P2**; **N/A** if logger unchanged and already covered)

`src/utils/__tests__/logger.test.ts` — extend only if logger behavior is non-trivial (PII redaction, levels).

---

## 5. `be_demo` — where to add tests (**required** read for any `be_demo` test PR; incremental)

**Context:** `BeDemo.Api.Tests` already contains broad **OAuth/JWT/refresh/security/SignalR** coverage including many `*Edge*` / `*Boundary*` files. This prompt’s value is **closing holes**, not duplicating happy paths.

**(required)** If this PR changes **`be_demo`** tests or production code under test, read **§5** (including **§5.1–§5.3**) and satisfy **§0.2** rows for `be_demo`. If **`be_demo` is untouched**, mark **§5** **N/A** with **`no be_demo changes`**.

**(required)** For each PR:

1. Grep `BeDemo.Api/Controllers` and `BeDemo.Api/Services` (and `Hubs`) for **public surface changed** in the same release.
2. If a controller lacks a `*ControllerTests.cs` sibling scenario, add **minimal** tests: authZ (401/403), validation (400), success shape.

**Specific follow-ups:**

- **`OAuthJwksController`** — if not fully covered by `OAuthJwksTests.cs`, add cases for **cache**, **invalid key id**, **rotation** semantics the API promises.
- **New services** — rule: new `Services/FooService.cs` ships with **`FooServiceTests.cs`** or a referenced issue explaining deferral.

### 5.1 EF Core test doubles (**required — if** new or changed **DB-heavy** / persistence tests; **N/A** otherwise — state in **§0.2**)

Choose one strategy per test class and **document in file header comment** if non-obvious:

| Strategy                           | When to use                                                                   | Pitfalls                                                                 |
| ---------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **In-memory provider**             | Fast tests of queries/filters that do not rely on SQLite/SQL Server semantics | No real constraints/transactions; **different null/ordering** edge cases |
| **SQLite** (shared or file)        | Closer to relational behavior, migrations smoke                               | Types differ from SQL Server; raw SQL may diverge                        |
| **`WebApplicationFactory` + real** | Integration tests already in repo                                             | Slower; isolate with collection fixtures                                 |

- Prefer **existing** patterns in `BeDemo.Api.Tests` over introducing a second style.
- When tests seed users/roles/faces, reuse or extend **`IntegrationTestSeed`** (or equivalent) so **IDs and roles stay consistent**; do not duplicate magic GUIDs across files — centralize in seed helpers.

### 5.2 Security-sensitive test data (**required — P0** for every `be_demo` test PR)

- **Never** commit real production JWTs, refresh tokens, or API keys. Use **short synthetic** base64-like strings that still **parse** through your helpers, or build tokens with **test-only signing keys** loaded from **embedded resources** or env vars **not** stored in git.
- For rate-limit / lockout tests, use **dedicated test users** from seed data with documented passwords only in test constants (not copied from prod).

### 5.3 Optional contract / OpenAPI alignment (**optional — P2**)

- If the repo adds **OpenAPI snapshot** or **Schemathesis**-style checks in CI, unit tests should **not duplicate** every field — link the CI job in the PR and keep unit tests focused on **business invariants**.
- If not present, this item is **optional** backlog; do not block P0 hook tests on it. **(required)** Still mark **§0.2** row §5.3 as **N/A** with reason when skipping.

---

## 6. `ai_demo` (**required** read for any `ai_demo` test PR)

**(required)** If the PR does **not** touch **`ai_demo`**, mark **§6** / **§6.1** as **N/A** in **§0.2** with reason **`no ai_demo changes`**.

**Targets:**

- `pytest` modules — expand beyond smoke: gRPC error status, invalid protobuf, timeout behavior (where mocked).

**(required)** If adding network tests, mark **hermetic** (no real external calls) or skip in CI with explicit env gate documented in `ai_demo/README.md`.

### 6.1 Pytest structure (**required** for any non-trivial `ai_demo` test addition; **N/A** only for single-file smoke with no new fixtures/markers — state that in PR)

- **`conftest.py`:** shared fixtures for **channel stubs**, **fake credentials**, and **timeouts**. Prefer **function-scoped** fixtures unless a session-scoped resource is expensive and safe.
- **`pytest.ini` / `pyproject.toml` markers:** define `@pytest.mark.integration`, `@pytest.mark.slow`, `@pytest.mark.grpc` and default **`pytest -m "not integration"`** in CI if integration tests need extra services.
- **Parametrize** error codes (`grpc.StatusCode.DEADLINE_EXCEEDED`, `UNAVAILABLE`, `INVALID_ARGUMENT`) instead of one test per file copy-paste.
- **Determinism:** fix random seeds where fuzzing; cap iterations for CI time budgets.

---

## 7. Monorepo `scripts/` (**required** read if PR touches `scripts/`; **optional** implementation — P2 unless scripts gate CI)

**(required)** If the PR does **not** touch **`scripts/`**, mark **§7** **N/A** in **§0.2** with **`no scripts changes`**.

**P2** — only if scripts gate CI:

- `scripts/check-mermaid-docs.sh` — golden input/output files in `scripts/__fixtures__/` or `docs/__test__/` with a tiny runner.
- `scripts/ci-local.sh` — document “not unit tested” vs add dry-run mode testable in bash **bats** (team choice).

---

## 8. Implementation standards (**required**)

**(required)** Read **§8.1–§8.15** before merge. For subsections marked **N/A** in **§0.2**, give a one-line reason (e.g. “no Vitest config change” for **§8.12**).

### 8.1 Naming and placement (**required**)

- **Vitest:** colocate `__tests__/*.test.ts` next to module or mirror `src/foo.ts` → `src/foo.test.ts` **only** if the repo already uses that pattern; **prefer existing** `fe_demo` / `admin_demo` layout.
- **.NET:** keep `BeDemo.Api.Tests` project; file names `ThingUnderTestTests.cs`.

### 8.2 Assertions (**required**)

- Prefer **exact** expected strings for URLs and error codes where stable.
- Avoid **over-mocking** internal implementation details; mock **IO boundaries** (network, `localStorage`, `Date` only when unavoidable).

### 8.3 Flakiness controls (**required**)

- Use **fake timers** (`vi.useFakeTimers`) only in tests that need them; always **restore** in `afterEach`.
- Async: **`await waitFor`** with explicit timeout only when needed; prefer **`expect.poll`**-style patterns Vitest supports or retry helper consistent with repo.

**Flaky-test policy (when CI fails intermittently):**

1. **Reproduce locally** with same command CI uses (`yarn test` / `dotnet test` / `pytest`) at least **3** runs or `vitest --repeat 10` for the single file.
2. If order-dependent: fix **shared mutable state** (global fetch, module cache, `Date.now`) — do not `@skip` without owner approval.
3. If timing-dependent: prefer **`waitFor`** / fake timers / longer `hookTimeout` **only** in that `describe` block.
4. **Quarantine** as last resort: move to separate job or mark with **issue URL**, **owner**, and **removal milestone** in test comment (not silent `test.skip`).

### 8.4 Language (**required**)

- Match existing test file language (**English** descriptions in `be_demo`; match SPA test file language already in use).

### 8.5 MSW vs `fetch` mock — decision matrix (**required** read for any FE test PR; **required** apply matrix when adding/changing **API** tests)

| Situation                                            | Prefer                                                        | Rationale                    |
| ---------------------------------------------------- | ------------------------------------------------------------- | ---------------------------- |
| Single endpoint, assert URL + headers + JSON once    | **`vi.fn` on `globalThis.fetch`** or thin `requestJson`       | Minimal setup, fast          |
| Many endpoints, shared error shapes, parallel suites | **MSW** (`setupServer` / `setupWorker` in tests)              | Central handlers, less drift |
| Streaming / SSE / multipart                          | **Dedicated mock** (ReadableStream stub) — MSW often overkill | Clear failure messages       |
| Regressions on **status + body** combinations        | Either; add **table** of `[status, body, expectedErrorCode]`  | Documentation value          |

- **Rule:** pick one style **per test file**; do not mix MSW and raw `fetch` spy in the same file unless transitioning (one PR, comment `TODO(msw)` with issue).

### 8.6 Factories and shared setup (**required**)

- Extract **`makeQueryClient(overrides?)`**, **`makeWrapper({ route, faceId })`**, **`makeAuthContextValue(...)`** into `__tests__/testUtils.ts` (or colocated `*.test-utils.ts`) once **second** test duplicates setup **>~15 lines**.
- Factories must use **defaults** that satisfy **happy path**; tests override only fields under assertion.
- **No** `beforeAll` that mutates shared `QueryClient` unless every test resets queries in `beforeEach`.

### 8.7 Fixtures, golden files, and snapshots (**required** read; apply **only** if PR introduces fixtures/goldens/string snapshots — else **N/A** in **§0.2**)

- **Golden JSON** for stable API responses: store under `__fixtures__/` or `__tests__/fixtures/`; load with `fs` in Node tests or `import raw` pattern the bundler supports.
- **Large payloads:** keep **one** minimal golden per variant (success, 401, 422 validation) — not every locale.
- **Snapshot tests:** **avoid** for React trees per this prompt’s non-goals; **allowed** for **stable string** outputs (e.g. serialized query keys, canonical URLs) when explicitly justified in PR.

### 8.8 Browser API mocks (`localStorage`, `sessionStorage`, `matchMedia`, `ResizeObserver`) (**required** read; **required — if** tests touch those APIs — else **N/A** in **§0.2**)

- Use **`vi.stubGlobal`** or a small **in-memory `Storage`** implementation; **clear** between tests.
- **`matchMedia`:** return controllable `{ matches, addEventListener, removeEventListener }` for responsive hooks.
- **`ResizeObserver`:** no-op class with `observe` / `unobserve` / `disconnect` mocked — prevents jsdom errors without asserting browser layout.

### 8.9 Time, time zones, and `Date` (**required** read; **required — if** tests depend on time / JWT `exp` — else **N/A** in **§0.2**)

- Prefer **`vi.setSystemTime(new Date('2026-01-15T12:00:00.000Z'))`** for deterministic expiry / JWT `exp` tests; **restore** in `afterEach`.
- If production code uses **`Intl` / local TZ**, set **`process.env.TZ = 'UTC'`** at top of test file **or** use explicit offset in expectations — document which.
- Avoid **`Date.now = vi.fn()`** without restoring; fake timers + system time is usually clearer.

### 8.10 Cryptography and randomness (**required** read; apply bullets **if** tests stub crypto / `Math.random` — else **N/A** in **§0.2**)

- **`crypto.subtle` / `getRandomValues`:** stub only when code path is unreachable with fake inputs; prefer **injectable** `randomBytes` / `uuid` for business logic.
- **`Math.random`:** not suitable for security; if tests hit it, **`vi.spyOn(Math, 'random').mockReturnValue(0.42)`** and restore.

### 8.11 PR size and batching (**required** — soft gate)

- Target **≤ ~400 lines of test + factory code per PR** (soft limit) so reviewers can trace behavior. Larger work → **series** (**§13**) with clear PR boundaries.
- One **primary risk area** per PR (e.g. “routing only” or “useAuthApi only”) reduces merge conflicts.

### 8.12 Vitest in CI: pools, shards, timeouts (**required** read; **required — if** PR changes Vitest config or CI test job — else **N/A** in **§0.2**)

- Prefer **`pool: 'threads'`** for CPU-bound pure tests; use **`forks`** if worker crashes from native deps (document in `vitest.config` comment if so).
- **Shard** in CI with `vitest run --shard=${{ matrix.shard }}/${{ matrix.total }}` only when suite duration **>~2 min** — keep shard count aligned with CI parallelism.
- Set **`testTimeout`** / **`hookTimeout`** globally conservative; **override locally** for integration-style tests with comment why.

### 8.13 Linting tests (**optional**)

- **`eslint-plugin-vitest`** (or repo equivalent): enable **`expect-expect`**, **`no-focused-tests`**, **`valid-expect`** in CI to catch empty tests and `.only` leaks.
- Align with existing ESLint flat config; do not introduce conflicting Jest rules.

### 8.14 Regression-linked `describe` / `it` names (**required** read; **required — if** PR adds a regression test for a fixed bug)

- When a test locks a **fixed bug**, name it so grep finds the ticket: e.g. `describe('issue #1234 — refresh token rotation')` or `it('regression: duplicate face segment in guest path (MFAI-567)')`.
- PR body must **link** the issue; if no public tracker, use **short internal id** consistent with team convention.

### 8.15 Documentation follow-up (**required** read; **required — if** PR introduces non-obvious env vars, markers, CI filters, or new commands — else **N/A** in **§0.2**)

- If tests document **new** env vars, markers, or CI commands, add **one** short subsection to the relevant **`README.md`** or **`docs/DEVELOPMENT.md`** in the same PR series (can be final PR of series).
- Cross-link **this prompt** from PR description when the team uses prompt-driven work.

---

## 9. Verification (**required**)

- [ ] `fe_demo`: `yarn test` (and `yarn validate` if the PR touches linted code).
- [ ] `admin_demo`: `yarn test` and `yarn validate`.
- [ ] `be_demo`: `dotnet test BeDemo.Api.Tests` (or solution test command used in CI). For a **subset**, use **`dotnet test --filter "FullyQualifiedName~YourClass"`** or xUnit **traits** (`[Trait("Category","Security")]`) if the repo adopts them — document the filter in PR.
- [ ] `ai_demo`: `pytest` (or documented subset, e.g. **`pytest -m "not integration"`**).
- [ ] No **new** `eslint-disable` for test code except rare flakiness with **issue link** + removal date.
- [ ] If Vitest **pool/shard** changed: note in PR and confirm **local** `yarn test` matches CI command.

---

## 10. Deliverables (**required**)

- [ ] PR description lists **P-tier** addressed and **modules** touched.
- [ ] New tests map to **risk** (one short paragraph).
- [ ] If coverage tool run: **before/after** snippet or “not measured — time-boxed”.
- [ ] Submodule + parent bump policy respected if multiple repos change.
- [ ] **Regression** tests: issue/ticket reference in **title or description** (**§8.14**).
- [ ] **Docs** updated when new markers, env gates, or `dotnet test --filter` examples are introduced (**§8.15**).

---

## 11. Anti-patterns (**required** read; **forbidden** without task owner approval)

- Huge **RTL** trees for every page.
- Copy-pasting **200-line** mock setups per test — extract **factories** (`makeQueryClient()`, `makeRouterWrapper()`).
- Tests that assert **implementation** (private function call order) instead of **observable outcome**.
- **Real** calls to production APIs or real JWTs in CI.
- **Empty tests** (`it('foo', () => {})`) or **`expect` without assertion** — CI should fail via lint rule where configured (**§8.13**).
- **`test.only` / `describe.only`** committed — treat as merge blocker.

---

## 12. Reference templates in this monorepo (**required**)

**(required)** Open at least **one** listed template that matches the subsystem you modify; mirror naming, arrange/act/assert shape, and mock boundaries.

Study and **mirror style**, not necessarily file length:

- `fe_demo/src/api/__tests__/facePathRouting.test.ts`
- `fe_demo/src/acl/__tests__/permissions.test.ts`
- `fe_demo/src/utils/__tests__/routeTranslations.test.ts`
- `admin_demo/src/hooks/api/__tests__/usePagesApi.test.ts` (and siblings)
- `be_demo/BeDemo.Api.Tests/JwtValidationEdgeTests.cs`, `RefreshTokenEdgeCaseTests.cs`, `SecurityEdgeCaseTests.cs` — structure for edge naming and arrange/act/assert
- `be_demo/BeDemo.Api.Tests/IntegrationTestSeed.cs` (or current equivalent) — **central** user/role/face IDs for new tests (**§5.1**)

---

## 13. Optional series plan (**optional** — for PM / agent sequencing)

| PR # | Scope                                      | Apps                 |
| ---- | ------------------------------------------ | -------------------- |
| 1    | Pure routing + JWT + env                   | `fe_demo`            |
| 2    | `useWallHostViewer` + one hand-written API | `fe_demo`            |
| 3    | Hook parity (`usePageTypesApi` + gaps)     | `admin_demo`         |
| 4    | BE service/controller gap close            | `be_demo`            |
| 5    | `ai_demo` gRPC edge + script smoke         | `ai_demo`, `scripts` |

Adjust order if security incidents dictate **P0** elsewhere first.

---

## 14. References (**required** read before merge; **§14.2** **required — if** PR touches security, dependency majors, or doc diagrams)

### 14.1 External docs (**required** skim — open links relevant to stack you changed)

- Vitest: [https://vitest.dev/](https://vitest.dev/)
- Testing Library guidance (use sparingly per this prompt): [https://testing-library.com/docs/react-testing-library/intro/](https://testing-library.com/docs/react-testing-library/intro/)
- xUnit + ASP.NET Core testing: [https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- MSW (Mock Service Worker): [https://mswjs.io/](https://mswjs.io/)
- fast-check (property-based): [https://fast-check.dev/](https://fast-check.dev/)

### 14.2 Related prompts in this repo (**required — if** scope intersects; **N/A** with reason otherwise)

- **Security, headers, JWT/OAuth edge cases, full-stack hardening:** [security-hardening-full-stack-edge-tests-agent-prompt.md](./security-hardening-full-stack-edge-tests-agent-prompt.md)
- **Dependency upgrades, CVEs, lockfiles, CI matrix:** [monorepo-dependency-audit-and-upgrade-agent-prompt.md](./monorepo-dependency-audit-and-upgrade-agent-prompt.md)
- **Architecture / flow diagrams in docs (when tests justify updating Mermaid):** [mermaid-documentation-diagrams-agent-prompt.md](./mermaid-documentation-diagrams-agent-prompt.md)

Use the **security** prompt when tests touch auth cookies, CSP, rate limits, or token storage; use the **dependency** prompt when test work requires **Vitest / TanStack / EF** major bumps; use the **Mermaid** prompt when new auth or data flows should be reflected in diagrams **after** behavior is locked by tests.

---

## 15. Master checklist — full execution list (**required**)

**(required)** Work this section **top to bottom** before requesting review. For each bullet: **✓** done, or **N/A** with a **one-line reason** in the PR (same rules as **§0.2**). If an entire **subsection** (e.g. **§15.6**) does not apply, mark its header **N/A** once (`no fe_demo changes`, etc.) and skip inner boxes.

> **Reference implementation (2026-04-10):** `fe_demo` gained pure **`buildLocalizedLinkPath` / `buildLocalizedNavigateTarget`**, **`authSessionActions`** (shared login/logout/refresh/read-token logic) with **`authSessionActions.test.ts`** + **`authKeys`** coverage, **`jwtUtils`**, **`authTokenRequest`**, **`buildLocalized*`** tests; **`admin_demo`** mirrors **`authSessionActions`** + tests and **`usePageTypesApi.test.ts`**. Same pass added **`wallHostViewerLogic`** tests, **`env` / `collectEnvValidationErrors`** tests, **`computeAlbumGridLayout`** tests, **`profileQueryKey` + `profileApi`** tests, **ACL catalog `it.each`** over **`ALL_ACL_PERMISSION_KEYS_SORTED`** (fe + admin), **`StoriesControllerTests`** (401 without auth), **`ai_demo`** `pytest` + **`conftest.py` / `pytest.ini` / gRPC marker** wiring. **Still open for future PRs:** full **`useWallHostViewer` hook** `renderHook` coverage (Vitest **`node`** pool today), **`SignalR` / `EventSource`** handler + unmount tests, **`scripts/`** CI gates, and optional **§15.3** inventory artefacts.

### 15.0 Checkboxes in this file (**read**)

**§9–§10** stay **PR copy-paste templates** (leave **`[ ]`** in the canonical file for those sections). For **§15**, this repo’s **2026-04-10** gap-fill engagement ticks **`[x]`** below **only** where the bullet is satisfied **in-tree** today; **`[ ]`** marks a deliberate remaining gap or meta step (inventory attachment, full `SignalR` coverage). Reset unchecked rows when you schedule a **fresh** gap-fill pass.

### 15.1 Non-goals and allowed shapes (every PR)

- [x] Tests are **not** primarily “render whole app / RTL tree / DOM snapshot” unless the task owner explicitly expanded scope (**Purpose**, **Non-goals**).
- [x] Tests are **not** sold as **E2E replacement**; they stay **fast unit / narrow integration**.
- [x] No **silent product behavior change** unless a **confirmed bug** is fixed (then separate commit if the team wants).
- [x] Prefer **pure functions**, **minimal-provider hook tests**, **mocked API adapters**, **`BeDemo.Api.Tests`-style** C# tests (**Allowed / encouraged**).

### 15.2 Workflow gates (every PR)

- [x] **§0** labels understood; **§0.2** table filled (or **§3–§7** collapsed per collapse rule).
- [x] **§15.1–§15.16** each ✓ or subsection-level **N/A** with reason (see **§0.2** footnote on collapsing whole apps).
- [ ] **§9** and **§10** fully ✓ before merge (no N/A).

### 15.3 §1 — Baseline inventory

- [ ] Listed existing tests (`**/__tests__/**`, `*.test.ts(x)`, `*Tests.cs`, `test_*.py`) for **each touched submodule**.
- [ ] Noted **high-churn / high-risk dirs** (git log) when time-boxing.
- [ ] **Coverage** tool run **or** PR states “not measured — time-boxed” with reason.
- [ ] Inventory **attached** to first PR of series or linked tracking issue.

### 15.4 §2 — Priority matrix

- [ ] **P0** work done or explicitly deferred **before** starting **P2** for the same app.
- [ ] PR text states which **P-tier** each change belongs to.

### 15.5 §3 — `fe_demo` (skip whole subsection **N/A** if no `fe_demo` changes)

#### 15.5.1 §3.1 Routing / URL (**P0**)

- [x] `useLocalizedLink` / `useLocalizedNavigate` logic covered via **pure** `buildLocalizedLinkPath` / `buildLocalizedNavigateTarget` (or equivalent) **or** documented why not extracted yet.
- [x] Matrix: guest + public face path; authenticated path; missing `lang`; root / trailing slashes.
- [ ] If applicable: **`replace` / `state`**; query/hash preservation behavior **locked** in tests.
- [x] Optional hook smoke only if needed — **no** full-page render.
- [x] `faceApiRouting` (and related): double slashes, encoding, unknown segment, `/api/oauth2/...` exclusion; i18n cache invalidation if applicable.
- [x] Edge cases in **test names or comments**: all `supportedLanguages`; static route vs face index ambiguity.

#### 15.5.2 §3.2 JWT / crypto utils (**P0**)

- [x] `jwtUtils` (or equivalent): expiry, malformed base64, missing segments, clock skew **as documented in tests**.
- [x] **No** real production secrets in repo — **fixtures only**.

#### 15.5.3 §3.3 Configuration (**P0 / P1**)

- [x] `env.ts` (or equivalent): validation, defaults, fail-fast vs runtime warning **matches code**.

#### 15.5.4 §3.4 Async hooks / auth API (**P1**)

- [ ] `useWallHostViewer`: `enabled`, unmount during fetch, `token` / `faceId` transitions.
- [x] Hand-written **`src/api/**`** wrappers: mocked `fetch` / wrapper; URL, method, headers, error mapping.
- [x] **`useAuthApi` / session:** `__tests__/authSessionActions.test.ts` (or `useAuthApi` hook tests) covers login/register/refresh/logout/read-token + errors; **`authKeys`** stable (**§3.4**). Hook-only cache/refetch behaviour may be covered via **`renderHook`** + jsdom **if** the project enables that environment for the file.
- [x] **TanStack v5**: `gcTime` (not `cacheTime`), `staleTime` assumptions, `setQueryData` / `invalidateQueries`, mutation side effects on mocks — no brittle internal names.

#### 15.5.5 §3.4.1 OpenAPI vs hand-written (**P1**)

- [x] Hand-written URL + error mapping **tested**; generated code **not** fully snapshotted.
- [ ] Thin wrapper (base URL, auth, unwrap) **tested** if present; contract CI linked if used (**§5.3**).
- [ ] OpenAPI/DTO changes: only **UI-dependent** fields asserted.

#### 15.5.6 §3.5 Layout math (**P1**)

- [x] Table-driven: clamps, zero/negative dimensions.
- [ ] Optional property/fuzz: invariants fast, failing seed → regression row in table.

#### 15.5.7 §3.6 Contexts (**P0 / P1**)

- [ ] No provider snapshots; **extracted** pure/injectable pieces tested (`loadAuthStateFromStorage`, `syncTokenFromReactQuery`, messenger reducers).

#### 15.5.8 §3.7 ACL (**P0**)

- [x] `permissions.test.ts` rows for **every** backend capability key; DTO/OpenAPI regressions covered.

#### 15.5.9 §3.8 i18n (**P2**)

- [x] Custom helpers beyond `routeTranslations` get tests **or** **N/A** — no custom helpers.

#### 15.5.10 §3.9 Realtime (**P1** if used)

- [ ] SignalR / `EventSource`: fake hub / mock `EventSource`; handler registration + **unmount cleanup**; no real server **or** **N/A** — app does not use realtime.

### 15.6 §4 — `admin_demo` (skip **N/A** if no `admin_demo` changes)

#### 15.6.1 §4.1 API hooks (**P0 / P1**)

- [x] Every `src/hooks/api/use*.ts` has `__tests__/use*.test.ts` **or** documented one-line exception in PR.
- [x] TanStack v5 rules aligned with **§3.4**; shared **`makeQueryClient()`** where duplicated.
- [x] Gap hooks (e.g. `usePageTypesApi`): happy path, error path, **`queryKey`** stability.

#### 15.6.2 §4.2 ACL (**P0**)

- [x] `permissions.test.ts` extended when backend roles change **or** **N/A** — no role change.

#### 15.6.3 §4.3 API core (**P1**)

- [ ] `config.ts`, `core/request.ts`, `ApiError` mapping table-driven **or** **N/A** — not in scope.

#### 15.6.4 §4.4 Logger (**P2**)

- [x] Logger tests extended only if non-trivial behavior changed **or** **N/A**.

### 15.7 §5 — `be_demo` (skip **N/A** if no `be_demo` changes)

#### 15.7.1 General (**§5** body)

- [x] Grep’d **Controllers**, **Services**, **Hubs** for changed public surface.
- [x] Controllers missing scenarios: **minimal** tests (401/403, 400, success shape) **or** already covered.
- [x] **`OAuthJwksController`**: cache, invalid `kid`, rotation — covered or explicitly out of scope with reason.
- [x] New **`FooService`** ships with **`FooServiceTests.cs`** **or** deferral issue linked.

#### 15.7.2 §5.1 EF / persistence (**if** DB-heavy tests added/changed)

- [ ] Strategy chosen (in-memory / SQLite / WAF) **documented** in test class if non-obvious.
- [ ] **`IntegrationTestSeed`** (or equivalent) used — **no** scattered magic GUIDs.

#### 15.7.3 §5.2 Security test data (**every** BE test PR)

- [x] **No** prod JWTs/secrets in git; synthetic or test-only keys.
- [x] Rate-limit tests use **dedicated** seeded users, not prod passwords.

#### 15.7.4 §5.3 Contract / OpenAPI (**optional**)

- [x] If CI has contract checks: unit tests don’t duplicate every field; PR links job **or** **N/A** with reason in **§0.2**.

### 15.8 §6 — `ai_demo` (skip **N/A** if no `ai_demo` changes)

- [ ] `pytest` beyond smoke: gRPC errors, invalid protobuf, timeouts (mocked) where in scope.
- [x] Network tests **hermetic** or CI skip + **`ai_demo/README.md`** env gate documented.
- [x] **§6.1**: `conftest.py` / markers / parametrize / determinism addressed **or** **N/A** — trivial single-file smoke only.

### 15.9 §7 — `scripts/` (skip **N/A** if no `scripts/` changes)

- [x] If scripts **gate CI**: golden fixtures / `bats` / documented “not tested” — per **§7** **or** **N/A**.

### 15.10 §8 — Implementation standards (read all; apply where relevant)

#### 15.10.1 §8.1–§8.4

- [x] **8.1** Naming/placement matches repo (`__tests__`, `*Tests.cs`).
- [x] **8.2** Stable URL/error strings; mock **IO boundaries**, not internals.
- [x] **8.3** Fake timers restored; async patterns; flaky policy (reproduce → fix state → quarantine last resort with issue).
- [x] **8.4** Test descriptions language matches repo convention.

#### 15.10.2 §8.5–§8.8

- [x] **8.5** MSW vs `fetch` matrix applied for new FE API tests; one style per file.
- [ ] **8.6** Factories extracted after ~2nd duplicate setup (`makeQueryClient`, wrappers).
- [x] **8.7** Fixtures/goldens/snapshots only if justified; no RTL snapshots per non-goals.
- [ ] **8.8** `localStorage` / `matchMedia` / `ResizeObserver` mocked **if** code touches them; cleared between tests.

#### 15.10.3 §8.9–§8.12

- [ ] **8.9** `vi.setSystemTime` / `TZ` if time-dependent; restored in `afterEach`.
- [ ] **8.10** Crypto / `Math.random` stubs only when needed; prefer injection.
- [ ] **8.11** PR size ~≤400 lines test+factory **or** split series explained.
- [x] **8.12** Vitest pool/shard/timeout: config + CI aligned **or** **N/A** — no config change.

#### 15.10.4 §8.13–§8.15

- [x] **8.13** `eslint-plugin-vitest` (or equivalent) considered **or** **N/A** — not adopting.
- [x] **8.14** Regression tests named + issue linked **or** **N/A** — no regression tests in PR.
- [x] **8.15** `README` / `docs/DEVELOPMENT.md` updated for new env/CI/markers **or** **N/A**; prompt linked if team uses prompt-driven PRs.

### 15.11 §9 — Verification commands

- [x] `fe_demo`: `yarn test` (+ `yarn validate` if linted files touched) **or** **N/A**.
- [x] `admin_demo`: `yarn test` + `yarn validate` **or** **N/A**.
- [x] `be_demo`: `dotnet test` (full or `--filter` / traits documented) **or** **N/A**.
- [x] `ai_demo`: `pytest` (subset documented if used) **or** **N/A**.
- [x] No new `eslint-disable` without issue + removal date.
- [x] Vitest pool/shard change: local command matches CI **or** **N/A**.

### 15.12 §10 — Deliverables

- [ ] PR lists **P-tier** + **modules**.
- [ ] Short **risk** paragraph for new tests.
- [ ] Coverage before/after **or** “not measured — time-boxed”.
- [ ] Submodule bump policy respected **or** **N/A**.
- [ ] Regression refs (**§8.14**) **or** **N/A**.
- [ ] Docs for new markers/env/CI filters (**§8.15**) **or** **N/A**.

### 15.13 §11 — Anti-patterns

- [x] No huge RTL trees as primary strategy.
- [x] No mega copy-paste mocks without factories.
- [x] No assertion on private call order only.
- [x] No real prod APIs / real JWTs in CI.
- [x] No empty tests / no committed `.only`.

### 15.14 §12 — Reference templates

- [x] Opened **≥1** file from **§12** list matching subsystem; style mirrored.

### 15.15 §13 — Optional series

- [x] Multi-PR order documented **or** **N/A** — single PR.

### 15.16 §14 — References

- [x] Skimmed relevant **§14.1** links for stacks you changed.
- [x] Read **§14.2** related prompts when scope touches security, dependency majors, or diagrams **or** **N/A** with reason.
