# User Content Approval Extensions — Agent Prompt

## 1. Mission

Extend the existing AI-assisted user content approval workflow in the Many Faces AI monorepo.

This prompt is for an AI coding agent. Treat it as an implementation specification, not as user-facing documentation. Work autonomously, but keep changes small, testable, and consistent with the existing repo patterns.

The current workflow already covers:

- FE-created albums, blogs, and reels start as `PendingApproval`.
- Public content surfaces show only `Approved` items.
- AI review jobs are queued and processed.
- The AI service exposes a typed `ReviewContent` gRPC contract.
- The backend stores AI recommendation metadata, audit events, retry/fallback state, and moderation metrics.
- The admin portal exposes a `SUPER_ADMIN` moderation queue with detail/history.
- FE has creator-safe copy and moderation badges.

This prompt covers the next product extensions beyond that core rollout.

## 2. Scope

Implement or design the following extension areas:

- A creator-facing “My submissions” experience.
- Stronger text moderation model integration.
- Media/image/video safety signals.
- Bulk moderation operations.
- Production-grade moderation dashboards/alerting.
- Retention/privacy cleanup rules for rejected/removed content.
- More complete OpenAPI/generated-client alignment where applicable.

Do not weaken the existing safety boundary:

- AI recommends.
- Backend policy validates.
- `SUPER_ADMIN` remains the only role that can approve, reject, remove, or override.
- `ADMIN` and `FACE_ADMIN` must not gain moderation powers unless a later prompt explicitly changes that product rule.

## 3. Required Operating Rules For The Agent

- Read the existing code before editing.
- Prefer existing patterns in `be_demo`, `fe_demo`, `admin_demo`, and `ai_demo`.
- Keep public visibility backend-enforced.
- Do not add feature flags for whether FE user-created content requires approval.
- Do not introduce autonomous AI publishing.
- Do not expose internal AI details to creators.
- Keep canonical checklist items unchecked in this file. Tick them only in a copied implementation task list or PR.
- Every implementation item must include complete unit tests or narrow integration tests for the changed behaviour.

## 4. Current System To Preserve

The agent should verify the current implementation before changing it:

- `be_demo`
  - `ContentApprovalStatus`, `AiReviewStatus`, `AiReviewJob`, `ContentModerationEvent`
  - `ContentAiReviewService`
  - `ContentModerationController`
  - album/blog/reel create/update/delete moderation behaviour
  - Redis job worker handling `content.ai-review`
- `ai_demo`
  - `HealthService.ReviewContent`
  - local Qwen model configuration
  - deterministic fallback/safety heuristics
- `admin_demo`
  - `ContentModerationPage`
  - moderation API hooks
  - `SUPER_ADMIN` UI gating
- `fe_demo`
  - album/blog/reel create forms
  - content moderation helpers
  - creator-safe badges

## 5. Creator “My Submissions” Experience

Add a protected FE experience where authenticated creators can see their own albums, blogs, and reels across moderation states.

Recommended route:

- `/my-submissions`

Recommended content groups:

- Pending approval
- Under AI review
- Needs review
- Approved
- Rejected
- Removed

Each item should show:

- content type
- title
- face
- submitted/updated date
- creator-safe status label
- safe creator-facing reason/message if available
- action buttons allowed by backend policy

Creator actions should follow existing backend rules:

- Pending/rejected content may be editable if backend allows it.
- Pending/rejected content may be deletable if backend allows it.
- Editing rejected content should resubmit it by creating/incrementing moderation version through the existing backend update flow.
- Approved/removed content should not be editable by the creator unless backend explicitly allows it.

Do not place non-approved content into public face grids unless it is explicitly rendered as a private creator-only overlay and tests prove it is not visible to other users.

## 6. Backend Creator APIs

Add or complete creator-owned APIs as needed.

Expected shape:

- list my albums with moderation states
- list my blogs with moderation states
- list my reels with moderation states
- optional unified endpoint: `GET /api/my/content-submissions`

If separate endpoints already exist for albums/reels but not blogs, fill the missing parity gap.

The backend must:

- authenticate the caller
- return only content owned by the caller
- include safe moderation fields needed by FE
- not expose internal AI reason, trace id, model internals, or abuse heuristics to creators
- keep public list/detail endpoints restricted to `Approved` content for non-owners

## 7. Stronger Text Moderation Model

Replace or augment the baseline heuristic with a stronger text moderation path.

