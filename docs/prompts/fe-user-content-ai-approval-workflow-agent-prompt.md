# FE User Content AI Approval Workflow — Agent Prompt

## 1. Mission

Design and implement the first phase of a moderation workflow for **content created by regular users from the user-facing frontend (`fe_demo`)**.

Scope for this first phase:

- Albums
- Blogs
- Reels

When a regular FE user creates one of these content types, the content must not become public immediately. It should be stored as **pending approval**.

The final reviewer will later be an internal AI moderation/review system. Do **not** implement the AI decision engine in this phase. Build the data model, backend status transitions, API contracts, frontend behaviour, and test coverage so the AI approval step can be added cleanly later.

## 2. Product Intent

Regular users should be able to contribute content to a face, but public visibility must be controlled. User-created content should enter a review queue first. This keeps face pages clean, prevents accidental public publishing, and gives the platform a clear place to add AI-based review later.

The experience should feel simple to the user:

1. User creates an album, blog, or reel from the FE app.
2. The app confirms that the content was submitted for approval.
3. The content is not shown publicly yet.
4. The creator can still understand that their submission exists and is waiting.
5. A later review process, eventually AI-backed, decides whether it becomes public.

## 3. Important Distinction

This is about **regular user-created content in `fe_demo`**, not admin-created content in `admin_demo`.

Recommended rule:

- Content created by a regular FE user: `PendingApproval`
- Content created by an admin/operator flow: `Approved` by default, unless product explicitly changes this later

Do not mix this workflow with admin grid component configuration. Admins configure which blocks exist on a page; FE users create content inside supported blocks.

## 4. Current FE Create Scope

The FE grid block `+` create flow currently supports:

- `album`, `albumGrid`, `albumCarousel` → `AlbumForm`
- `blog`, `blogGrid`, `blogCarousel` → `BlogForm`
- `reel`, `reelGrid`, `reelCarousel` → `ReelForm`
- `chatRoom`, `chatRoomGrid`, `chatRoomCarousel` → `ChatRoomForm`, gated by face config

This prompt only covers:

- Albums
- Blogs
- Reels

Out of scope for this phase:

- Chat rooms
- Ads
- Stories
- User profiles
- Admin grid layout component creation

## 5. Target Approval Status Model

Add a shared approval status concept for user-created content.

Suggested enum values:

- `Draft`
- `PendingApproval`
- `Approved`
- `Rejected`

If the codebase already has an equivalent moderation/status enum, reuse or extend the existing pattern rather than creating a parallel abstraction.

Recommended metadata fields for `Album`, `Blog`, and `Reel`:

- `ApprovalStatus`
- `SubmittedAtUtc`
- `ReviewedAtUtc`
- `ReviewedByUserId`
- `RejectionReason`
- `CreatedByUserId` if not already present

Use nullable review fields where appropriate. Keep timestamps UTC.

## 6. Backend Behaviour

### Create From FE User Flow

When a regular FE user creates an album, blog, or reel:

- Persist the new entity.
- Set `ApprovalStatus = PendingApproval`.
- Set `SubmittedAtUtc`.
- Set creator ownership metadata if missing.
- Return a response that lets FE show “submitted for approval”.

### Public Queries

Public/grid/list/detail queries should not expose non-approved content to other users.

Default public visibility rule:

- Return only `Approved` content.

Author visibility rule:

- The creator may see their own `PendingApproval` and `Rejected` content in an appropriate “my content” context.
- Do not leak pending/rejected items into public grid blocks unless product explicitly asks for creator-private overlays there.

### Admin / Review API Placeholder

Even if AI review is not implemented now, prepare backend contracts so review can be added cleanly.

Recommended endpoints or service methods:

- list pending albums/blogs/reels
- approve item
- reject item with reason

For this first phase, manual/admin review endpoints may exist as placeholders or basic protected operations. The important part is that the data model and status transitions are ready for AI review later.

### AI Review Future Integration

Do not implement AI approval decisions yet.

Design so a future AI reviewer can:

