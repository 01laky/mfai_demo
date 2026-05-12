#!/bin/bash

# Lint all projects: portal, backend, admin, mobile (Expo), AI
# Usage: ./scripts/lint-all.sh (from repository root)

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

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

lint_project "many_faces_portal" "many_faces_portal (frontend)"
lint_project "many_faces_backend" "many_faces_backend (backend)"
lint_project "many_faces_admin" "many_faces_admin (admin)"
lint_project "many_faces_mobile" "many_faces_mobile (Expo)"
lint_project "many_faces_ai" "many_faces_ai (AI service)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
    echo "✅ All projects passed lint"
    exit 0
else
    echo "❌ Some projects failed lint"
    exit 1
fi
