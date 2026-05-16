#!/usr/bin/env bash
# Fast static checks that dev-stack scripts and compose stay aligned (no Docker).
# Catches regressions like ENABLE_* default drift, missing SEARCH_DEV wiring, or
# grpcurl TLS smoke scripts that forgot -proto when reflection is off.
#
# Usage: ./scripts/verify-dev-stack-contracts.sh (from repository root)
# Invoked from: scripts/ci-local.sh (before lint-all).

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

fail() {
  echo "verify-dev-stack-contracts: $*" >&2
  exit 1
}

echo "🔎 verify-dev-stack-contracts: bash -n on orchestration scripts..."
for f in \
  start-all-dev.sh stop-all-dev.sh clear-all-dev.sh rebuild-all-dev.sh restart-all-dev.sh \
  status-all.sh test-all.sh build-all.sh lint-all.sh start-missing-dev.sh menu.sh ci-local.sh \
  verify-dev-stack-contracts.sh smoke-localization-api.sh _monorepo.sh; do
  bash -n "$SCRIPTS_DIR/$f" || fail "bash -n failed: $f"
done

echo "🔎 verify-dev-stack-contracts: node colocation scripts exist..."
for f in \
  verify-portal-component-colocation.mjs colocate-portal-component.mjs \
  verify-admin-component-colocation.mjs colocate-admin-component.mjs \
  migrate-admin-colocate-phase.mjs fix-admin-colocated-relative-paths.mjs \
  migrate-admin-imports-to-alias.mjs; do
  [ -f "$SCRIPTS_DIR/$f" ] || fail "missing $f"
done

echo "🔎 verify-dev-stack-contracts: start-all-dev ENABLE_* defaults (must be on unless =0)..."
grep -q 'ENABLE_ELASTICSEARCH:-1' "$SCRIPTS_DIR/start-all-dev.sh" \
  || fail "start-all-dev.sh missing ENABLE_ELASTICSEARCH:-1 default"
grep -q 'ENABLE_PUSH_WORKER:-1' "$SCRIPTS_DIR/start-all-dev.sh" \
  || fail "start-all-dev.sh missing ENABLE_PUSH_WORKER:-1 default"
grep -q 'ENABLE_MAILER_WORKER:-1' "$SCRIPTS_DIR/start-all-dev.sh" \
  || fail "start-all-dev.sh missing ENABLE_MAILER_WORKER:-1 default"
grep -q 'SEARCH_DEV_ENABLED=true' "$SCRIPTS_DIR/start-all-dev.sh" \
  || fail "start-all-dev.sh missing SEARCH_DEV_* export for backend"

echo "🔎 verify-dev-stack-contracts: docker-compose.dev.yml Search + worker env wiring..."
grep -q 'Search__Enabled=\${SEARCH_DEV_ENABLED' "$ROOT/docker-compose.dev.yml" \
  || fail "docker-compose.dev.yml missing Search__Enabled SEARCH_DEV substitution"
grep -q 'Push__Enabled=\${PUSH_DEV_ENABLED' "$ROOT/docker-compose.dev.yml" \
  || fail "docker-compose.dev.yml missing Push__ wiring"
grep -q 'Mail__Enabled=\${MAIL_DEV_ENABLED' "$ROOT/docker-compose.dev.yml" \
  || fail "docker-compose.dev.yml missing Mail__ wiring"

echo "🔎 verify-dev-stack-contracts: TLS smoke grpcurl uses vendored health.proto (reflection off)..."
for pair in \
  "many_faces_mailer/scripts/smoke-grpc-tls.sh:many_faces_mailer/scripts/grpcurl-protos/grpc/health/v1/health.proto" \
  "many_faces_push/scripts/smoke-grpc-tls.sh:many_faces_push/scripts/grpcurl-protos/grpc/health/v1/health.proto"; do
  sh="${pair%%:*}"
  proto="${pair#*:}"
  [ -f "$ROOT/$sh" ] || fail "missing $sh"
  [ -f "$ROOT/$proto" ] || fail "missing $proto"
  grep -q 'grpcurl-protos' "$ROOT/$sh" || fail "$sh must reference grpcurl-protos for grpcurl -import-path"
  grep -q 'grpc/health/v1/health.proto' "$ROOT/$sh" || fail "$sh must pass -proto grpc/health/v1/health.proto"
done

echo "✅ verify-dev-stack-contracts: all checks passed"