- load pending submissions
- inspect content and metadata
- produce an approval/rejection recommendation
- store review metadata
- optionally require human/admin confirmation before publication

Keep this future path explicit in comments/docs where useful, but avoid fake AI logic.

## 7. Frontend Behaviour

For `AlbumForm`, `BlogForm`, and `ReelForm` create flows in `fe_demo`:

- After successful create, show a success message that says the content was submitted for approval.
- Do not imply that the content is already public.
- If the form currently closes/navigates to a public detail page, review whether that still makes sense for pending content.
- If navigating to detail, ensure the detail view handles pending/private author visibility correctly.
- Add or reuse status badges where “my content” views show pending/rejected submissions.

Suggested user copy:

- “Submitted for approval.”
- “Your content was created and is waiting for review.”
- “This item is not public yet.”

## 8. Permissions And Roles

Initial recommendation:

- Authenticated FE users may submit content if the face allows the relevant content type.
- Review/approval permissions are limited to `SUPER_ADMIN` for now.
- FE clients should not be able to mark their own content as `Approved`.
- `ADMIN` and `FACE_ADMIN` must not approve, reject, or remove this content in the first implementation.
- Backend must enforce status transitions; UI gating is not sufficient.

Required role rule:

- submit content: authenticated FE user, subject to normal face/content rules
- review recommendation: future internal AI reviewer/service identity
- approve/reject/remove: `SUPER_ADMIN` only
- view moderation queues: start with `SUPER_ADMIN` only unless product explicitly expands visibility later

## 9. Data Migration

Add migrations for new fields.

Migration defaults need a deliberate decision:

- Existing content should probably default to `Approved` to avoid hiding already-visible content.
- New FE-created content should default to `PendingApproval` in create logic, not only in database defaults.

Document this decision in the migration or implementation notes.

## 10. Testing Requirements

Backend tests:

- Creating album/blog/reel from regular user flow sets `PendingApproval`.
- Existing/admin-created path remains `Approved` if that rule is implemented.
- Public list/grid queries exclude pending content.
- Public detail access does not expose another user’s pending/rejected content.
- Creator can access their own pending content only through intended author/my-content path.
- Approve transition changes status to `Approved`.
- Reject transition changes status to `Rejected` and stores reason.
- Users cannot approve their own content through public endpoints.

Frontend tests:

- Album create success copy says submitted/pending approval.
- Blog create success copy says submitted/pending approval.
- Reel create success copy says submitted/pending approval.
- Public grid/list UI does not assume freshly created content is public.
- Pending status badge/copy appears wherever author-owned pending content is shown.

## 11. Implementation Checklist

Leave these unchecked in this canonical prompt. Tick them only in the implementation PR or a copied task list.

Every implementation checklist item includes the requirement to add or update complete unit tests for the changed behaviour. Do not mark an item complete if the implementation is present but the relevant unit coverage is missing.

