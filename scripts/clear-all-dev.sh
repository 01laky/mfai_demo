#!/usr/bin/env bash
# clear-all-dev.sh — remove all monorepo dev containers, named volumes, and project networks.
#
# Handles Docker Compose v2 volume names (e.g. many_faces_main_seq-data, many_faces_elastic_elasticsearch-data;
# legacy mfai_demo_*), legacy short names, and leaves no known demo volumes behind when Docker allows removal.
#
# WARNING: Destructive (DB, Redis, Seq, FE/Admin node_modules caches, Elasticsearch + search-worker, push-worker, …).
# By default the AI gRPC service (ai-demo-dev) and its Hugging Face cache volume are left
# alone so models are not re-downloaded; use --clean-ai to remove them too.
# After containers/volumes are gone, unused Docker images are pruned; the ai-demo-dev image
# is kept unless you pass --clean-ai (base layers shared with other images may remain until
# unused).
#
# Usage: ./scripts/clear-all-dev.sh [--yes|-y] [--clean-ai]
#   --yes, -y   Skip the confirmation prompt (automation / CI).
#   --clean-ai  Also remove ai-demo-dev, ai-demo-hf-cache, and prune all unused images.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

AUTO_YES=0
CLEAN_AI=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes) AUTO_YES=1; shift ;;
    --clean-ai) CLEAN_AI=1; shift ;;
    -h | --help)
      echo "Usage: ./scripts/clear-all-dev.sh [--yes|-y] [--clean-ai]"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1 (try --help)"
      exit 1
      ;;
  esac
done

echo "🧹 Clearing development containers, volumes, networks, and (most) Docker images..."
echo ""
echo "⚠️  WARNING: This removes demo DB, Redis, Seq, BE/FE/Admin dev stack, logger, Elasticsearch/search-worker, push-worker, TLS smoke stacks, etc."
if [[ "$CLEAN_AI" -eq 1 ]]; then
  echo "   Including AI demo and Hugging Face cache (--clean-ai)."
else
  echo "   AI demo (ai-demo-dev) and HF model cache are kept unless you pass --clean-ai."
fi
echo ""

if [[ "$AUTO_YES" -eq 1 ]]; then
  REPLY=yes
else
  read -p "Are you sure you want to continue? (yes/no): " -r
  echo ""
fi

