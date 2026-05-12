#!/bin/bash

# build-all.sh - Build all projects (many_faces_backend, many_faces_portal, many_faces_admin, many_faces_ai)
#
# Runs build for each project without Docker.
# - many_faces_backend: dotnet build
# - many_faces_portal: yarn build
# - many_faces_admin: yarn build (vite only, no tsc - see admin package.json)
# - many_faces_ai: pip install + optional model download (Python, no traditional "build")
#
# Usage: ./scripts/build-all.sh (from repository root)

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

FAILED=0

echo "🔨 Building all projects..."
echo ""

# Backend
echo "═══════════════════════════════════════════════════════════"
echo "  Building Backend (many_faces_backend)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_backend" ]; then
  (cd many_faces_backend && dotnet build -c Release) || FAILED=1
else
  echo "⚠️  many_faces_backend not found, skipping"
fi
echo ""

# Frontend
echo "═══════════════════════════════════════════════════════════"
echo "  Building Frontend (many_faces_portal)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_portal" ]; then
  (cd many_faces_portal && yarn build) || FAILED=1
else
  echo "⚠️  many_faces_portal not found, skipping"
fi
echo ""

# Admin
echo "═══════════════════════════════════════════════════════════"
echo "  Building Admin (many_faces_admin)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_admin" ]; then
  (cd many_faces_admin && yarn build) || FAILED=1
else
  echo "⚠️  many_faces_admin not found, skipping"
fi
echo ""

# AI Demo — same checks as CI (ruff + pytest, no full torch stack)
echo "═══════════════════════════════════════════════════════════"
echo "  Verifying AI Demo (many_faces_ai / verify-ci.sh)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_ai" ]; then
  chmod +x many_faces_ai/verify-ci.sh 2>/dev/null || true
  (cd many_faces_ai && ./verify-ci.sh) || FAILED=1
else
  echo "⚠️  many_faces_ai not found, skipping"
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
