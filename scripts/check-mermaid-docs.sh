#!/usr/bin/env bash
# Validate every ```mermaid fenced block in repo Markdown via @mermaid-js/mermaid-cli.
# Slower than Prettier: downloads Chromium on first run. Not part of scripts/ci-local.sh by default.
# Linux CI (e.g. GitHub Actions): mmdc uses scripts/mermaid-puppeteer-ci.json so Chromium can start without a user namespace sandbox.
#
# Usage:
#   ./scripts/check-mermaid-docs.sh
#   MERMAID_CLI_VERSION=11.4.1 ./scripts/check-mermaid-docs.sh
#
# Requires: Node.js (npx), Python 3.

set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"
exec python3 "$SCRIPTS_DIR/check_mermaid_docs.py" --root "$ROOT" "$@"