if [[ ! ${REPLY:-} =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "❌ Aborted"
  exit 1
fi

echo "🧹 Starting cleanup..."
echo ""

# -----------------------------------------------------------------------------
# docker compose (v2) with fallback to docker-compose (v1)
# -----------------------------------------------------------------------------
compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

# -----------------------------------------------------------------------------
# Phase 1 — Stop each stack with declared volumes (correct working directory / project)
# Order: logger (external net) → root stack → DB → Redis → elastic + push (optional stacks) → per-app local composes
# -----------------------------------------------------------------------------
echo "  📦 Phase 1: docker compose down -v (per stack)"

if [ -f many_faces_logger/docker-compose.dev.yml ]; then
  (cd "$ROOT/many_faces_logger" && compose -f docker-compose.dev.yml down --remove-orphans 2>/dev/null) || true
fi

if [ -f docker-compose.dev.yml ]; then
  if [[ "$CLEAN_AI" -eq 1 ]]; then
    (cd "$ROOT" && compose -f docker-compose.dev.yml down -v --remove-orphans 2>/dev/null) || true
  else
    # Leave ai-demo-dev and ai-demo-hf-cache; drop BE/Seq/FE/proxy/Admin only.
    (cd "$ROOT" && compose -f docker-compose.dev.yml stop fe-demo-proxy fe-demo-dev admin-demo-dev be-demo-dev seq 2>/dev/null) || true
    (cd "$ROOT" && compose -f docker-compose.dev.yml rm -f fe-demo-proxy fe-demo-dev admin-demo-dev be-demo-dev seq 2>/dev/null) || true
  fi
fi

if [ -f many_faces_database/docker-compose.yml ]; then
  (cd "$ROOT/many_faces_database" && compose down -v --remove-orphans 2>/dev/null) || true
fi

if [ -f many_faces_redis/docker-compose.yml ]; then
  (cd "$ROOT/many_faces_redis" && compose down -v --remove-orphans 2>/dev/null) || true
fi

# Elasticsearch + Go search-worker (optional dev stack; named volume elasticsearch-data).
if [ -f many_faces_elastic/docker-compose.yml ]; then
  (cd "$ROOT/many_faces_elastic" && compose -f docker-compose.yml down -v --remove-orphans 2>/dev/null) || true
fi
# TLS/mTLS smoke compose (same project names as CI smoke scripts).
if [ -f many_faces_elastic/docker-compose.tls-smoke.yml ]; then
  (cd "$ROOT/many_faces_elastic" && compose -f docker-compose.tls-smoke.yml -p mf-search-tls-smoke down -v --remove-orphans 2>/dev/null) || true
fi

# FCM push worker (optional dev stack; no named volumes in base compose).
if [ -f many_faces_push/docker-compose.yml ]; then
  (cd "$ROOT/many_faces_push" && compose -f docker-compose.yml down --remove-orphans 2>/dev/null) || true
fi
if [ -f many_faces_push/docker-compose.tls-smoke.yml ]; then
  (cd "$ROOT/many_faces_push" && compose -f docker-compose.tls-smoke.yml -p mf-push-tls-smoke down -v --remove-orphans 2>/dev/null) || true
fi

if [ -f many_faces_backend/docker-compose.dev.yml ]; then
  (cd "$ROOT/many_faces_backend" && compose -f docker-compose.dev.yml down -v --remove-orphans 2>/dev/null) || true
fi

if [ -f many_faces_portal/docker-compose.yml ]; then
  (cd "$ROOT/many_faces_portal" && compose -f docker-compose.yml down -v --remove-orphans 2>/dev/null) || true
fi

if [ -f many_faces_admin/docker-compose.yml ]; then
  (cd "$ROOT/many_faces_admin" && compose -f docker-compose.yml down -v --remove-orphans 2>/dev/null) || true
fi

# -----------------------------------------------------------------------------
# Phase 2 — Force-remove containers by name (stopped / orphaned / renamed)
# -----------------------------------------------------------------------------
echo "  📦 Phase 2: force-remove dev containers by name"

_AI_RM=(be-demo-dev be-demo-seq be-demo-api fe-demo-dev fe-demo-proxy fe-demo-prod admin-demo-dev admin-demo-prod seq seq-dev postgres-dev pgadmin-dev redis-dev dozzle-dev elasticsearch-dev search-worker-dev push-worker-dev elasticsearch-tls-smoke search-worker-tls-smoke push-worker-tls-smoke)
if [[ "$CLEAN_AI" -eq 1 ]]; then
  _AI_RM+=(ai-demo-dev)
fi
# shellcheck disable=SC2086
docker rm -f "${_AI_RM[@]}" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Phase 3 — Remove project networks (explicit names from compose + Compose defaults)
# -----------------------------------------------------------------------------
echo "  📦 Phase 3: remove project networks"

for net in \
  many_faces_database_db-network \
  many_faces_redis_redis-network \
  many_faces_backend_be-demo-network \
  many_faces_portal_fe-demo-network \
  many_faces_admin_admin-demo-network \
  many_faces_elastic_elastic-network \
  many_faces_push_default \
  mf-search-tls-smoke_tls-smoke-net \
  mf-push-tls-smoke_tls-smoke-net \
  db_demo_db-network \
  redis_demo_redis-network \
  be_demo_be-demo-network \
  fe_demo_fe-demo-network \
  admin_demo_admin-demo-network; do
  docker network rm "$net" 2>/dev/null || true
done
# Root dev network: ai-demo-dev stays attached unless --clean-ai or container absent.
if [[ "$CLEAN_AI" -eq 1 ]] || ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'ai-demo-dev'; then
  docker network rm many_faces_main_dev-network 2>/dev/null || true
  docker network rm mfai_demo_dev-network 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Phase 4 — Legacy short volume names (Compose v1 / manual)
# -----------------------------------------------------------------------------
echo "  📦 Phase 4: remove legacy (unprefixed) volume names"

_LEGACY_VOLUMES=(be-demo-https be-demo-data seq-data fe-demo-node-modules fe-demo-yarn-cache admin-demo-node-modules admin-demo-yarn-cache postgres-data pgadmin-data redis-data)
if [[ "$CLEAN_AI" -eq 1 ]]; then
  _LEGACY_VOLUMES+=(ai-demo-hf-cache)
fi
for vol in "${_LEGACY_VOLUMES[@]}"; do
  docker volume rm -f "$vol" 2>/dev/null || true
done

# -----------------------------------------------------------------------------
# Phase 5 — Compose v2 prefixed volumes (project_volume)
# -----------------------------------------------------------------------------
echo "  📦 Phase 5: remove Compose v2–prefixed volumes (many_faces_* + legacy *_demo_* / mfai_demo_ / many_faces_main_)"

remove_prefixed_volumes() {
  # grep can exit 1 when no volumes match — must not trip set -e
  local candidates
  candidates=$(docker volume ls -q 2>/dev/null | grep -E '^(mfai_demo_|many_faces_main_|many_faces_database_|many_faces_redis_|many_faces_logger_|many_faces_backend_|many_faces_portal_|many_faces_admin_|many_faces_ai_|many_faces_elastic_|many_faces_push_|mf-search-tls-smoke_|mf-push-tls-smoke_|db_demo_|redis_demo_|logger_demo_|be_demo_|fe_demo_|admin_demo_|ai_demo_)' || true)
  [[ -z "$candidates" ]] && return 0
  if [[ "$CLEAN_AI" -ne 1 ]]; then
    candidates=$(echo "$candidates" | grep -vF 'ai-demo-hf-cache' | grep -vE '^many_faces_ai_' || true)
  fi
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    docker volume rm -f "$vol" 2>/dev/null || true
  done <<<"$candidates"
}

remove_prefixed_volumes
sleep 1
remove_prefixed_volumes

# -----------------------------------------------------------------------------
# Phase 6 — Host processes (non-Docker Vite / dotnet dev)
# -----------------------------------------------------------------------------
echo "  📦 Phase 6: stop stray host dev processes (if any)"

pkill -f "vite.*8081" 2>/dev/null || true
pkill -f "vite.*8082" 2>/dev/null || true
pkill -f "dotnet.*BeDemo" 2>/dev/null || true

sleep 2

echo ""
echo "✅ Cleanup phases finished"
echo ""

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------
echo "🔍 Verifying cleanup..."
echo ""

_CONTAINER_RE='^(be-demo-dev|fe-demo-dev|fe-demo-proxy|admin-demo-dev|postgres-dev|pgadmin-dev|redis-dev|seq-dev|dozzle-dev|be-demo-seq|be-demo-api|elasticsearch-dev|search-worker-dev|push-worker-dev|elasticsearch-tls-smoke|search-worker-tls-smoke|push-worker-tls-smoke)$'
if [[ "$CLEAN_AI" -eq 1 ]]; then
  _CONTAINER_RE='^(be-demo-dev|fe-demo-dev|fe-demo-proxy|admin-demo-dev|ai-demo-dev|postgres-dev|pgadmin-dev|redis-dev|seq-dev|dozzle-dev|be-demo-seq|be-demo-api|elasticsearch-dev|search-worker-dev|push-worker-dev|elasticsearch-tls-smoke|search-worker-tls-smoke|push-worker-tls-smoke)$'
fi

BAD_CONTAINERS=$(
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E "$_CONTAINER_RE" || true
)

if [[ -z "$BAD_CONTAINERS" ]]; then
  if [[ "$CLEAN_AI" -eq 1 ]]; then
    echo "✅ No known demo containers remain"
  else
    echo "✅ Stack containers cleared (ai-demo-dev left running if it existed)"
  fi
else
  echo "⚠️  Retrying force-remove on remaining demo containers..."
  # shellcheck disable=SC2086
  docker rm -f $BAD_CONTAINERS 2>/dev/null || true
  sleep 1
  BAD_CONTAINERS=$(
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E "$_CONTAINER_RE" || true
  )
  if [[ -n "$BAD_CONTAINERS" ]]; then
    echo "❌ Could not remove containers:"
    echo "$BAD_CONTAINERS"
    exit 1
  fi
  echo "✅ Demo containers removed on retry"
fi

_BAD_VOL_GREP='^(mfai_demo_|many_faces_main_|many_faces_database_|many_faces_redis_|many_faces_logger_|many_faces_backend_|many_faces_portal_|many_faces_admin_|many_faces_ai_|many_faces_elastic_|many_faces_push_|mf-search-tls-smoke_|mf-push-tls-smoke_|db_demo_|redis_demo_|logger_demo_|be_demo_|fe_demo_|admin_demo_|ai_demo_)'
BAD_VOLUMES_RAW=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E "$_BAD_VOL_GREP" || true)
if [[ "$CLEAN_AI" -eq 1 ]]; then
  BAD_VOLUMES=$BAD_VOLUMES_RAW
else
  BAD_VOLUMES=$(echo "$BAD_VOLUMES_RAW" | grep -vF 'ai-demo-hf-cache' | grep -vE '^many_faces_ai_' || true)
fi

_LEGACY_GREP='^(be-demo-https|be-demo-data|seq-data|fe-demo-node-modules|fe-demo-yarn-cache|admin-demo-node-modules|admin-demo-yarn-cache|ai-demo-hf-cache|postgres-data|pgadmin-data|redis-data)$'
LEGACY_RAW=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E "$_LEGACY_GREP" || true)
if [[ "$CLEAN_AI" -eq 1 ]]; then
  LEGACY_LEFT=$LEGACY_RAW
