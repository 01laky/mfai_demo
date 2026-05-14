#!/usr/bin/env bash
# Run root orchestration scripts in CI order (verify-dev-stack-contracts → lint → build → test).
# Skips Cypress e2e (set SKIP_CYPRESS=0 to allow e2e when stack is up).
# Prerequisites: submodules checked out, Docker available for compose validation
# is covered by separate workflow jobs; this script does not start containers.
#
# Usage: ./scripts/ci-local.sh (from repository root)

set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

export SKIP_CYPRESS="${SKIP_CYPRESS:-1}"

echo "═══════════════════════════════════════════════════════════"
echo "  ci-local: verify-dev-stack-contracts → lint-all → build-all → test-all"
echo "  SKIP_CYPRESS=$SKIP_CYPRESS"
echo "═══════════════════════════════════════════════════════════"
echo ""

chmod +x "$SCRIPTS_DIR/lint-all.sh" "$SCRIPTS_DIR/build-all.sh" "$SCRIPTS_DIR/test-all.sh" "$SCRIPTS_DIR/verify-dev-stack-contracts.sh" "$SCRIPTS_DIR/_monorepo.sh" 2>/dev/null || true
"$SCRIPTS_DIR/verify-dev-stack-contracts.sh"

# shellcheck source=scripts/_monorepo.sh
# shellcheck disable=SC1091
. "$SCRIPTS_DIR/_monorepo.sh"
monorepo_chmod_submodule_scripts

"$SCRIPTS_DIR/lint-all.sh"
"$SCRIPTS_DIR/build-all.sh"
"$SCRIPTS_DIR/test-all.sh"

echo ""
echo "✅ ci-local completed successfully"
