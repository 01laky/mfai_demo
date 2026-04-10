#!/usr/bin/env bash
# Format every Markdown file in the monorepo with Prettier (markdown parser).
# - Normalizes tables, lists, spacing, and wrapping outside code fences.
# - Fenced blocks (```mermaid, ```bash, …) are kept as code: inner lines are not
#   reformatted as Markdown prose, so Mermaid syntax stays intact.
#
# Usage:
#   ./format-all-doc.sh           # write fixes in place
#   ./format-all-doc.sh --check   # exit 1 if any file would change (CI)
#
# Requires: Node.js + npx (downloads Prettier on first run).
# Env: PRETTIER_VERSION (default 3.8.0, aligned with fe_demo/admin_demo)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PRETTIER_VERSION="${PRETTIER_VERSION:-3.8.0}"
MODE="write"
if [[ "${1:-}" == "--check" ]]; then
  MODE="check"
fi

# Portable: no mapfile / process substitution required (macOS Bash 3.2 friendly).
# If no *.md matches, find does not run -exec (exit 0).
run_prettier() {
  local action="$1"
  find "$ROOT" \
    \( \
    -path '*/.git/*' -o \
    -path '*/node_modules/*' -o \
    -path '*/.yarn/*' -o \
    -path '*/.venv/*' -o \
    -path '*/.venv-ci-verify/*' -o \
    -path '*/venv/*' -o \
    -path '*/site-packages/*' -o \
    -path '*/dist/*' -o \
    -path '*/build/*' -o \
    -path '*/coverage/*' -o \
    -path '*/.turbo/*' -o \
    -path '*/.pytest_cache/*' \
    \) -prune -o \
    -type f \( -name '*.md' -o -name '*.mdx' \) \
    -exec npx --yes "prettier@${PRETTIER_VERSION}" \
    "$action" \
    --parser markdown \
    --prose-wrap preserve \
    --tab-width 2 \
    --end-of-line lf \
    {} +
}

echo "Scanning Markdown under $ROOT; Prettier ${PRETTIER_VERSION} (${MODE})."

if [[ "$MODE" == "check" ]]; then
  run_prettier --check
else
  run_prettier --write
fi

echo "Done."