else
  LEGACY_LEFT=$(echo "$LEGACY_RAW" | grep -vF 'ai-demo-hf-cache' || true)
fi

if [[ -z "$BAD_VOLUMES" && -z "$LEGACY_LEFT" ]]; then
  echo "✅ No known demo volumes remain"
else
  if [[ -n "$BAD_VOLUMES" ]]; then
    echo "⚠️  Prefixed volumes still present:"
    echo "$BAD_VOLUMES"
    while IFS= read -r v; do
      [[ -z "$v" ]] && continue
      docker volume rm -f "$v" 2>/dev/null || true
    done <<<"$BAD_VOLUMES"
  fi
  if [[ -n "$LEGACY_LEFT" ]]; then
    echo "⚠️  Legacy volumes still present:"
    echo "$LEGACY_LEFT"
    while IFS= read -r v; do
      [[ -z "$v" ]] && continue
      docker volume rm -f "$v" 2>/dev/null || true
    done <<<"$LEGACY_LEFT"
  fi
fi

_NET_GREP='^(many_faces_main_dev-network|mfai_demo_dev-network|many_faces_database_db-network|many_faces_redis_redis-network|many_faces_backend_be-demo-network|many_faces_portal_fe-demo-network|many_faces_admin_admin-demo-network|many_faces_elastic_elastic-network|many_faces_push_default|mf-search-tls-smoke_tls-smoke-net|mf-push-tls-smoke_tls-smoke-net|db_demo_db-network|redis_demo_redis-network|be_demo_be-demo-network|fe_demo_fe-demo-network|admin_demo_admin-demo-network)$'
BAD_NETS_RAW=$(docker network ls --format '{{.Name}}' 2>/dev/null | grep -E "$_NET_GREP" || true)
if [[ "$CLEAN_AI" -eq 1 ]] || ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'ai-demo-dev'; then
  BAD_NETS=$BAD_NETS_RAW
