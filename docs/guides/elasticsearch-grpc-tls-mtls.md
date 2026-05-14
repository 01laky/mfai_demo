# Search-worker gRPC: TLS and mTLS

This guide describes how to protect the **gRPC** link between **`many_faces_backend`** and the Go **search-worker** in **`many_faces_elastic`**. Local Docker defaults use **cleartext HTTP/2 (h2c)** on a private bridge network; production-style deployments should use **TLS** on the same TCP port and optionally **mutual TLS (mTLS)** so only trusted callers present a client certificate.

**Elasticsearch HTTP** and **PostgreSQL** are out of scope here; only the **backend → worker** gRPC hop is covered.

## Threat model (short)

Without TLS, any process that can reach the worker’s gRPC port can call it. A shared metadata token (`x-search-worker-token`) helps but is not a substitute for transport encryption on untrusted networks. **TLS** provides confidentiality and integrity; **mTLS** adds client authentication at the TLS layer (in addition to optional token checks).

## Worker (Go): environment variables

| Variable | Role |
| -------- | ---- |
| `SEARCH_WORKER_GRPC_TLS_CERT_FILE` | Server certificate PEM path. |
| `SEARCH_WORKER_GRPC_TLS_KEY_FILE` | Server private key PEM path matching the certificate. |
| `SEARCH_WORKER_GRPC_MTLS_CLIENT_CA_FILE` | Optional PEM bundle of CAs used to verify **client** certificates. When set together with cert+key, the worker requires a valid client cert (**mTLS**). |

If **both** cert and key paths are **empty**, the worker listens in **plaintext** (development only). If **either** is set without the other, the process exits with a configuration error.

## Backend (.NET): `Search` configuration

| Key | When to use |
| --- | ----------- |
| `Search:WorkerGrpcUrl` | Use `https://host:port` for TLS. Use `http://…` only on trusted dev networks (requires `Http2UnencryptedSupport`; see `Program.cs`). |
| `Search:WorkerTlsServerCaPath` | PEM file with one or more CA certificates when the server uses a **private CA** or **self-signed** cert not in the OS trust store. |
| `Search:WorkerTlsClientCertPath` / `Search:WorkerTlsClientKeyPath` | PEM client cert and key when the worker runs with **mTLS** (`SEARCH_WORKER_GRPC_MTLS_CLIENT_CA_FILE`). |
| `Search:WorkerGrpcTlsServerName` | Optional TLS server name (SNI / validation) when it differs from the host in `WorkerGrpcUrl`. |

TLS-related keys are ignored for `http://` URLs; setting them with `http://` causes startup failure with a clear error.

## Generating a small internal CA (openssl example)

The commands below create a **demo** hierarchy on a machine with OpenSSL 3.x style defaults. Adjust validity, subject names, and key types for your organization’s policy.

```bash
mkdir -p demo-grpc-tls && cd demo-grpc-tls

# Root CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/CN=Many Faces Search gRPC Demo Root" -out ca.crt

# Server cert (SAN: adjust hostnames for your worker DNS name)
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr \
  -subj "/CN=search-worker.internal"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 825 -sha256 \
  -extfile <(printf "subjectAltName=DNS:search-worker.internal,DNS:search-worker-dev")

# Client (API) cert for mTLS
openssl genrsa -out api-client.key 4096
openssl req -new -key api-client.key -out api-client.csr \
  -subj "/CN=many-faces-backend"
openssl x509 -req -in api-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out api-client.crt -days 825 -sha256
```

**Worker** mounts `server.crt`, `server.key`, and for mTLS sets `SEARCH_WORKER_GRPC_MTLS_CLIENT_CA_FILE` to **`ca.crt`** (the same CA that signed the client cert).

**Backend** sets `Search:WorkerTlsServerCaPath` to **`ca.crt`**, `WorkerTlsClientCertPath` / `WorkerTlsClientKeyPath` to **`api-client.crt`** / **`api-client.key`**, and `WorkerGrpcUrl` to **`https://search-worker.internal:50052`** (or the real DNS name), optionally `WorkerGrpcTlsServerName` if the URL host does not match the certificate SAN.

## Docker mounts

Mount PEM files read-only into both containers, for example:

```yaml
volumes:
  - ./demo-grpc-tls/server.crt:/run/grpc-tls/server.crt:ro
  - ./demo-grpc-tls/server.key:/run/grpc-tls/server.key:ro
  - ./demo-grpc-tls/ca.crt:/run/grpc-tls/client-ca.crt:ro
environment:
  - SEARCH_WORKER_GRPC_TLS_CERT_FILE=/run/grpc-tls/server.crt
  - SEARCH_WORKER_GRPC_TLS_KEY_FILE=/run/grpc-tls/server.key
  - SEARCH_WORKER_GRPC_MTLS_CLIENT_CA_FILE=/run/grpc-tls/client-ca.crt
```

The API container needs matching mounts for `Search:WorkerTls*` paths.

## grpcurl with TLS

Without mTLS:

```bash
grpcurl -cacert ca.crt search-worker.internal:50052 list
```

With mTLS (client cert):

```bash
grpcurl -cacert ca.crt -cert api-client.crt -key api-client.key \
  search-worker.internal:50052 grpc.health.v1.Health/Check
```

## Continuous integration

The monorepo workflow **`.github/workflows/ci.yml`** includes:

- **`infra_many_faces_elastic`**: validates `docker compose … config` for **`many_faces_elastic/docker-compose.yml`** and **`many_faces_elastic/docker-compose.tls-smoke.yml`** (the TLS smoke file only needs `SEARCH_TLS_SMOKE_CERT_DIR` set to an existing directory so Compose can expand the volume source path; it does not run containers).
- **`smoke_search_worker_grpc_tls`**: runs **`many_faces_elastic/scripts/smoke-grpc-tls.sh`**, which generates a short-lived CA + server + client PEM chain with **OpenSSL**, sets **directory and file modes** so the **distroless nonroot** worker can read the bind-mounted `/tls` PEMs, starts **Elasticsearch + search-worker** from **`docker-compose.tls-smoke.yml`**, asserts **`grpcurl`** `Ping` sees Elasticsearch, then runs **`dotnet test`** filtered to **`SearchWorkerTlsEndToEndSmokeTests`** with **`SEARCH_TLS_SMOKE=1`**.

Normal **`dotnet test`** without that environment variable skips the end-to-end class in milliseconds; fast TLS **option** validation lives in **`SearchWorkerGrpcProbeOptionsTests`**.

## Related documentation

- Feature overview (stack capabilities, verification matrix): [`elasticsearch-search-features-overview.md`](./elasticsearch-search-features-overview.md)
- Local dev (plaintext defaults): [`elasticsearch-local-dev.md`](./elasticsearch-local-dev.md)
- Submodule overview: [`many_faces_elastic/README.md`](../../many_faces_elastic/README.md)
- **Push-worker** (FCM sidecar) uses the same TLS/mTLS vocabulary: [`push-grpc-tls-mtls.md`](./push-grpc-tls-mtls.md)
