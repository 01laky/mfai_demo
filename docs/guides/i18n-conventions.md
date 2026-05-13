# Internationalization (i18n) conventions

## Languages

- **`many_faces_portal`** and **`many_faces_admin`** ship **`en`**, **`sk`**, **`cz`** (and may add more). Mobile follows the same family where parity exists.

## Key structure

- Prefer **namespaced** keys: `routes.*`, `components.*`, `errors.*`, etc.
- Keep **parity** across languages for the same release (missing keys fall back to English in some setups — verify per app).

## Where files live

- Portal / admin: `src/i18n/` trees (see each submodule’s `src/i18n/README.md` when present).

## Process

- When adding UI, add **all** locale files in the same PR when possible.
- For **admin** + **portal** shared concepts (e.g. capability labels), keep naming aligned to reduce translator confusion.

## Related

- [`mobile-expo-development.md`](./mobile-expo-development.md) — mobile copy parity.