Recommended design:

- Keep `ReviewContent` response shape stable.
- Keep Qwen as a reasoning/explanation model when useful.
- Add a dedicated classifier-style text moderation step if feasible.
- Keep a deterministic fallback when the model is unavailable.
- Validate every model response in the backend.

Text moderation should inspect:

- title
- blog content
- album description
- reel description
- URLs
- face metadata where relevant

Target categories:

- spam
- scam
- phishing / unsafe links
- hate / harassment
- adult / sexual content
- violence
- self-harm, if supported
- low quality / empty submissions
- copyright or policy-sensitive content, if supported

Model output must still map into:

- `decision`
- `confidence`
- `riskLevel`
- `flags`
- `reason`
- `userMessage`
- `modelVersion`
- `traceId`

## 8. Media, Image, And Video Safety

Add media-aware moderation signals for albums and reels.

Minimum design:

- Detect missing or invalid media URLs.
- Validate supported schemes and file types.
- Capture thumbnail/preview metadata where available.
- Preserve enough metadata for admin review.

Recommended future implementation:

- Image moderation model for album images/thumbnails.
- Video moderation through sampled frames or thumbnails.
- OCR on images/video frames before text moderation.
- NSFW/adult signal.
- violence signal.
- unsafe-logo/phishing screenshot signal where applicable.

Admin UI should display media safety state without rendering unsafe media in an uncontrolled way.

## 9. Bulk Moderation

Add bulk moderation only with strong safety constraints.

Supported operations may include:

- bulk approve selected items
- bulk reject selected items with shared reason
- bulk remove selected items with shared reason
- bulk requeue AI review for failed items

Backend requirements:

- `SUPER_ADMIN` only
- require a reason for bulk reject/remove
- write one audit event per item
- return per-item success/failure result
- preserve idempotency for already-transitioned items
- do not partially hide errors in a single global success message

Admin requirements:

- row selection
- selected count
- shared reason input
- confirmation before destructive bulk actions
- per-item result summary
- tests for selection, payloads, and result display

## 10. Moderation Dashboards And Alerts

Promote metrics from simple counters into operational visibility.

Recommended backend metrics:

- pending submissions count
- AI queued count
- AI processing count
- AI failed count
- oldest pending age
- average review latency
- p95 review latency
- approve/reject/remove counts
- AI recommended approve/reject/human-review counts
- top flags
- per-face submission spikes
- per-user submission spikes
- AI timeout/error counts

Recommended admin dashboard:

- queue health cards
- oldest pending warning
- failed AI jobs list
- high-risk submissions list
- per-face breakdown
- trend over time if historical data exists

Alerting can start as structured logs and admin warnings. Do not add external services unless the repo already has a pattern for them.

## 11. Retention And Privacy

Implement or document retention rules for rejected/removed content.

Decisions to encode:

- how long rejected content is retained
- how long removed content is retained
- whether creator-deleted pending/rejected content is hard-deleted or soft-deleted
- whether AI internal reasons are retained forever
- whether media previews are retained after rejection/removal
- what is redacted from audit logs

Recommended first policy:

- keep audit events
- redact long or unsafe free-form reasons
- soft-delete or mark content removed rather than hard-deleting approved content
- allow creators to delete their own pending/rejected content if backend policy already allows it
- add a retention job only after product rules are explicit

## 12. Notifications

Add user/admin notifications if the existing notification system can support them cleanly.

Creator notifications:

- submitted for approval
- AI review failed and needs manual review
- approved
- rejected with safe message
- removed
- editable/resubmittable after rejection

Superadmin/admin notifications:

- new pending submissions
- queue age threshold exceeded
- AI review failures
- high-risk spike

Notifications should not leak internal AI reasons or trace ids to creators.

## 13. OpenAPI And Client Alignment

If backend contracts change:

- regenerate or update FE/admin API clients according to the repo’s current pattern
- update local typed service wrappers
- update tests that depend on response shapes
- document any manual client edits if generation is not available

Do not leave FE/admin using stale response types.

## 14. Security And Authorization

Every new endpoint must be explicitly reviewed for:

- authentication
- ownership checks
- face scope
- `SUPER_ADMIN` restriction where applicable
- rejection of client-controlled face/user scope spoofing
- safe error messages
- auditability

Creator APIs must never allow a user to approve, reject, remove, or override their own content.

## 15. Testing Requirements