else
  BAD_NETS=$(echo "$BAD_NETS_RAW" | grep -vE '^(many_faces_main_dev-network|mfai_demo_dev-network)$' || true)
fi

if [[ -z "$BAD_NETS" ]]; then
  echo "✅ No blocking demo networks remain (many_faces_main_dev-network or legacy mfai_demo_dev-network may stay for AI)"
else
  echo "⚠️  Networks still present (remove after containers are gone):"
  echo "$BAD_NETS"
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    docker network rm "$n" 2>/dev/null || true
  done <<<"$BAD_NETS"
fi

# Final pass: prefixed volumes (race with daemon)
remove_prefixed_volumes
sleep 1

STILL_PREFIXED_RAW=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E "$_BAD_VOL_GREP" || true)
if [[ "$CLEAN_AI" -eq 1 ]]; then
  STILL_PREFIXED=$STILL_PREFIXED_RAW
else
  STILL_PREFIXED=$(echo "$STILL_PREFIXED_RAW" | grep -vF 'ai-demo-hf-cache' | grep -vE '^many_faces_ai_' || true)
fi
STILL_LEGACY_RAW=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -E "$_LEGACY_GREP" || true)
if [[ "$CLEAN_AI" -eq 1 ]]; then
  STILL_LEGACY=$STILL_LEGACY_RAW
