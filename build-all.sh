#!/bin/bash

# build-all.sh - Build all projects (be_demo, fe_demo, admin_demo, ai_demo)
#
# Runs build for each project without Docker.
# - be_demo: dotnet build
# - fe_demo: yarn build
# - admin_demo: yarn build (vite only, no tsc - see admin package.json)
# - ai_demo: pip install + optional model download (Python, no traditional "build")
#
# Usage: ./build-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FAILED=0

echo "🔨 Building all projects..."
echo ""

# Backend
echo "═══════════════════════════════════════════════════════════"
echo "  Building Backend (be_demo)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "be_demo" ]; then
  (cd be_demo && dotnet build) || FAILED=1
else
  echo "⚠️  be_demo not found, skipping"
fi
echo ""

# Frontend
echo "═══════════════════════════════════════════════════════════"
echo "  Building Frontend (fe_demo)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "fe_demo" ]; then
  (cd fe_demo && yarn build) || FAILED=1
else
  echo "⚠️  fe_demo not found, skipping"
fi
echo ""

# Admin
echo "═══════════════════════════════════════════════════════════"
echo "  Building Admin (admin_demo)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "admin_demo" ]; then
  (cd admin_demo && yarn build) || FAILED=1
else
  echo "⚠️  admin_demo not found, skipping"
fi
echo ""

# AI Demo - Python, verify deps install
echo "═══════════════════════════════════════════════════════════"
echo "  Verifying AI Demo (ai_demo)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "ai_demo" ]; then
  if command -v python3 &>/dev/null; then
    (cd ai_demo && python3 -m pip install -q -r requirements.txt 2>/dev/null) && echo "✅ ai_demo: dependencies OK" || echo "⚠️  ai_demo: pip install had issues (optional for Docker builds)"
  else
    echo "⚠️  python3 not found, ai_demo skip (use Docker for ai_demo)"
  fi
else
  echo "⚠️  ai_demo not found, skipping"
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
  echo "✅ Build all completed successfully!"
  exit 0
else
  echo "❌ Some builds failed"
  exit 1
fi
