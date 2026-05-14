# Push-worker gRPC: TLS and mTLS

This guide mirrors **[`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md)** for the **Go push worker** in **`many_faces_push`**: cleartext **h2c** is fine on a trusted Docker bridge; production-style setups should use **TLS** and optionally **mTLS** so only trusted callers ( **`many_faces_backend`** ) open the channel.

**Product context:** [`push-notifications-local-dev.md`](./push-notifications-local-dev.md) · Submodule **[`many_faces_push/README.md`](../../many_faces_push/README.md)**.

---

## Worker (Go): environment variables

| Variable | Role |
| -------- | ---- |
| `PUSH_WORKER_GRPC_TLS_CERT_FILE` | Server certificate PEM path. |
| `PUSH_WORKER_GRPC_TLS_KEY_FILE` | Server private key PEM path matching the certificate. |
| `PUSH_WORKER_GRPC_MTLS_CLIENT_CA_FILE` | Optional PEM bundle of CAs used to verify **client** certificates. When set together with cert+key, the worker requires a valid client cert (**mTLS**). |

If **both** cert and key paths are **empty**, the worker listens in **plaintext** (development only). If **either** is set without the other, the process exits with a configuration error (same semantics as the search-worker).

---

## Backend (.NET): `Push` configuration

| Key | When to use |
| --- | ----------- |
| `Push:WorkerGrpcUrl` | Use `https://host:port` for TLS. Use `http://…` only on trusted dev networks (`Http2UnencryptedSupport` in `Program.cs`). |
| `Push:WorkerTlsServerCaPath` | PEM file with one or more CA certificates when the server uses a **private CA** or **self-signed** cert. |
| `Push:WorkerTlsClientCertPath` / `Push:WorkerTlsClientKeyPath` | PEM client cert and key when the worker runs with **mTLS** (`PUSH_WORKER_GRPC_MTLS_CLIENT_CA_FILE`). |
| `Push:WorkerGrpcTlsServerName` | Optional TLS server name (SNI / validation) when it differs from the host in `WorkerGrpcUrl`. |

TLS-related keys are **ignored** for `http://` URLs; setting them with `http://` causes startup failure (validated in **`GrpcWorkerChannelFactory`**).

---

## Generating a small internal CA (openssl)

Use the same flow as the search-worker guide **[`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md#generating-a-small-internal-ca-openssl-example)**; substitute **SAN** hostnames for your push worker DNS name (e.g. `push-worker.internal`) and name client CN **`many-faces-backend`**.

**Worker** mounts `server.crt`, `server.key`, and for mTLS sets `PUSH_WORKER_GRPC_MTLS_CLIENT_CA_FILE` to **`ca.crt`**.

**Backend** sets `Push:WorkerTlsServerCaPath` to **`ca.crt`**, client PEM paths as above, and `Push:WorkerGrpcUrl` to **`https://push-worker.internal:50053`** (or your real DNS / Docker DNS name).

---

## grpcurl with TLS

Without mTLS (private CA still needs `-cacert`):

```bash
grpcurl -cacert ca.crt push-worker.internal:50053 grpc.health.v1.Health/Check
```

With mTLS:

```bash
grpcurl -cacert ca.crt -cert api-client.crt -key api-client.key \
  push-worker.internal:50053 grpc.health.v1.Health/Check
```

---

## CI and automated smoke

The monorepo workflow **`.github/workflows/ci.yml`** includes **`smoke_push_worker_grpc_tls`**, which runs **`many_faces_push/scripts/smoke-grpc-tls.sh`**: OpenSSL generates a short-lived CA + server + client chain, starts **`docker-compose.tls-smoke.yml`**, asserts **`grpcurl`** `Health/Check`, then runs **`dotnet test`** filtered to **`PushWorkerTlsEndToEndSmokeTests`** with **`PUSH_TLS_SMOKE=1`**.

Normal **`dotnet test`** without that environment variable skips the Docker-backed class; fast TLS option validation lives in **`GrpcWorkerChannelFactoryPushOptionsTests`**.

The **`infra_many_faces_push`** job validates **`docker-compose.tls-smoke.yml`** compose expansion using **`PUSH_TLS_SMOKE_CERT_DIR=/tmp`**.

---

## Related documentation

- Search-worker TLS reference (same patterns): [`elasticsearch-grpc-tls-mtls.md`](./elasticsearch-grpc-tls-mtls.md)
- Push stack local dev: [`push-notifications-local-dev.md`](./push-notifications-local-dev.md)