- [ ] Audit current `Album`, `Blog`, and `Reel` backend models, DTOs, services, controllers, and migrations, including complete unit-test gap notes.
- [ ] Identify current FE create paths for `AlbumForm`, `BlogForm`, and `ReelForm`, including complete unit-test gap notes.
- [ ] Add or reuse approval status enum, including complete unit tests for parsing, serialization, defaults, and invalid values where applicable.
- [ ] Add approval metadata fields to album/blog/reel entities, including complete unit tests for defaults and mapping.
- [ ] Add EF Core migration with safe defaults for existing content, including complete unit tests or narrow migration/model tests where applicable.
- [ ] Update create endpoints so regular FE-created content becomes `PendingApproval`, including complete unit tests.
- [ ] Preserve or define admin-created content behaviour, recommended `Approved`, including complete unit tests.
- [ ] Filter public/grid/list queries to approved content only, including complete unit tests.
- [ ] Add intended author/private visibility path for pending/rejected content, or document why it is deferred, including complete unit tests for whichever path is implemented.
- [ ] Add protected approve/reject backend contracts or service methods, including complete unit tests.
- [ ] Ensure FE users cannot approve their own content, including complete unit tests.
- [ ] Ensure only `SUPER_ADMIN` can approve, reject, or remove submitted content, including complete unit tests.
- [ ] Ensure `ADMIN` and `FACE_ADMIN` cannot approve, reject, or remove submitted content in this phase, including complete unit tests.
- [ ] Regenerate OpenAPI clients for `fe_demo` and `admin_demo` after backend contract changes, including complete unit tests for updated generated-client usage.
- [ ] Update FE create success copy for albums, including complete unit tests.
- [ ] Update FE create success copy for blogs, including complete unit tests.
- [ ] Update FE create success copy for reels, including complete unit tests.
- [ ] Add pending/rejected badges where author-owned content is shown, if that screen exists in scope, including complete unit tests.
- [ ] Decide whether creators may edit, delete, or resubmit pending/rejected content in phase 1, including complete unit tests for the chosen behaviour.
- [ ] Add backend tests for status defaults, visibility filtering, and transitions, including complete unit tests for all new service/controller branches.
- [ ] Add FE tests for user-facing create copy and pending behaviour, including complete unit tests for all changed pure logic and UI state helpers.
- [ ] Update docs/comments to mark AI review as a future integration point, not implemented decision logic, including complete unit tests for any code touched by the doc-driven change.

## 12. Acceptance Criteria

- Regular FE-created albums/blogs/reels are stored as pending approval.
- Pending content is not publicly visible to other users.
- Existing public content is not accidentally hidden by migration defaults.
- The creator receives clear “submitted for approval” feedback.
- Backend owns all status and visibility enforcement.
- The implementation leaves a clear extension point for a future AI approval service.

## 13. Part 2 Direction — AI-Assisted Approval

After the first phase is in place, extend the workflow into an **AI-assisted moderation pipeline**.

Important rule: the safe default is that AI should **recommend** a moderation decision, not silently become the final authority. Final publication/removal should be controlled by backend policy and should always be auditable. A future product decision may allow limited auto-approval under strict rules, but that must be explicit, configurable, and reversible.

Recommended operating model:

1. FE user submits album/blog/reel.
2. Backend stores the content as `PendingApproval`.
3. Backend enqueues an AI review job.
4. AI processes a limited number of jobs at a time.
5. AI returns a structured recommendation.
6. Backend policy decides whether the item can move forward automatically or must go to admin/superadmin review.
7. Admin/superadmin can override AI recommendations.
8. Every decision is written to an audit log.

## 14. Separate Content Status From AI Review Status

Keep the public content lifecycle separate from AI processing lifecycle.

Recommended content status:

- `PendingApproval`
- `Approved`
- `Rejected`
- `Removed`

Optional content status if the product wants drafts:

- `Draft`

Recommended AI review status:

- `NotQueued`
- `Queued`
- `InProgress`
- `RecommendedApprove`
- `RecommendedReject`
- `NeedsHumanReview`
- `Failed`

Why separate fields:

- Public visibility depends on content status.
- AI processing can retry, fail, or change recommendation without rewriting final publication status.
- Superadmin override stays clean: content can be `Approved` even if AI recommended reject, and the audit log explains why.

Suggested fields:

- `ApprovalStatus`
- `AiReviewStatus`
- `AiReviewDecision`
- `AiReviewConfidence`
- `AiReviewRiskLevel`
- `AiReviewFlagsJson`
- `AiReviewReason`
- `AiReviewUserMessage`
- `AiReviewModelVersion`
- `AiReviewTraceId`
- `AiReviewedAtUtc`
- `HumanReviewedAtUtc`
- `HumanReviewedByUserId`
- `HumanDecisionReason`
- `RemovedAtUtc`
- `RemovedByUserId`
- `RemovalReason`

Use JSON only where it is appropriate for flexible AI flags/details. Keep query-critical values as typed columns.

## 15. AI Review Job Queue

Do not call AI synchronously from the FE create request. The create request should be fast and reliable.

