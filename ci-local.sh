#!/usr/bin/env bash
# Run root orchestration scripts in CI order (lint → build → test).
# Skips Cypress e2e (set SKIP_CYPRESS=0 to allow e2e when stack is up).
# Prerequisites: submodules checked out, Docker available for compose validation
# is covered by separate workflow jobs; this script does not start containers.
#
# Usage: ./ci-local.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export SKIP_CYPRESS="${SKIP_CYPRESS:-1}"

echo "═══════════════════════════════════════════════════════════"
echo "  ci-local: lint-all → build-all → test-all"
echo "  SKIP_CYPRESS=$SKIP_CYPRESS"
echo "═══════════════════════════════════════════════════════════"
echo ""

chmod +x lint-all.sh build-all.sh test-all.sh 2>/dev/null || true
for s in be_demo fe_demo admin_demo ai_demo; do
  [ -f "$s/lint.sh" ] && chmod +x "$s/lint.sh" || true
done
chmod +x ai_demo/verify-ci.sh 2>/dev/null || true

./lint-all.sh
./build-all.sh
./test-all.sh

echo ""
echo "✅ ci-local completed successfully"