else
  STILL_LEGACY=$(echo "$STILL_LEGACY_RAW" | grep -vF 'ai-demo-hf-cache' || true)
fi

if [[ -n "$STILL_PREFIXED" || -n "$STILL_LEGACY" ]]; then
  echo ""
  echo "❌ Demo volumes still exist after cleanup (another container may reference them):"
  [[ -n "$STILL_PREFIXED" ]] && echo "$STILL_PREFIXED"
  [[ -n "$STILL_LEGACY" ]] && echo "$STILL_LEGACY"
  echo "💡 Inspect: docker ps -a   then   docker volume rm -f <name>"
  exit 1
fi

# -----------------------------------------------------------------------------
# Phase 7 — Prune unused images (keep ai-demo-dev image unless --clean-ai)
# -----------------------------------------------------------------------------
echo ""
echo "  📦 Phase 7: prune unused Docker images"

if [[ "$CLEAN_AI" -eq 1 ]]; then
  docker image prune -a -f 2>/dev/null || true
  echo "  ✅ All unused images pruned (--clean-ai)"
else
  KEEP_FILE=$(mktemp)
  if [[ -f "$ROOT/docker-compose.dev.yml" ]]; then
    while IFS= read -r _img; do
      [[ -z "$_img" ]] && continue
      docker inspect -f '{{.Id}}' "$_img" 2>/dev/null >>"$KEEP_FILE" || true
    done < <(cd "$ROOT" && compose -f docker-compose.dev.yml images -q ai-demo-dev 2>/dev/null || true)
  fi
  if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'ai-demo-dev'; then
    _aiimg=$(docker inspect -f '{{.Image}}' ai-demo-dev 2>/dev/null || true)
    if [[ -n "$_aiimg" ]]; then
      docker inspect -f '{{.Id}}' "$_aiimg" 2>/dev/null >>"$KEEP_FILE" || true
    fi
  fi
  # compose `images -q` is often empty when no container exists; keep any tagged *ai-demo-dev* image.
  while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    _rid="${_line##* }"
    [[ -z "$_rid" ]] && continue
    docker inspect -f '{{.Id}}' "$_rid" 2>/dev/null >>"$KEEP_FILE" || true
  done < <(docker images --format '{{.Repository}} {{.ID}}' 2>/dev/null | grep -i 'ai-demo-dev' || true)
  sort -u "$KEEP_FILE" -o "$KEEP_FILE"

  while IFS= read -r _id; do
    [[ -z "$_id" ]] && continue
    _full=$(docker inspect -f '{{.Id}}' "$_id" 2>/dev/null) || continue
    _base="${_full#sha256:}"
    if grep -Fxq "$_full" "$KEEP_FILE" 2>/dev/null || grep -Fxq "sha256:$_base" "$KEEP_FILE" 2>/dev/null || grep -Fxq "$_base" "$KEEP_FILE" 2>/dev/null; then
      continue
    fi
    docker rmi -f "$_id" 2>/dev/null || true
  done < <(docker images -q --no-trunc 2>/dev/null || true)

  rm -f "$KEEP_FILE"
  docker image prune -f 2>/dev/null || true
  echo "  ✅ Unused images pruned (ai-demo-dev image kept)"
fi

echo ""
if [[ "$CLEAN_AI" -eq 1 ]]; then
  echo "🎉 Cleanup complete — no known demo volumes or networks left; unused images pruned."
else
  echo "🎉 Cleanup complete — AI demo / HF cache / ai-demo image kept (use --clean-ai to remove)."
fi
