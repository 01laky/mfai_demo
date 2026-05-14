#!/usr/bin/env bash
# Run root orchestration scripts in CI order (lint → build → test).
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
echo "  ci-local: lint-all → build-all → test-all"
echo "  SKIP_CYPRESS=$SKIP_CYPRESS"
echo "═══════════════════════════════════════════════════════════"
echo ""

chmod +x "$SCRIPTS_DIR/lint-all.sh" "$SCRIPTS_DIR/build-all.sh" "$SCRIPTS_DIR/test-all.sh" 2>/dev/null || true
for s in many_faces_backend many_faces_portal many_faces_admin many_faces_mobile many_faces_ai many_faces_database many_faces_redis many_faces_logger many_faces_elastic many_faces_push many_faces_mailer; do
  if [ -d "$s/scripts" ]; then
    find "$s/scripts" -maxdepth 1 -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  fi
done

"$SCRIPTS_DIR/lint-all.sh"
"$SCRIPTS_DIR/build-all.sh"
"$SCRIPTS_DIR/test-all.sh"

echo ""
echo "✅ ci-local completed successfully"
