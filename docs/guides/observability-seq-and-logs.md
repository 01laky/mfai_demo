# Observability — Seq and logs

## Backend (ASP.NET)

- **Serilog** sinks typically include **console** and **Seq** in development.
- Default local Seq UI port is documented alongside API ports in [`dev-https.md`](./dev-https.md) and the root [`README.md`](../../README.md).

## Frontends

- Portal and admin may ship optional Seq / browser logging helpers; check each submodule’s README and any `SEQ_FRONTEND_LOGS.md`-style notes **inside that submodule** if present.

## Container logs

- **`many_faces_logger`** (Dozzle) — see [`many_faces_logger/README.md`](../../many_faces_logger/README.md).

## Practices

- Correlate by **request path**, **user id**, and **face id** when debugging multi-tenant issues.
- For AI moderation, also trace **job id** / **content id** (see [`content-moderation-operations.md`](./content-moderation-operations.md)).

## Related

- [`troubleshooting-local-dev.md`](./troubleshooting-local-dev.md)
