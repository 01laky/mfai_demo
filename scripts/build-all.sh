#!/bin/bash

# build-all.sh - Build all projects (many_faces_backend, many_faces_portal, many_faces_admin,
# many_faces_mobile, many_faces_ai, many_faces_elastic, many_faces_push, many_faces_mailer)
#
# Runs build for each project without Docker.
# - many_faces_backend: dotnet build
# - many_faces_portal: yarn build
# - many_faces_admin: yarn build (vite only, no tsc - see admin package.json)
# - many_faces_mobile: TypeScript + expo-doctor (Phase 1; no EAS native binary)
# - many_faces_ai: pip install + optional model download (Python, no traditional "build")
# - many_faces_elastic / many_faces_push: go build ./... (skipped if go is missing)
# - many_faces_mailer: ./gradlew build (skipped if Gradle wrapper missing)
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

# Mobile (Expo) — static build gate
echo "═══════════════════════════════════════════════════════════"
echo "  Build check Mobile (many_faces_mobile)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_mobile" ] && [ -f "many_faces_mobile/scripts/build.sh" ]; then
  chmod +x many_faces_mobile/scripts/build.sh 2>/dev/null || true
  (cd many_faces_mobile && ./scripts/build.sh) || FAILED=1
else
  echo "⚠️  many_faces_mobile/scripts/build.sh not found, skipping"
fi
echo ""

# Many Faces AI service — same checks as CI (ruff + pytest, no full torch stack)
echo "═══════════════════════════════════════════════════════════"
echo "  Verifying Many Faces AI service (many_faces_ai / scripts/verify-ci.sh)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_ai" ]; then
  find many_faces_ai/scripts -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  (cd many_faces_ai && ./scripts/verify-ci.sh) || FAILED=1
else
  echo "⚠️  many_faces_ai not found, skipping"
fi
echo ""

# Elasticsearch search worker (Go)
echo "═══════════════════════════════════════════════════════════"
echo "  Go build: many_faces_elastic (search worker)"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_elastic" ] && command -v go >/dev/null 2>&1; then
  (cd many_faces_elastic && go build ./...) || FAILED=1
elif [ -d "many_faces_elastic" ]; then
  echo "⚠️  go not on PATH, skipping many_faces_elastic"
else
  echo "⚠️  many_faces_elastic not found, skipping"
fi
echo ""

# FCM push worker (Go)
echo "═══════════════════════════════════════════════════════════"
echo "  Go build: many_faces_push"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_push" ] && command -v go >/dev/null 2>&1; then
  (cd many_faces_push && go build ./...) || FAILED=1
elif [ -d "many_faces_push" ]; then
  echo "⚠️  go not on PATH, skipping many_faces_push"
else
  echo "⚠️  many_faces_push not found, skipping"
fi
echo ""

# Mailer (Gradle / JVM)
echo "═══════════════════════════════════════════════════════════"
echo "  Gradle build: many_faces_mailer"
echo "═══════════════════════════════════════════════════════════"
if [ -d "many_faces_mailer" ] && [ -f "many_faces_mailer/gradlew" ] && command -v java >/dev/null 2>&1; then
  chmod +x many_faces_mailer/gradlew 2>/dev/null || true
  (cd many_faces_mailer && ./gradlew build --no-daemon) || FAILED=1
elif [ -d "many_faces_mailer" ]; then
  echo "⚠️  many_faces_mailer/gradlew or java missing — skipping"
else
  echo "⚠️  many_faces_mailer not found, skipping"
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