Create a queue/job abstraction for AI review:

- `AiReviewJobId`
- `ContentType`
- `ContentId`
- `FaceId`
- `CreatedByUserId`
- `Priority`
- `Status`
- `Attempts`
- `MaxAttempts`
- `NextAttemptAtUtc`
- `CreatedAtUtc`
- `StartedAtUtc`
- `CompletedAtUtc`
- `LastError`

Recommended job statuses:

- `Queued`
- `Processing`
- `Completed`
- `RetryScheduled`
- `Failed`
- `NeedsHumanReview`

The implementation can use Redis queue infrastructure or a database-backed queue. Prefer the existing local infrastructure if it already has a reliable queue/worker pattern. Do not invent a second queue system without a reason.

## 16. AI Backpressure And Workload Protection

AI should not receive an unbounded amount of work at once.

Add or design for:

- global max concurrent AI reviews
- per-face queue limits
- per-user submission limits
- batch size limits
- retry backoff
- max attempts
- deduplication for identical content/version
- priority handling
- circuit breaker if AI service is unavailable
- fallback to `NeedsHumanReview` when AI cannot decide or repeatedly fails
- operational switch to disable AI auto-processing per environment or face

Recommended initial policy:

- New content is enqueued.
- Worker processes small batches.
- If queue is overloaded, content remains `PendingApproval` and visible in admin moderation.
- AI failure must not publish content.

## 17. Structured AI Recommendation Contract

AI should return structured data, not free-form prose.

Target response shape:

```json
{
  "decision": "approve | reject | needs_human_review",
  "confidence": 0.92,
  "riskLevel": "low | medium | high",
  "flags": ["spam", "unsafe_link", "hate", "adult", "copyright", "low_quality"],
  "reason": "Internal explanation for admins.",
  "userMessage": "Safe optional message that may be shown to the creator.",
  "modelVersion": "moderation-v1",
  "traceId": "ai-review-..."
}
```

Backend must validate this response:

- unknown decision → `NeedsHumanReview`
- invalid confidence → `NeedsHumanReview`
- high risk → never auto-approve
- missing reason for reject → require human review or use safe fallback copy
- AI service timeout/error → retry or `NeedsHumanReview`

## 18. Backend Policy For AI Recommendations

The AI recommendation should not directly mutate public visibility without backend policy.

Safe first policy:

- `approve` recommendation → `RecommendedApprove`, still visible in admin queue
- `reject` recommendation → `RecommendedReject`, still visible in admin queue
- `needs_human_review` → `NeedsHumanReview`
- final `Approved`, `Rejected`, or `Removed` requires admin/superadmin action
- in the first implementation, the human/admin action means `SUPER_ADMIN` only

Optional future policy, only if product explicitly allows:

- Auto-approve only when:
  - confidence is above threshold
  - risk is `low`
  - flags are empty or only informational
  - author/face is not rate-limited or suspicious
  - auto-approval has been explicitly enabled by a future product decision
- Never auto-approve when:
  - risk is `medium` or `high`
  - unsafe flags are present
  - content contains links/files requiring deeper review
  - AI model version is unknown
  - queue/retry state is inconsistent

Even with auto-approval, write an audit event and allow superadmin removal.

## 19. Admin Moderation UI

Add an admin moderation area for album/blog/reel submissions.

Recommended top-level section:

- `Moderation`

In the first implementation, moderation actions should be available to `SUPER_ADMIN` only.
`ADMIN` and `FACE_ADMIN` should not approve, reject, or remove user-created albums/blogs/reels yet.

Recommended lists/tabs:

- `Pending`
- `AI Recommended Approval`
- `AI Recommended Rejection`
- `Needs Human Review`
- `Approved`
- `Rejected`
- `Removed`

Each list should support filters:

- content type: album/blog/reel
- face
- author
- status
- AI review status
- risk level
- AI flags
- confidence range
- date range
- reviewer
- queue age
- moderation version

Each row/card should show:

