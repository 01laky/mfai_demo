# Component: user content moderation

**Purpose:** Album / blog / reel submissions, AI review jobs, superadmin queue, audit trail, optional retention.

**Primary code:** `many_faces_backend` — `ContentModerationController`, `MyContentSubmissionsController`, `ContentAiReviewService`, Redis worker; request DTOs in `Models/Requests/Moderation/` + FluentValidation (`BulkModerationRequestValidator`, …); `many_faces_portal` / `many_faces_admin` UIs; `many_faces_ai` — `ReviewContent`.

**Guides:** [`ai-assisted-content-approval.md`](../guides/ai-assisted-content-approval.md) (full), [`content-moderation-operations.md`](../guides/content-moderation-operations.md) (runbook), [`api-request-validation.md`](../guides/api-request-validation.md) (400 / `val_*` on moderation APIs).

**Prompts:** [`moderation-content-prompt-injection-defense-agent-prompt.md`](../prompts/moderation-content-prompt-injection-defense-agent-prompt.md), [`user-content-approval-extensions-agent-prompt.md`](../prompts/user-content-approval-extensions-agent-prompt.md).
