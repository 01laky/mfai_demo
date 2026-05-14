#!/usr/bin/env bash
#
# lint-all.sh — run each submodule's lint entrypoint from the monorepo root.
#
# For each first-party app below, the script looks for ./scripts/lint.sh inside
# the submodule directory, or ./lint.sh at the repository root of that submodule.
# If neither exists, the project is skipped with a warning (common when a
# submodule is not checked out in a sparse clone); that skip does not set FAILED.
#
# Order: infra + workers (database, redis, logger, elastic, push, mailer), then
# portal, admin, mobile, backend, AI. Each project runs in a subshell so a failure
# is recorded via FAILED=1 without aborting the rest.
#
# Exit codes: 0 if every executed lint succeeded, 1 if any executed lint failed.
#
# Usage: ./scripts/lint-all.sh (from repository root)

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/_monorepo.sh
# shellcheck disable=SC1091
. "$SCRIPTS_DIR/_monorepo.sh"

FAILED=0

lint_project() {
    local dir=$1
    local name=$2
    local run=""
    if [ -f "$dir/scripts/lint.sh" ]; then
        run="./scripts/lint.sh"
        chmod +x "$dir/scripts/lint.sh" 2>/dev/null || true
    elif [ -f "$dir/lint.sh" ]; then
        run="./lint.sh"
        chmod +x "$dir/lint.sh" 2>/dev/null || true
    else
        echo "⚠️  $dir/scripts/lint.sh (or lint.sh) not found, skipping $name"
        return
    fi
    if [ -d "$dir/scripts" ]; then
        find "$dir/scripts" -maxdepth 1 -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if (cd "$dir" && $run); then
        echo ""
    else
        FAILED=1
    fi
}

echo "🔍 Linting all projects..."
echo ""

while IFS='|' read -r dir label; do
    [[ -n "$dir" ]] || continue
    lint_project "$dir" "$label"
done <<<"$MONOREPO_LINT_SPECS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ All projects passed lint"
    exit 0
else
    echo "❌ Some projects failed lint"
    exit 1
fi