- content type
- title/name
- face
- author
- created/submitted time
- current approval status
- AI status
- confidence/risk
- key flags
- thumbnail/preview where available
- quick actions allowed for current role

Detail view should show:

- full content preview
- metadata
- AI recommendation
- AI reason
- safe user-facing rejection message
- moderation history
- approve/reject/remove controls
- superadmin override controls where allowed
- media/file preview and safety indicators where content includes uploads

## 20. Superadmin Powers

`SUPER_ADMIN` should be able to:

- approve pending content
- approve content AI recommended for rejection
- reject pending content
- reject content AI recommended for approval
- remove already approved content
- restore removed content if product allows
- view AI decision details
- view model version and trace id
- view full moderation audit history
- override AI recommendation with a required reason

Do not hard-delete approved content as the normal moderation action. Prefer `Removed` so the system keeps auditability and can explain why content disappeared.

`ADMIN` and `FACE_ADMIN` are intentionally excluded from approval, rejection, and removal in the first implementation. If product later wants delegated face-level moderation, add it as a separate explicit role/permission rollout.

## 21. Audit Log

Add a moderation audit log, for example `ContentModerationEvents`.

Recommended fields:

- `Id`
- `ContentType`
- `ContentId`
- `FaceId`
- `OldApprovalStatus`
- `NewApprovalStatus`
- `OldAiReviewStatus`
- `NewAiReviewStatus`
- `ActorType` (`User`, `AI`, `Admin`, `SuperAdmin`, `System`)
- `ActorUserId`
- `Reason`
- `UserMessage`
- `AiTraceId`
- `AiModelVersion`
- `CreatedAtUtc`

Write audit events when:

- content is submitted
- AI job is queued
- AI starts processing
- AI completes recommendation
- AI fails or falls back to human review
- admin approves
- admin rejects
- superadmin overrides
- approved content is removed
- removed content is restored, if supported
- creator edits, deletes, or resubmits pending/rejected content if those actions are allowed

## 22. Notifications

Add or design for user/admin notifications around moderation status changes.

Recommended creator notifications:

- content submitted for approval
- content moved into AI review
- content approved
- content rejected with safe user-facing reason
- approved content removed
- rejected content can be edited/resubmitted, if supported

Recommended superadmin/admin notifications:

- new pending content exists
- AI review failed or needs human review
- queue age exceeds threshold
- suspicious spike in submissions for a user or face

Do not block the core approval workflow on a full notification system if one does not exist yet. At minimum, keep response copy and future notification hooks explicit.

## 23. FE User Status Display

The user-facing app should eventually show the creator a clear status for their own submitted content.

Recommended creator-visible states:

- `Pending approval`
- `Under AI review`
- `Needs review`
- `Approved`
- `Rejected`
- `Removed`

FE should not expose internal-only AI details by default. Show safe messages:

- “Your content is waiting for review.”
- “Your content is being reviewed.”
- “Your content was approved.”
- “Your content was rejected.”
- “This content is no longer public.”

If rejected, show `AiReviewUserMessage` or `HumanDecisionReason` only if it is safe for end users. Internal flags like abuse heuristics, model trace ids, or policy internals should stay in admin.

## 24. Creator Actions, Resubmission, And Versioning

Decide whether pending/rejected content can be edited, deleted, or resubmitted by the creator.

Recommended model:

- User may delete their own `PendingApproval` content if product allows.
- User may edit rejected content if product allows.
- Editing rejected content creates a new moderation version or increments `ModerationVersion`.
- Resubmission resets content status to `PendingApproval`.
- AI review starts again for the new version.
- Old moderation events remain attached to history.

Avoid overwriting old AI reasons or human decisions without history.

## 25. Media And File Safety

Albums and reels may include uploaded or linked media. The approval workflow must account for media safety, not just text metadata.

Design for:

- image/video thumbnail preview in moderation queues
- file type and size validation
- unsafe link detection
- media availability failures
- missing/broken media handling
- future image/video moderation signals
- safe display of media previews in admin UI

Do not mark media content public until the content item is `Approved`.

