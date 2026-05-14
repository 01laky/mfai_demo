# Mailer worker + Mailpit — local development

This guide describes how to run **`many_faces_mailer`** (Java gRPC + SMTP) together with **`many_faces_backend`** so ASP.NET Core Identity can send **confirm** and **reset** email through **Mailpit** (no real internet delivery).

## Prerequisites

- Docker (for Mailpit + the mailer container build).
- Submodule **`many_faces_mailer/`** checked out.
- Optional: **`grpcurl`** for manual RPC smoke.

## One-command stack (monorepo)

From the monorepo root:

```bash
ENABLE_MAILER_WORKER=1 docker compose -f docker-compose.dev.yml up -d be-demo-dev seq
```

Use **`./scripts/start-all-dev.sh`** with **`ENABLE_MAILER_WORKER=1`** so `mailer-worker-dev` starts, joins **`many_faces_main_dev-network`**, and exports **`MAIL_DEV_*`** for the backend compose substitution (see `docker-compose.dev.yml`).

## Mailpit UI

With default submodule port maps:

- **SMTP (worker → sink):** host `localhost`, port **`51025`** (maps to Mailpit `1025` inside compose).
- **Web UI:** **`http://localhost:58025`** (maps to Mailpit `8025`).

## Backend configuration (`Mail:`)

| Key | Example | Notes |
| --- | ------- | ----- |
| `Mail:Enabled` | `true` | When `false`, **`IEmailSender`** logs and **no-ops** (safe default in `appsettings.Development.json`). |
| `Mail:WorkerGrpcUrl` | `http://mailer-worker-dev:50054` | From **inside** `be-demo-dev`; on the host use `http://localhost:59204` only if you point the API at the host-mapped port. |
| `Mail:WorkerAuthToken` | shared secret | Must match **`MAILER_WORKER_EXPECTED_TOKEN`** on the worker when set. Header: **`x-mailer-worker-token`**. |
| `Mail:DefaultLocale` | `en` | Fallback BCP 47 tag when `CultureInfo.CurrentUICulture` is empty. |

### Correlation (HTTP → gRPC metadata)

`MailerWorkerGrpcClient` copies inbound HTTP headers into outbound gRPC **metadata** (same lowercase keys the worker reads):

| gRPC metadata key | Typical HTTP header |
| ----------------- | ------------------- |
| `x-request-id` | `X-Request-Id` |
| `traceparent` | `traceparent` |
| `tracestate` | `tracestate` |

Values are single-line ASCII (max 256 chars); CR/LF/NUL are dropped. When there is no HTTP context (background jobs), only **`x-mailer-worker-token`** is sent.

Docker Compose uses placeholders **`MAIL_DEV_*`** (exported by `start-all-dev.sh` when the mailer is enabled), mirroring the **`PUSH_DEV_*`** pattern.

## Worker environment (many_faces_mailer)

See **`many_faces_mailer/.env.example`** and **`many_faces_mailer/README.md`**. Important variables:

- **`MAILER_WORKER_GRPC_LISTEN`** — bind address (default `:50054`).
- **`MAILER_SMTP_HOST` / `MAILER_SMTP_PORT`** — Mailpit in submodule compose defaults to **`mailpit:1025`**.
- **`MAILER_FROM_EMAIL`**, **`MAILER_FROM_DISPLAY_NAME`** — envelope / MIME From identity.

## gRPC smoke (`grpcurl`)

With **cleartext** gRPC on the host-mapped port and **no auth token** on the worker:

```bash
grpcurl -plaintext -d '{
  "to": ["you@example.com"],
  "template_id": "identity_email_confirm",
  "locale": "en",
  "params": {
    "action_link": "https://example.com/confirm-demo",
    "user_name": "Demo"
  }
}' localhost:59204 manyfaces.mailer.v1.MailerService/SendTemplatedEmail
```

If **`MAILER_WORKER_EXPECTED_TOKEN`** is set, add a metadata header:

```bash
grpcurl -plaintext \
  -H 'x-mailer-worker-token: YOUR_TOKEN' \
  -d '{ ... }' \
  localhost:59204 manyfaces.mailer.v1.MailerService/SendTemplatedEmail
```

## Template catalog (v1)

| `template_id` | Required `params` | Locales |
| --- | --- | --- |
| `identity_email_confirm` | `action_link`, `user_name` | `en`, `sk` (+ fallback chain in worker) |
| `identity_password_reset` | `action_link`, `user_name` | `en`, `sk` |

The backend **`MailerGrpcEmailSender`** classifies Identity mail from HTML markers, **does not** forward Identity’s HTML as the MIME body, and passes only the extracted callback URL plus a display name — see code comments in `MailerGrpcEmailSender.cs`.

## TLS / mTLS

Parity with push/search workers: **`MAILER_WORKER_GRPC_TLS_CERT_FILE`**, **`MAILER_WORKER_GRPC_TLS_KEY_FILE`**, optional **`MAILER_WORKER_GRPC_MTLS_CLIENT_CA_FILE`**, and backend **`Mail:WorkerTls*`** when **`Mail:WorkerGrpcUrl`** uses **`https://`**.

**Step-by-step:** **[mailer-grpc-tls-mtls.md](./mailer-grpc-tls-mtls.md)** (openssl, grpcurl, CI smoke script **`many_faces_mailer/scripts/smoke-grpc-tls.sh`**, Docker project **`mf-mailer-tls-smoke`**, host gRPC port **59216**). The push-worker guide remains a useful generic reference: **[push-grpc-tls-mtls.md](./push-grpc-tls-mtls.md)**.

## Resilience and retries (backend)

- **Transient `UNAVAILABLE`** from the worker (SMTP or network) may justify a **limited** retry in application code; **`INVALID_ARGUMENT`**, **`FAILED_PRECONDITION`**, and most other codes should **not** be blindly retried.
- Retrying user-visible flows (password reset, confirmation) without an **`idempotency_key`** policy risks **duplicate email**; v1 logs `idempotency_key` when present but does not deduplicate yet — prefer at-most-once send semantics at the caller.

## Runbook (quick)

| Symptom | Checks |
| ------- | ------ |
| No mail at all | `Mail:Enabled`, worker container up, `Mail:WorkerGrpcUrl` reachable from `be-demo-dev`, `MAILER_WORKER_EXPECTED_TOKEN` matches `Mail:WorkerAuthToken`, Mailpit SMTP port |
| gRPC `UNAUTHENTICATED` | Token header on client vs `MAILER_WORKER_EXPECTED_TOKEN` |
| SMTP auth errors | `MAILER_SMTP_*` credentials; provider suppression / lockout |
| Wrong locale | Missing bundle key in worker `i18n/`; check `Mail:DefaultLocale` |

## Security reminders

- Never commit real SMTP passwords or provider API keys; use gitignored `.env` or Docker secrets.
- For real relays, configure **SPF**, **DKIM**, and **DMARC** on your sending domain — the worker cannot fix DNS.