Every checklist item below requires complete unit tests or narrow integration tests. A task is not complete if the feature works manually but lacks coverage.

Required test areas:

- backend authorization and ownership
- backend moderation status transitions
- backend bulk idempotency
- AI service response mapping
- AI fallback behaviour
- admin API hooks
- admin selection/detail/filter UI logic
- FE creator status helpers
- FE my-submissions data shaping
- retention/redaction helpers
- notification event emission if implemented

Tests should be focused and fast. Prefer pure helper tests for formatting/filtering logic, and narrow integration tests for backend auth/transition behaviour.

## 16. Implementation Checklist

Leave these unchecked in this canonical prompt. Tick them only in the implementation PR or copied agent task list.

- [ ] Audit current moderation implementation across `be_demo`, `ai_demo`, `admin_demo`, and `fe_demo`, including complete unit-test gap notes.
- [ ] Add or complete creator-owned listing APIs for albums, blogs, and reels, including complete unit/integration tests for ownership, moderation fields, and non-owner access denial.
- [ ] Add a unified FE “My submissions” experience or equivalent creator-owned moderation surface, including complete unit tests for grouping, labels, safe messages, and empty states.
- [ ] Add creator edit/delete/resubmit UI where backend allows it, including complete unit tests for allowed and forbidden actions.
- [ ] Ensure public grids/lists still exclude non-approved content for other users, including backend and FE regression tests.
- [ ] Integrate a stronger text moderation model or classifier path while preserving the `ReviewContent` contract, including complete AI service tests for response shape, flags, fallback, and invalid input.
- [ ] Keep Qwen reasoning/explanation optional and advisory, including tests proving backend policy does not auto-publish model output.
- [ ] Add media URL/file metadata validation for album/reel moderation, including complete unit tests for safe/unsafe media inputs.
- [ ] Add image moderation signals or documented model integration boundary, including tests for metadata mapping and fallback behaviour where code is added.
- [ ] Add video moderation signals or documented frame/thumbnail sampling boundary, including tests for metadata mapping and fallback behaviour where code is added.
- [ ] Expand admin moderation filters for face, author, AI status, risk, flags, confidence, date range, reviewer, queue age, and moderation version as supported by backend, including complete unit tests.
- [ ] Add admin bulk selection and shared moderation reason UI, including complete unit tests for selection state and payload creation.
- [ ] Add backend bulk moderation endpoints if implementing true bulk operations, including complete integration tests for `SUPER_ADMIN` authorization, per-item audit events, idempotency, and partial failures.
- [ ] Add bulk requeue for failed AI jobs if product wants it, including complete tests for stale-version protection and retry state.
- [ ] Promote moderation metrics into richer backend queries or DTOs, including complete unit/integration tests for counters, oldest age, and latency calculations.
- [ ] Add admin dashboard widgets for queue health and AI failures, including complete unit tests for data shaping and warning thresholds.
- [ ] Add structured logs or alert hooks for queue age, AI failures, and suspicious spikes, including complete tests for emitted events/helpers where code is added.
- [ ] Define retention/privacy policy for rejected, removed, and creator-deleted content, including complete unit tests for retention decisions and redaction helpers.
- [ ] Implement retention cleanup jobs only after policy is explicit, including complete tests for dry-run, due-item selection, and audit preservation.
- [ ] Add notifications for creator/admin moderation events if using the existing notification system, including complete tests for event creation and safe recipient payloads.
- [ ] Regenerate or update FE/admin API clients after backend contract changes, including complete tests for updated client usage.
- [ ] Update `README.md`, submodule READMEs, guides, and prompts with implementation notes and operational caveats.
- [ ] Run full verification: backend tests/format, AI lint/tests, FE lint/typecheck/tests/build, admin lint/typecheck/tests/build.

## 17. Acceptance Criteria

- Creators can see their own submitted albums/blogs/reels without exposing non-approved content publicly.
- Stronger AI moderation improves recommendations while remaining advisory.
- Media moderation has at least a safe validation/metadata baseline and clear future model boundary.
- Bulk moderation, if implemented, is `SUPER_ADMIN` only, auditable per item, and idempotent.
- Admins can monitor queue health and AI failures.
- Retention/privacy rules are explicit and tested before destructive cleanup exists.
- FE/admin clients match backend contracts.
- Every implemented behaviour is covered by tests.
- The workflow remains safe if the AI service is unavailable, wrong, slow, or returns invalid data.