## 26. Concurrency And Idempotency

Approval transitions must be safe under repeated clicks, retries, and duplicate jobs.

Design for:

- idempotent AI job creation per content moderation version
- optimistic concurrency or row version checks on status transitions
- no duplicate approve/reject/remove events for the same transition
- repeated approve on already approved content returns a safe no-op or conflict
- stale AI recommendation cannot override a newer moderation version
- queue retries do not create duplicate public content

## 27. Bulk Moderation

Bulk moderation is not required for the first UI, but the API/design should not make it impossible.

Future bulk operations may include:

- bulk approve low-risk items
- bulk reject obvious spam
- bulk remove approved items after a policy incident
- bulk requeue failed AI reviews

Bulk actions must still write per-item audit events.

## 28. Metrics And Observability

Add or design for operational visibility:

- count of pending submissions
- count of AI queued/in-progress/failed jobs
- oldest queue age
- review latency
- approve/reject/remove counts
- AI confidence distribution
- top AI flags
- per-face submission spikes
- per-user submission spikes
- failed AI service calls

These metrics can start as logs/queries, but the model should preserve enough data to build dashboards later.

## 29. Retention And Privacy

Rejected and removed content may contain unsafe or sensitive material. Decide retention rules before production use.

Recommended questions:

- how long rejected content is retained
- how long removed content is retained
- whether creators can delete rejected content
- whether AI reasons are considered internal-only
- whether media previews are stored after rejection/removal
- what is included in audit logs vs redacted

Keep auditability, but avoid storing more unsafe content than the product needs.

## 30. API Client Regeneration

Any backend DTO/endpoint changes must be reflected in generated clients.

Required follow-up:

- regenerate `fe_demo` OpenAPI client
- regenerate `admin_demo` OpenAPI client
- update affected TypeScript model usage
- update FE/admin tests that depend on generated response shapes

## 31. No Feature Flag Requirement

Do not add a gradual feature flag rollout requirement for this workflow. The product decision is to implement the approval model as the default path for regular FE user-created albums, blogs, and reels.

Optional future config may still exist for AI automation policy, but first implementation should not depend on feature flags to decide whether user-created content requires approval.

## 32. Suggested Implementation Phases For Part 2

Phase 2A — moderation queue foundation:

- Add AI review status fields.
- Add job model/queue abstraction.
- Add admin moderation lists using current statuses.
- No real AI decision yet.

Phase 2B — AI service contract:

- Add typed AI review request/response contract.
- Add mock/stub AI reviewer.
- Store AI recommendation metadata.
- Add tests for structured response handling.

Phase 2C — admin review workflow:

- Add moderation detail screen.
- Add approve/reject/remove actions.
- Add superadmin override rules.
- Add audit log UI.
- Keep all final moderation actions restricted to `SUPER_ADMIN`.

Phase 2D — real AI review:

- Connect `ai_demo` or chosen AI service.
- Add backpressure/rate limits.
- Add retry/circuit breaker.
- Add model/version tracing.

Phase 2E — controlled automation:

- Optional auto-approval for low-risk/high-confidence content.
- Superadmin kill switch.
- Expanded audit reporting.

## 33. Part 2 Checklist

Leave these unchecked in this canonical prompt. Tick them only in the implementation PR or a copied task list.

Every Part 2 checklist item includes the requirement to add or update complete unit tests for the changed behaviour. Do not mark an item complete if queue, policy, admin, AI, or FE code was changed without relevant unit coverage.

