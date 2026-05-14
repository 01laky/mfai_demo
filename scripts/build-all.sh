#!/usr/bin/env bash
# build-all.sh — build every app submodule from the monorepo root (no Docker).
#
# Usage: ./scripts/build-all.sh (from repository root)

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

FAILED=0

section() {
  echo "═══════════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════════"
}

run_go_build() {
  local dir=$1 title=$2
  section "$title"
  if [[ ! -d $dir ]]; then
    echo "⚠️  $dir not found, skipping"
    echo ""
    return 0
  fi
  if ! command -v go >/dev/null 2>&1; then
    echo "⚠️  go not on PATH, skipping $dir"
    echo ""
    return 0
  fi
  if (cd "$dir" && go build ./...); then
    :
  else
    FAILED=1
  fi
  echo ""
}

echo "🔨 Building all projects..."
echo ""

section "Building Backend (many_faces_backend)"
if [[ -d many_faces_backend ]]; then
  (cd many_faces_backend && dotnet build -c Release) || FAILED=1
else
  echo "⚠️  many_faces_backend not found, skipping"
fi
echo ""

section "Building Frontend (many_faces_portal)"
if [[ -d many_faces_portal ]]; then
  (cd many_faces_portal && yarn build) || FAILED=1
else
  echo "⚠️  many_faces_portal not found, skipping"
fi
echo ""

section "Building Admin (many_faces_admin)"
if [[ -d many_faces_admin ]]; then
  (cd many_faces_admin && yarn build) || FAILED=1
else
  echo "⚠️  many_faces_admin not found, skipping"
fi
echo ""

section "Build check Mobile (many_faces_mobile)"
if [[ -d many_faces_mobile && -f many_faces_mobile/scripts/build.sh ]]; then
  chmod +x many_faces_mobile/scripts/build.sh 2>/dev/null || true
  (cd many_faces_mobile && ./scripts/build.sh) || FAILED=1
else
  echo "⚠️  many_faces_mobile/scripts/build.sh not found, skipping"
fi
echo ""

section "Verifying Many Faces AI (many_faces_ai / scripts/verify-ci.sh)"
if [[ -d many_faces_ai ]]; then
  find many_faces_ai/scripts -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  (cd many_faces_ai && ./scripts/verify-ci.sh) || FAILED=1
else
  echo "⚠️  many_faces_ai not found, skipping"
fi
echo ""

run_go_build many_faces_elastic "Go build: many_faces_elastic (search worker)"
run_go_build many_faces_push "Go build: many_faces_push"

section "Gradle build: many_faces_mailer"
if [[ ! -d many_faces_mailer ]]; then
  echo "⚠️  many_faces_mailer not found, skipping"
elif [[ ! -f many_faces_mailer/gradlew ]] || ! command -v java >/dev/null 2>&1; then
  echo "⚠️  many_faces_mailer/gradlew or java missing — skipping"
else
  chmod +x many_faces_mailer/gradlew 2>/dev/null || true
  if (cd many_faces_mailer && ./gradlew build --no-daemon); then
    :
  else
    FAILED=1
  fi
fi
echo ""

section "Summary"
if [[ $FAILED -eq 0 ]]; then
  echo "✅ Build all completed successfully!"
  exit 0
fi
echo "❌ Some builds failed"
exit 1
