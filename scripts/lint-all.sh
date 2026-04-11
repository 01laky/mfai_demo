#!/bin/bash

# Lint all projects: fe_demo, be_demo, admin_demo, ai_demo
# Usage: ./scripts/lint-all.sh (from repository root)

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

FAILED=0

lint_project() {
    local dir=$1
    local name=$2
    if [ -f "$dir/lint.sh" ]; then
        chmod +x "$dir/lint.sh" 2>/dev/null || true
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📦 $name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if (cd "$dir" && ./lint.sh); then
            echo ""
        else
            FAILED=1
        fi
    else
        echo "⚠️  $dir/lint.sh not found, skipping $name"
    fi
}

echo "🔍 Linting all projects..."
echo ""

lint_project "fe_demo" "fe_demo (frontend)"
lint_project "be_demo" "be_demo (backend)"
lint_project "admin_demo" "admin_demo (admin)"
lint_project "ai_demo" "ai_demo (AI service)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ All projects passed lint"
    exit 0
else
    echo "❌ Some projects failed lint"
    exit 1
fi
