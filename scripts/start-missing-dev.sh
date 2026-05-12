#!/bin/bash
# Start only the dev containers that are not running.
# Use when status shows "Not found" for postgres, backend, admin, seq, pgadmin.
# Usage: ./scripts/start-missing-dev.sh (from repository root)

set -e
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

echo "🔍 Checking which containers are missing..."
MISSING=()

docker ps -a --format '{{.Names}}' | grep -q '^postgres-dev$' || MISSING+=(postgres)
docker ps -a --format '{{.Names}}' | grep -q '^redis-dev$' || MISSING+=(redis)
docker ps -a --format '{{.Names}}' | grep -q '^pgadmin-dev$' || MISSING+=(pgadmin)
docker ps -a --format '{{.Names}}' | grep -qE '^be-demo-dev$|^be-demo-api$' || MISSING+=(backend)
docker ps -a --format '{{.Names}}' | grep -q '^admin-demo-dev$' || MISSING+=(admin)
docker ps -a --format '{{.Names}}' | grep -q '^seq-dev$' || MISSING+=(seq)

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "✅ All required containers already exist. Starting any stopped ones..."
  docker start postgres-dev redis-dev pgadmin-dev 2>/dev/null || true
  docker start seq-dev be-demo-dev admin-demo-dev 2>/dev/null || true
  echo "Done. Run ./scripts/status-all.sh to check."
  exit 0
fi

echo "   Missing: ${MISSING[*]}"
echo ""

# 1. Database first (postgres + pgadmin)
if [[ " ${MISSING[*]} " =~ " postgres " ]] || [[ " ${MISSING[*]} " =~ " pgadmin " ]]; then
  echo "📦 Starting database (postgres + pgadmin)..."
  (cd many_faces_database && docker-compose up -d)
  echo "   Waiting for PostgreSQL to be ready..."
  for i in {1..30}; do
    if docker exec postgres-dev pg_isready -U bedemo_user -d bedemo 2>/dev/null; then
      echo "   ✅ PostgreSQL ready."
      break
    fi
    [ "$i" -eq 30 ] && { echo "   ❌ PostgreSQL did not become ready."; exit 1; }
    sleep 1
  done
  echo ""
fi

# 1b. Redis
if [[ " ${MISSING[*]} " =~ " redis " ]]; then
  echo "📦 Starting Redis (many_faces_redis)..."
  if [ -f "many_faces_redis/start-redis.sh" ]; then
    (cd many_faces_redis && ./start-redis.sh)
  else
    (cd many_faces_redis && docker-compose up -d)
  fi
  echo ""
fi

# 2. Seq (backend depends on it)
if [[ " ${MISSING[*]} " =~ " seq " ]]; then
  echo "📦 Starting Seq (seq-dev)..."
  docker-compose -f docker-compose.dev.yml up -d seq
  echo "   Waiting for Seq to be healthy..."
  for i in {1..60}; do
    if docker inspect seq-dev --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; then
      echo "   ✅ Seq ready."
      break
    fi
    [ "$i" -eq 60 ] && echo "   ⚠ Seq not healthy yet, continuing anyway."
    sleep 2
  done
  echo ""
fi

# 3. Backend (be-demo-dev)
if [[ " ${MISSING[*]} " =~ " backend " ]]; then
  echo "📦 Starting Backend (be-demo-dev)..."
  docker rm -f be-demo-seq be-demo-api 2>/dev/null || true
  docker-compose -f docker-compose.dev.yml up -d be-demo-dev
  echo "   Waiting for Backend to be healthy..."
  for i in {1..90}; do
    if docker inspect be-demo-dev --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; then
      echo "   ✅ Backend ready."
      break
    fi
    [ "$i" -eq 90 ] && echo "   ⚠ Backend not healthy yet, continuing anyway."
    sleep 2
  done
  echo ""
fi

# 4. Admin (depends on backend)
if [[ " ${MISSING[*]} " =~ " admin " ]]; then
  echo "📦 Starting Admin (admin-demo-dev)..."
  docker-compose -f docker-compose.dev.yml up -d admin-demo-dev
  echo "   ✅ Admin started."
  echo ""
fi

echo "✅ Missing services started. Run ./scripts/status-all.sh to verify."