- [ ] Add separate AI review status concept, including complete unit tests for defaults, transitions, parsing, and serialization.
- [ ] Add AI review metadata fields, including complete unit tests for defaults, mapping, and update behaviour.
- [ ] Add moderation audit event model, including complete unit tests for event creation and required fields.
- [ ] Add AI review job model or queue abstraction, including complete unit tests for enqueue/dequeue/state changes.
- [ ] Add queue backpressure limits and retry policy, including complete unit tests for limits, retry, and failure paths.
- [ ] Add structured AI recommendation contract, including complete unit tests for valid and invalid payloads.
- [ ] Add backend validation for AI recommendation responses, including complete unit tests for every validation branch.
- [ ] Add policy layer that separates AI recommendation from final approval, including complete unit tests for each policy decision.
- [ ] Add admin moderation section, including complete unit tests for routing/state helpers and permission guards.
- [ ] Add admin lists for pending, AI recommended approval, AI recommended rejection, needs human review, approved, rejected, removed, including complete unit tests for filtering and status mapping.
- [ ] Add moderation detail view with content preview and AI metadata, including complete unit tests for data shaping and safe display helpers.
- [ ] Add approve/reject/remove actions restricted to `SUPER_ADMIN`, including complete unit tests.
- [ ] Ensure `ADMIN` and `FACE_ADMIN` cannot approve, reject, or remove content, including complete unit tests.
- [ ] Add superadmin override rules, including complete unit tests for required reasons and override transitions.
- [ ] Add audit log writes for all moderation transitions, including complete unit tests for each transition event.
- [ ] Add safe FE creator-facing status labels, including complete unit tests for status-to-copy mapping.
- [ ] Add rejected/resubmit/versioning decision, including complete unit tests for the chosen behaviour.
- [ ] Add creator edit/delete/resubmit decision for pending/rejected content, including complete unit tests for allowed and forbidden actions.
- [ ] Add notification hooks or documented follow-up points, including complete unit tests for emitted events/hooks where code is added.
- [ ] Add media/file safety handling for album/reel content, including complete unit tests for validators and safety metadata.
- [ ] Add concurrency/idempotency protection for moderation transitions and AI jobs, including complete unit tests for duplicate/stale/retry scenarios.
- [ ] Add bulk moderation design notes or API-safe constraints, including complete unit tests for any implemented bulk guards.
- [ ] Add metrics/observability fields or logs for queue and moderation health, including complete unit tests for metric/log event helpers where code is added.
- [ ] Add retention/privacy rules for rejected/removed content and AI reasons, including complete unit tests for retention decisions and redaction helpers.
- [ ] Regenerate FE/admin OpenAPI clients after backend contract changes, including complete unit tests for updated generated-client usage.
- [ ] Add backend tests for AI queue, recommendation handling, policy decisions, and superadmin override, including complete unit tests for all new backend branches.
- [ ] Add admin UI tests for moderation lists and actions, including complete unit tests for all changed UI logic.
- [ ] Add FE tests for creator-facing status display, including complete unit tests for all changed UI logic.

## 34. Part 2 Acceptance Criteria

- AI work is queued and rate-limited rather than processed unbounded.
- AI returns structured recommendations.
- AI recommendation does not bypass backend policy.
- Admin can view pending, approved, rejected, removed, and AI-recommended queues.
- Only `SUPER_ADMIN` can approve, reject, override, or remove approved content.
- `ADMIN` and `FACE_ADMIN` cannot perform moderation actions for this workflow.
- Every moderation transition is auditable.
- FE creator-facing status is clear and does not leak internal AI details.
- Media/file safety is considered before public visibility.
- Moderation transitions and AI jobs are safe against duplicate retries.
- Generated FE/admin API clients are updated after backend contract changes.
- The system can later enable carefully controlled AI auto-approval without redesigning the whole workflow.

## 35. Implementation Notes From Current Branch

This canonical prompt intentionally keeps checklist items unchecked. The current implementation branch covers
the first concrete rollout by adding backend moderation status fields, AI review job/audit models, pending-by-default
FE-created album/blog/reel submissions, approved-only public visibility, `SUPER_ADMIN` moderation endpoints,
creator-facing FE pending copy, and a first admin Moderation screen.

Known operational note:

- EF migration generation via local `dotnet-ef` failed because the installed EF design tool/runtime combination
  throws `MissingMethodException` against the repo's EF Core 10 packages. The migration file was therefore added
  manually with existing-content defaults set to `Approved`; backend tests validate the runtime model and workflow.

