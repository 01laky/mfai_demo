#!/usr/bin/env bash
#
# restart-all-dev.sh — full Docker dev stack: stop then start (same flow as start-all-dev).
#
# Uses ./scripts/stop-all-dev.sh then ./scripts/start-all-dev.sh from the monorepo root.
# Optional env: same as start-all-dev. Workers (Elasticsearch, push, mailer) are on by default; set ENABLE_*=0 to skip.
#
# By default skips the interactive live status TUI at the end of start-all-dev (sets
# SKIP_STATUS_SCREEN=1). To see the TUI after restart: SKIP_STATUS_SCREEN=0 ./scripts/restart-all-dev.sh
#
# Usage: ./scripts/restart-all-dev.sh (from repository root)

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

echo "🔄 restart-all-dev: stop then start (Docker stack via start-all-dev)"
export SKIP_STATUS_SCREEN="${SKIP_STATUS_SCREEN:-1}"

"$SCRIPTS_DIR/stop-all-dev.sh"
"$SCRIPTS_DIR/start-all-dev.sh"
