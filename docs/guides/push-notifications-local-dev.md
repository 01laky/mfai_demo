# Push notifications — local development (FCM + `many_faces_push`)

This guide describes how to run the **Go gRPC push worker** (`many_faces_push`) alongside **`many_faces_backend`** inside the **`many_faces_main`** monorepo Docker network, register device tokens from **`many_faces_mobile`**, and perform an **operator-only** smoke send.

**Canonical product spec:** [`../prompts/push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md`](../prompts/push-notifications-fcm-go-grpc-firebase-worker-agent-prompt.md).

**Transport security (TLS/mTLS) for backend ↔ worker gRPC:** [`push-grpc-tls-mtls.md`](./push-grpc-tls-mtls.md) (same patterns as [`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md)).

**Submodule README (ports, security, proto regeneration):** [`../../many_faces_push/README.md`](../../many_faces_push/README.md).

---

## v1 transport decision (FCM token path)

Many Faces **v1** targets **direct FCM registration tokens** obtained on the mobile client per current **Expo / EAS** documentation for your project (path **A** in the agent prompt). The Go worker uses **Firebase Admin SDK** only. **Do not mix** Expo Push Service tokens with this worker unless you explicitly change the architecture (prompt path **B**).

---

## Prerequisites

- A **Firebase / GCP** project with **Cloud Messaging** enabled.
- A **service account JSON** with permission to send FCM messages (typical role: **Firebase Cloud Messaging API Admin** or a custom role including `cloudmessaging.messages.create`). **Never commit** this file.
- **iOS:** APNs key or certificate uploaded to Firebase (required for Apple devices to receive FCM-delivered notifications).
- **Android:** `google-services.json` belongs in the **mobile app** build, not in the push worker repository (the worker uses the service account only).

---

## Ports (defaults)

| Direction | Value |
| --------- | ----- |
| Host → push-worker gRPC (debug / grpcurl) | `localhost:59203` → container `50053` |
| Backend container → worker | `http://push-worker-dev:50053` on `many_faces_main_dev-network` |

---

## One-time local files (gitignored)

| File | Where | Purpose |
| ---- | ----- | ------- |
| Service account JSON | e.g. `many_faces_push/firebase-sa.json` (host path) | `GOOGLE_APPLICATION_CREDENTIALS` for the worker |
| `GoogleService-Info.plist` | Mobile / optional copy in `many_faces_push/` root | iOS client config only |
| `google-services.json` | Mobile | Android client config |

---

## Start the worker with the full dev stack

Copy **[`dev/push-dev.env.example`](../../dev/push-dev.env.example)** into a **`.env`** file at the monorepo root (or export the same variables), then:

```bash
export ENABLE_PUSH_WORKER=1
# Optional shared secret — must match on worker and API when both use it:
# export PUSH_WORKER_EXPECTED_TOKEN=dev-shared-secret
./scripts/start-all-dev.sh
```

**Service account file:** save the Firebase **private key JSON** as **`many_faces_push/firebase-sa.json`** (gitignored via `*-sa.json`). `start-all-dev.sh` sets **`FIREBASE_SA_HOST_PATH`** automatically when that file exists, and **`scripts/start-push-worker.sh`** merges **`docker-compose.credentials.yml`** to mount it at `/run/secrets/firebase-sa.json` and set **`GOOGLE_APPLICATION_CREDENTIALS`**.

If the JSON lives elsewhere, export an absolute path before starting:

```bash
export FIREBASE_SA_HOST_PATH=/absolute/path/to/firebase-adminsdk.json
export ENABLE_PUSH_WORKER=1
./scripts/start-all-dev.sh
```

The script runs `many_faces_push/scripts/start-push-worker.sh`, waits for **localhost:59203**, and connects **`push-worker-dev`** to **`many_faces_main_dev-network`**.

When **`ENABLE_PUSH_WORKER=1`**, `start-all-dev.sh` also exports **`PUSH_DEV_*`** so **`be-demo-dev`** receives **`Push__Enabled=true`** and **`Push__WorkerGrpcUrl=http://push-worker-dev:50053`** via root **`docker-compose.dev.yml`** (see `Push__*` lines there).

---

## Backend configuration (`many_faces_backend`)

Set **`Push:`** keys (Docker env uses double underscore `Push__*`):

| Key | Example | Notes |
| --- | ------- | ----- |
| `Push__Enabled` | `true` | Master switch |
| `Push__WorkerGrpcUrl` | `http://push-worker-dev:50053` | Cleartext OK only on trusted dev Docker networks |
| `Push__WorkerAuthToken` | same as `PUSH_WORKER_EXPECTED_TOKEN` | Optional; metadata `x-push-worker-token` |

When **`Push:Enabled`** is false, **`IPushWorkerClient.SendPushAsync`** returns `null` and the API does not throw during startup.

---

## Mobile registration API

Authenticated clients call the **face-scoped** path (same rule as other REST traffic; the test `FaceScopeTestHandler` mirrors this for integration tests):

- **`POST /{face-kebab}/api/me/push-token`** with JSON `{ "registrationToken", "platform": "ios"|"android", "installationId?": "..." }`.
- **`DELETE /{face-kebab}/api/me/push-token?installationId=...`** removes rows for that installation for the caller; omit `installationId` to delete **all** push rows for the user (rare; mobile logout uses the query for a single device).

The backend stores rows in **`UserPushDevices`** (EF migration `AddUserPushDevices`).

---

## Operator smoke test (admin)

After at least one device row exists for your operator user:

1. Obtain a JWT with **`CanManageAllFaces`** (seed admin / operator account — see [`local-dev-accounts.md`](./local-dev-accounts.md)).
2. `POST /{admin-face}/api/admin/push/test-self` with `Authorization: Bearer …` (e.g. **`POST /admin/api/admin/push/test-self`** when the admin scope URL prefix is `admin`).

The backend loads **all tokens for the caller** and invokes **`PushService.SendPush`** with localization keys **`push_self_test_title`** / **`push_self_test_body`**. Permanently invalid FCM tokens are **deleted** from SQL based on worker results.

---

## Notification localization catalog (v1 keys)

Strings **must** exist in the mobile app bundle (see agent prompt §3.4.1). Backend and worker carry **keys + args only**.

| `title_loc_key` | `body_loc_key` | title args | body args | Meaning |
| --------------- | -------------- | ---------- | --------- | ------- |
| `push_self_test_title` | `push_self_test_body` | 0 | 0 | Admin self-test ping |

The Expo config plugin **`many_faces_mobile/plugins/withPushLocaleResources.ts`** injects **English** (`values/strings.xml`, `en.lproj/Localizable.strings`) and **Slovak** (`values-sk/strings.xml`, `sk.lproj/Localizable.strings`) at **prebuild** time. Re-run `npx expo prebuild` / EAS when you add keys to this table.

When you add product events, extend this table and extend the same plugin (or native resources) so keys stay in sync.

---

## End-to-end manual smoke (definition of done)

1. **Prebuild mobile** with Firebase Android file when testing FCM on Android: set **`GOOGLE_SERVICES_JSON`** to the path of your `google-services.json` before `npx expo prebuild` / EAS (see `many_faces_mobile/app.config.ts`). iOS needs **`GoogleService-Info.plist`** in the native project per Expo / Firebase docs.
2. Install the dev client on a **physical device**, sign in, accept notification permission — the app registers **`POST /{face}/api/me/push-token`** using the **currently selected face** segment.
3. Obtain an operator JWT with **`CanManageAllFaces`** and call **`POST /admin/api/admin/push/test-self`** (or the correct `/{admin-face}/api/admin/push/test-self` for your deployment) with `Authorization: Bearer …`. With the worker + credentials healthy, the device should show a notification whose **title/body** resolve from native strings (`push_self_test_*`), not raw keys.
4. **Tap** the notification: the mobile app treats **`data.route === "push-test"`** (admin smoke payload) and navigates to **Home** (extend `PushNotificationResponseEffect` when product routes ship).
5. **Logout** on the device: the app calls **`DELETE /{face}/api/me/push-token?installationId=...`** so SQL does not retain a stale token for that install.

---

## grpcurl example (optional)

With reflection enabled (`PUSH_WORKER_GRPC_REFLECTION=1` in compose defaults) and metadata token if configured:

```bash
grpcurl -plaintext -d '{"registration_tokens":["YOUR_TOKEN"],"title_loc_key":"push_self_test_title","body_loc_key":"push_self_test_body"}' \
  -H 'x-push-worker-token: YOUR_TOKEN_IF_SET' \
  localhost:59203 manyfaces.push.v1.PushService/SendPush
```

Never paste production tokens into tickets or logs.

---

## Troubleshooting

| Symptom | Check |
| ------- | ----- |
| `FailedPrecondition` from worker | `GOOGLE_APPLICATION_CREDENTIALS` missing or unreadable inside the container |
| `Unauthenticated` | `PUSH_WORKER_EXPECTED_TOKEN` / `Push__WorkerAuthToken` mismatch |
| iOS never shows notification | Firebase APNs configuration, device permissions, correct bundle ID |
| Backend `null` from client | `Push:Enabled` false or invalid `Push:WorkerGrpcUrl` |

---

## Stop

`./scripts/stop-all-dev.sh` stops **`many_faces_push`** via `many_faces_push/scripts/stop-push-worker.sh` before Elasticsearch teardown.
