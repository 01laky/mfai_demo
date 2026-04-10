#!/usr/bin/env bash
# Validate every ```mermaid fenced block in repo Markdown via @mermaid-js/mermaid-cli.
# Slower than Prettier: downloads Chromium on first run. Not part of ci-local.sh by default.
#
# Usage:
#   ./check-mermaid-docs.sh
#   MERMAID_CLI_VERSION=11.4.1 ./check-mermaid-docs.sh
#   ./check-mermaid-docs.sh   # optional: python3 scripts/check_mermaid_docs.py --root . -v
#
# Requires: Node.js (npx), Python 3.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
exec python3 "$ROOT/scripts/check_mermaid_docs.py" --root "$ROOT" "$@"
