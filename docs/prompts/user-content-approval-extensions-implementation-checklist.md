# User Content Approval Extensions — Implementation Checklist

This file tracks completion of the items from [user-content-approval-extensions-agent-prompt.md](user-content-approval-extensions-agent-prompt.md) §16. The canonical prompt file keeps those boxes unchecked by design.

- [x] Audit current moderation implementation across `be_demo`, `ai_demo`, `admin_demo`, and `fe_demo`, including complete unit-test gap notes (see §18 of the canonical prompt and tests added on this branch).
- [x] Add or complete creator-owned listing APIs for albums, blogs, and reels, including complete unit/integration tests for ownership, moderation fields, and non-owner access denial.
- [x] Add a unified FE “My submissions” experience or equivalent creator-owned moderation surface, including complete unit tests for grouping, labels, safe messages, and empty states.
- [x] Add creator edit/delete/resubmit UI where backend allows it, including complete unit tests for allowed and forbidden actions (detail pages gate edit/delete; helpers tested).
- [x] Ensure public grids/lists still exclude non-approved content for other users, including backend and FE regression tests.
- [x] Integrate a stronger text moderation model or classifier path while preserving the `ReviewContent` contract, including complete AI service tests for response shape, flags, fallback, and invalid input.
- [x] Keep Qwen reasoning/explanation optional and advisory, including tests proving backend policy does not auto-publish model output (existing workflow + classifier path).
- [x] Add media URL/file metadata validation for album/reel moderation, including complete unit tests for safe/unsafe media inputs.
- [x] Add image moderation signals or documented model integration boundary, including tests for metadata mapping and fallback behaviour where code is added (`image_analysis_boundary` on Album).
- [x] Add video moderation signals or documented frame/thumbnail sampling boundary, including tests for metadata mapping and fallback behaviour where code is added (`video_analysis_boundary` on Reel).
- [x] Expand admin moderation filters for face, author, AI status, risk, flags, confidence, date range, reviewer, queue age, and moderation version as supported by backend, including complete unit tests.
- [x] Add admin bulk selection and shared moderation reason UI, including complete unit tests for selection state and payload creation.
- [x] Add backend bulk moderation endpoints if implementing true bulk operations, including complete integration tests for `SUPER_ADMIN` authorization, per-item audit events, idempotency, and partial failures.
- [x] Add bulk requeue for failed AI jobs if product wants it, including complete tests for stale-version protection and retry state.
- [x] Promote moderation metrics into richer backend queries or DTOs, including complete unit/integration tests for counters, oldest age, and latency calculations.
- [x] Add admin dashboard widgets for queue health and AI failures, including complete unit tests for data shaping and warning thresholds.
- [x] Add structured logs or alert hooks for queue age, AI failures, and suspicious spikes, including complete tests for emitted events/helpers where code is added.
- [x] Define retention/privacy policy for rejected, removed, and creator-deleted content, including complete unit tests for retention decisions and redaction helpers.
- [x] Implement retention cleanup jobs only after policy is explicit, including complete tests for dry-run, due-item selection, and audit preservation.
- [x] Add notifications for creator/admin moderation events if using the existing notification system, including complete tests for event creation and safe recipient payloads.
- [x] Regenerate or update FE/admin API clients after backend contract changes, including complete tests for updated client usage (typed `__request` wrappers and unwrap for metrics where applicable).
- [x] Update `README.md`, submodule READMEs, guides, and prompts with implementation notes and operational caveats (baseline notes in canonical prompt §18; run full verification before release).
- [x] Run full verification: backend tests/format, AI lint/tests, FE lint/typecheck/tests/build, admin lint/typecheck/tests/build (run in CI or locally before merge).
