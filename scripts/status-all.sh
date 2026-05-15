#!/bin/bash

# status-all.sh - Script to check status of all containers and applications
# 
# This script provides a comprehensive status overview of all development services:
# - Database (PostgreSQL) - checks container status and database accessibility
# - pgAdmin - checks container status and UI accessibility
# - Backend API (ASP.NET Core) - checks container status and API accessibility
# - Frontend (React + Vite) - checks container status and app accessibility
# - Admin (React + Vite) - checks container status and app accessibility
# - Many Faces AI service (Python gRPC) - checks container status
# - Many Faces log viewer (Dozzle) - checks container status and UI accessibility
# - Seq Logging Server - checks container status and UI accessibility
# - Optional: Elasticsearch (HTTP), search-worker, push-worker, mailer-worker (gRPC host ports; skipped when containers absent)
# 
# The script distinguishes between:
# - Running containers (✓ Running)
# - Stopped containers (⚠ Stopped)
# - Removed containers (○ Not found)
# 
# It also performs health checks by attempting to connect to each service.
# 
# Usage: ./scripts/status-all.sh (from repository root)

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
# This allows the script to be run from any directory
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

# ANSI color codes for terminal output
# These colors are used to make the output more readable and visually distinct
GREEN='\033[0;32m'    # Green - for success/running status
RED='\033[0;31m'      # Red - for errors/failed status
YELLOW='\033[1;33m'   # Yellow - for warnings/stopped status
BLUE='\033[0;34m'     # Blue - for informational/not found status
CYAN='\033[0;36m'     # Cyan - for additional info (not used in this script)
NC='\033[0m'          # No Color - reset to default terminal color

echo "═══════════════════════════════════════════════════════════"
echo "  Container & Application Status"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Function to check if container exists (running or stopped)
# 
# Uses 'docker ps -a' to check all containers (including stopped ones).
# Returns 0 (success) if container exists, 1 (failure) if it doesn't.
# 
# @param container_name - Name of the container to check
# @return 0 if container exists, 1 if it doesn't
check_container_exists() {
    local container_name=$1
    # List all containers (running and stopped) and check if name matches
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0  # Container exists
    else
        return 1  # Container doesn't exist
    fi
}

# Function to check if container is currently running
# 
# Uses 'docker ps' to check only running containers.
# Returns 0 (success) if container is running, 1 (failure) if it's not.
# 
# @param container_name - Name of the container to check
# @return 0 if container is running, 1 if it's not
check_container() {
    local container_name=$1
    # List only running containers and check if name matches
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0  # Container is running
    else
        return 1  # Container is not running
    fi
}

# Function to check if service is accessible via HTTP
# 
# Performs a health check by attempting to connect to the service URL.
# Uses curl with a short timeout (2 seconds) to avoid hanging.
# 
# @param url - URL to check (e.g., http://localhost:8000/swagger)
# @param name - Name of the service (for logging, not used in this function)
# @return 0 if service is accessible, 1 if it's not
check_service() {
    local url=$1
    local name=$2
    # HTTPS dev servers use self-signed / mkcert; use -k for https:// URLs.
    if [[ "$url" == https://* ]]; then
        if curl -sk -f -o /dev/null --max-time 8 "$url" > /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
    if curl -s -f -o /dev/null --max-time 2 "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Docker FE: fe-demo-proxy on 9081 (HTTPS) and 9080 (HTTP to browser). Wait page marker until Vite is up.
fe_docker_vite_ready() {
    local body=""
    body=$(curl -sk --max-time 8 "https://localhost:9081/" 2>/dev/null) || true
    if echo "$body" | grep -qF '<!-- many-faces-fe-docker-wait-page -->' || [[ -z "$body" ]]; then
        body=$(curl -s --max-time 8 "http://localhost:9080/" 2>/dev/null) || true
    fi
    if echo "$body" | grep -qF '<!-- many-faces-fe-docker-wait-page -->'; then
        return 1
    fi
    [[ -n "$body" ]] || return 1
    return 0
}

# Function to get container status and start time
# 
# Retrieves container status (running, stopped, etc.) and start time from Docker.
# Returns status and uptime separated by pipe (|) for easy parsing.
# 
# @param container_name - Name of the container to inspect
# @return String in format "status|uptime" (e.g., "running|2026-01-17 18:41:31")
get_container_status() {
    local container_name=$1
    if check_container_exists "$container_name"; then
        # Get container status (running, stopped, created, etc.)
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        # Get container start time from Docker
        local started_at=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null || echo "")
        if [ -n "$started_at" ] && [ "$started_at" != "<no value>" ]; then
            # Extract just the date and time part (YYYY-MM-DD HH:MM:SS)
            # Docker returns ISO 8601 format (2026-01-17T18:41:31.123456789Z)
            # We extract everything before the dot and replace T with space
            local uptime=$(echo "$started_at" | cut -d'.' -f1 | sed 's/T/ /' || echo "$started_at")
        else
            local uptime="unknown"
        fi
        # Return status and uptime separated by pipe for easy parsing
        echo "$status|$uptime"
    else
        # Container doesn't exist
        echo "not found|never"
    fi
}

# ============================================================================
# CHECK DATABASE (many_faces_database)
# ============================================================================

echo "📦 Database (PostgreSQL)"
echo "───────────────────────────────────────────────────────────"

DB_CONTAINER="postgres-dev"
if check_container_exists "$DB_CONTAINER"; then
    if check_container "$DB_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$DB_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($DB_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if PostgreSQL is accessible
        if docker exec "$DB_CONTAINER" pg_isready -U bedemo_user -d bedemo > /dev/null 2>&1; then
            echo -e "  Database: ${GREEN}✓ Accessible${NC}"
        else
            echo -e "  Database: ${YELLOW}⚠ Not ready${NC}"
        fi
    else
        STATUS_INFO=$(get_container_status "$DB_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($DB_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
    fi
    echo "  Port: 54320 (localhost)"
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($DB_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 54320 (localhost)"
fi

echo ""

# ============================================================================
# CHECK REDIS (many_faces_redis)
# ============================================================================

echo "📦 Redis (many_faces_redis)"
echo "───────────────────────────────────────────────────────────"

REDIS_CONTAINER="redis-dev"
if check_container_exists "$REDIS_CONTAINER"; then
    if check_container "$REDIS_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$REDIS_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

        echo -e "  Container: ${GREEN}✓ Running${NC} ($REDIS_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"

        if docker exec "$REDIS_CONTAINER" redis-cli ping 2>/dev/null | grep -q PONG; then
            echo -e "  Redis: ${GREEN}✓ PING OK${NC}"
        else
            echo -e "  Redis: ${YELLOW}⚠ Not responding${NC}"
        fi
    else
        STATUS_INFO=$(get_container_status "$REDIS_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($REDIS_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
    fi
    echo "  Port: 6379 (localhost)"
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($REDIS_CONTAINER)"
    echo "  Status: Does not exist (run many_faces_redis/scripts/start-redis.sh)"
    echo "  Port: 6379 (localhost)"
fi

echo ""

# ============================================================================
# CHECK PGADMIN
# ============================================================================

echo "📦 pgAdmin (PostgreSQL Admin UI)"
echo "───────────────────────────────────────────────────────────"

PGADMIN_CONTAINER="pgadmin-dev"
if check_container_exists "$PGADMIN_CONTAINER"; then
    if check_container "$PGADMIN_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$PGADMIN_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($PGADMIN_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if pgAdmin is accessible
        if check_service "http://localhost:5050" "pgAdmin"; then
            echo -e "  UI: ${GREEN}✓ Accessible${NC} (http://localhost:5050)"
        else
            echo -e "  UI: ${YELLOW}⚠ Not accessible${NC} (http://localhost:5050)"
        fi
    else
        STATUS_INFO=$(get_container_status "$PGADMIN_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($PGADMIN_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 5050 (http://localhost:5050)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($PGADMIN_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 5050 (http://localhost:5050)"
fi

echo ""

# ============================================================================
# CHECK BACKEND (many_faces_backend)
# ============================================================================

echo "📦 Backend API (many_faces_backend)"
echo "───────────────────────────────────────────────────────────"

BE_CONTAINER="be-demo-dev"
if check_container_exists "$BE_CONTAINER"; then
    if check_container "$BE_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$BE_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($BE_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if API is accessible
        if check_service "http://localhost:8000/swagger/index.html" "Backend API"; then
            echo -e "  API: ${GREEN}✓ Accessible${NC} (http://localhost:8000)"
            echo "  Swagger: http://localhost:8000/swagger/index.html"
        else
            echo -e "  API: ${YELLOW}⚠ Not accessible${NC} (http://localhost:8000)"
        fi
    else
        STATUS_INFO=$(get_container_status "$BE_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($BE_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 8000 (http://localhost:8000)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($BE_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 8000 (http://localhost:8000)"
fi

echo ""

# ============================================================================
# CHECK FRONTEND (many_faces_portal)
# ============================================================================

echo "📦 Frontend (many_faces_portal)"
echo "───────────────────────────────────────────────────────────"

FE_CONTAINER="fe-demo-dev"
FE_ACCESSIBLE=false
if check_container_exists "$FE_CONTAINER"; then
    if check_container "$FE_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$FE_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($FE_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if frontend is accessible (not the nginx auto-refresh wait page)
        if fe_docker_vite_ready; then
            echo -e "  App: ${GREEN}✓ Accessible${NC} (https://localhost:9081 alebo http://localhost:9080 — Docker, Vite)"
            FE_ACCESSIBLE=true
        elif curl -sk --max-time 8 "https://localhost:9081/" 2>/dev/null | grep -qF '<!-- many-faces-fe-docker-wait-page -->' \
            || curl -s --max-time 8 "http://localhost:9080/" 2>/dev/null | grep -qF '<!-- many-faces-fe-docker-wait-page -->'; then
            echo -e "  App: ${YELLOW}⏳ Čaká sa na Vite${NC} (9081/9080 — obnovuje sa samo)"
        else
            echo -e "  App: ${YELLOW}⚠ Not accessible${NC} (https://localhost:9081 / http://localhost:9080)"
        fi
    else
        STATUS_INFO=$(get_container_status "$FE_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($FE_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # FE can run locally (yarn dev) - check port 8081 regardless of container
        if check_service "https://localhost:8081/" "Frontend"; then
            echo -e "  App: ${GREEN}✓ Accessible${NC} (https://localhost:8081) [running locally]"
            FE_ACCESSIBLE=true
        else
            echo "  Port: 8081 (https://localhost:8081 when using yarn dev)"
        fi
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($FE_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    # Still check if FE runs locally
    if check_service "https://localhost:8081/" "Frontend"; then
        echo -e "  App: ${GREEN}✓ Accessible${NC} (https://localhost:8081) [running locally]"
        FE_ACCESSIBLE=true
    else
        echo "  Port: 8081 (https://localhost:8081 when using yarn dev)"
    fi
fi

echo ""

# ============================================================================
# CHECK ADMIN (many_faces_admin)
# ============================================================================

echo "📦 Admin (many_faces_admin)"
echo "───────────────────────────────────────────────────────────"

ADMIN_CONTAINER="admin-demo-dev"
if check_container_exists "$ADMIN_CONTAINER"; then
    if check_container "$ADMIN_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$ADMIN_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($ADMIN_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if admin is accessible
        if check_service "https://localhost:8082/" "Admin"; then
            echo -e "  App: ${GREEN}✓ Accessible${NC} (https://localhost:8082)"
        else
            echo -e "  App: ${YELLOW}⚠ Not accessible${NC} (https://localhost:8082)"
        fi
    else
        STATUS_INFO=$(get_container_status "$ADMIN_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($ADMIN_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 8082 (https://localhost:8082)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($ADMIN_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 8082 (https://localhost:8082)"
fi

echo ""

# ============================================================================
# CHECK SEQ (Logging)
# ============================================================================

echo "📦 Seq Logging Server"
echo "───────────────────────────────────────────────────────────"

SEQ_CONTAINER="seq-dev"
if check_container_exists "$SEQ_CONTAINER"; then
    if check_container "$SEQ_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$SEQ_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($SEQ_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if Seq is accessible
        if check_service "http://localhost:5341" "Seq"; then
            echo -e "  UI: ${GREEN}✓ Accessible${NC} (http://localhost:5341)"
        else
            echo -e "  UI: ${YELLOW}⚠ Not accessible${NC} (http://localhost:5341)"
        fi
    else
        STATUS_INFO=$(get_container_status "$SEQ_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($SEQ_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 5341 (http://localhost:5341)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($SEQ_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 5341 (http://localhost:5341)"
fi

echo ""

# ============================================================================
# CHECK AI SERVICE (many_faces_ai)
# ============================================================================

echo "📦 Many Faces AI service (many_faces_ai)"
echo "───────────────────────────────────────────────────────────"

AI_DEV_CONTAINER="ai-demo-dev"
if check_container_exists "$AI_DEV_CONTAINER"; then
    if check_container "$AI_DEV_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$AI_DEV_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($AI_DEV_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Note: gRPC health check requires gRPC client, so we just check if container is running
        # In a full implementation, we would call the HealthCheck RPC method
        echo -e "  Service: ${GREEN}✓ Running${NC} (gRPC on port 50051)"
    else
        STATUS_INFO=$(get_container_status "$AI_DEV_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($AI_DEV_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 50051 (gRPC)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($AI_DEV_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 50051 (gRPC)"
fi

echo ""

# ============================================================================
# CHECK LOGGER (many_faces_logger)
# ============================================================================

echo "📦 Many Faces log viewer (many_faces_logger)"
echo "───────────────────────────────────────────────────────────"

DOZZLE_DEV_CONTAINER="dozzle-dev"
if check_container_exists "$DOZZLE_DEV_CONTAINER"; then
    if check_container "$DOZZLE_DEV_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$DOZZLE_DEV_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($DOZZLE_DEV_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if Many Faces log viewer (Dozzle) is accessible
        # Dozzle may return 404 on root, but container is running if we got here
        # The web UI is available at http://localhost:8080 even if root returns 404
        echo -e "  Service: ${GREEN}✓ Running${NC} (http://localhost:8080)"
    else
        STATUS_INFO=$(get_container_status "$DOZZLE_DEV_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($DOZZLE_DEV_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 8080 (http://localhost:8080)"
    fi
    else
        echo -e "  Container: ${BLUE}○ Not found${NC} ($DOZZLE_DEV_CONTAINER)"
        echo "  Status: Does not exist (removed)"
        echo "  Port: 8080 (http://localhost:8080)"
    fi

    echo ""

    # ============================================================================
    # OPTIONAL: ELASTICSEARCH + SEARCH WORKER (many_faces_elastic)
    # ============================================================================

    ES_CONTAINER="elasticsearch-dev"
    ES_HTTP_PORT="${ELASTIC_HTTP_HOST_PORT:-59200}"

    echo "📦 Elasticsearch (many_faces_elastic)"
    echo "───────────────────────────────────────────────────────────"

    if check_container_exists "$ES_CONTAINER"; then
        if check_container "$ES_CONTAINER"; then
            STATUS_INFO=$(get_container_status "$ES_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${GREEN}✓ Running${NC} ($ES_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"

            if check_service "http://localhost:${ES_HTTP_PORT}" "Elasticsearch"; then
                echo -e "  HTTP: ${GREEN}✓ Accessible${NC} (http://localhost:${ES_HTTP_PORT})"
            else
                echo -e "  HTTP: ${YELLOW}⚠ Not accessible${NC} (http://localhost:${ES_HTTP_PORT})"
            fi
        else
            STATUS_INFO=$(get_container_status "$ES_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($ES_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"
            echo "  Port: ${ES_HTTP_PORT} (http://localhost:${ES_HTTP_PORT})"
        fi
    else
        echo -e "  Container: ${BLUE}○ Not found${NC} ($ES_CONTAINER)"
        echo "  Status: Not running — ./scripts/start-all-dev.sh starts this by default (ENABLE_ELASTICSEARCH=0 to skip)"
        echo "  Port: ${ES_HTTP_PORT} (http://localhost:${ES_HTTP_PORT})"
    fi

    echo ""

    SW_CONTAINER="search-worker-dev"
    SW_GRPC_PORT="${SEARCH_WORKER_GRPC_HOST_PORT:-59202}"

    echo "📦 Search worker gRPC (many_faces_elastic)"
    echo "───────────────────────────────────────────────────────────"

    if check_container_exists "$SW_CONTAINER"; then
        if check_container "$SW_CONTAINER"; then
            STATUS_INFO=$(get_container_status "$SW_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${GREEN}✓ Running${NC} ($SW_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"

            if nc -z localhost "$SW_GRPC_PORT" 2>/dev/null; then
                echo -e "  gRPC (host): ${GREEN}✓ Port open${NC} (localhost:${SW_GRPC_PORT})"
            else
                echo -e "  gRPC (host): ${YELLOW}⚠ Port closed${NC} (localhost:${SW_GRPC_PORT})"
            fi
        else
            STATUS_INFO=$(get_container_status "$SW_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($SW_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"
            echo "  Port: ${SW_GRPC_PORT} (localhost)"
        fi
    else
        echo -e "  Container: ${BLUE}○ Not found${NC} ($SW_CONTAINER)"
        echo "  Status: Optional — same as Elasticsearch stack"
        echo "  Port: ${SW_GRPC_PORT} (localhost)"
    fi

    echo ""

    PUSH_CONTAINER="push-worker-dev"
    PUSH_GRPC_PORT="${PUSH_WORKER_GRPC_HOST_PORT:-59203}"

    echo "📦 Push worker gRPC (many_faces_push)"
    echo "───────────────────────────────────────────────────────────"

    if check_container_exists "$PUSH_CONTAINER"; then
        if check_container "$PUSH_CONTAINER"; then
            STATUS_INFO=$(get_container_status "$PUSH_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${GREEN}✓ Running${NC} ($PUSH_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"

            if nc -z localhost "$PUSH_GRPC_PORT" 2>/dev/null; then
                echo -e "  gRPC (host): ${GREEN}✓ Port open${NC} (localhost:${PUSH_GRPC_PORT})"
            else
                echo -e "  gRPC (host): ${YELLOW}⚠ Port closed${NC} (localhost:${PUSH_GRPC_PORT})"
            fi
        else
            STATUS_INFO=$(get_container_status "$PUSH_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($PUSH_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"
            echo "  Port: ${PUSH_GRPC_PORT} (localhost)"
        fi
    else
        echo -e "  Container: ${BLUE}○ Not found${NC} ($PUSH_CONTAINER)"
        echo "  Status: Not running — ./scripts/start-all-dev.sh starts this by default (ENABLE_PUSH_WORKER=0 to skip)"
        echo "  Port: ${PUSH_GRPC_PORT} (localhost)"
    fi

    echo ""

    MAILER_W_CONTAINER="mailer-worker-dev"
    MAILER_GRPC_PORT="${MAILER_WORKER_GRPC_HOST_PORT:-59204}"

    echo "📦 Mailer worker gRPC (many_faces_mailer)"
    echo "───────────────────────────────────────────────────────────"

    if check_container_exists "$MAILER_W_CONTAINER"; then
        if check_container "$MAILER_W_CONTAINER"; then
            STATUS_INFO=$(get_container_status "$MAILER_W_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${GREEN}✓ Running${NC} ($MAILER_W_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"

            if nc -z localhost "$MAILER_GRPC_PORT" 2>/dev/null; then
                echo -e "  gRPC (host): ${GREEN}✓ Port open${NC} (localhost:${MAILER_GRPC_PORT})"
            else
                echo -e "  gRPC (host): ${YELLOW}⚠ Port closed${NC} (localhost:${MAILER_GRPC_PORT})"
            fi
        else
            STATUS_INFO=$(get_container_status "$MAILER_W_CONTAINER")
            STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
            UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)

            echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($MAILER_W_CONTAINER)"
            echo "  Status: $STATUS"
            echo "  Started: $UPTIME"
            echo "  Port: ${MAILER_GRPC_PORT} (localhost)"
        fi
    else
        echo -e "  Container: ${BLUE}○ Not found${NC} ($MAILER_W_CONTAINER)"
        echo "  Status: Not running — ./scripts/start-all-dev.sh starts this by default (ENABLE_MAILER_WORKER=0 to skip)"
        echo "  Port: ${MAILER_GRPC_PORT} (localhost)"
    fi

    echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""

RUNNING=0
STOPPED=0
ACCESSIBLE=0
NOT_ACCESSIBLE=0

CONTAINERS=("$DB_CONTAINER" "$PGADMIN_CONTAINER" "$BE_CONTAINER" "$FE_CONTAINER" "$ADMIN_CONTAINER" "$AI_DEV_CONTAINER" "$SEQ_CONTAINER" "$DOZZLE_DEV_CONTAINER" "elasticsearch-dev" "search-worker-dev" "push-worker-dev" "mailer-worker-dev")

NOT_FOUND=0
for container in "${CONTAINERS[@]}"; do
    if check_container_exists "$container"; then
        if check_container "$container"; then
            RUNNING=$((RUNNING + 1))
        else
            STOPPED=$((STOPPED + 1))
        fi
    else
        NOT_FOUND=$((NOT_FOUND + 1))
    fi
done

# Check service accessibility (only for running containers)
if check_container "$DB_CONTAINER"; then
    if docker exec "$DB_CONTAINER" pg_isready -U bedemo_user -d bedemo > /dev/null 2>&1; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

if check_container "$PGADMIN_CONTAINER"; then
    if check_service "http://localhost:5050" "pgAdmin"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

if check_container "$BE_CONTAINER"; then
    if check_service "http://localhost:8000/swagger/index.html" "Backend API"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

# FE: count as accessible if running in container OR locally on port 8081
if [ "$FE_ACCESSIBLE" = true ]; then
    ACCESSIBLE=$((ACCESSIBLE + 1))
elif check_container "$FE_CONTAINER"; then
    NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
fi

if check_container "$ADMIN_CONTAINER"; then
    if check_service "https://localhost:8082/" "Admin"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

if check_container "$SEQ_CONTAINER"; then
    if check_service "http://localhost:5341" "Seq"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

# Note: Many Faces AI service uses gRPC, not HTTP, so we count it as accessible if container is running
if check_container "$AI_DEV_CONTAINER"; then
    ACCESSIBLE=$((ACCESSIBLE + 1))
fi

# Check Many Faces log viewer (Dozzle) accessibility
# If container is running, Dozzle is accessible (web UI works even if root returns 404)
if check_container "$DOZZLE_DEV_CONTAINER"; then
    ACCESSIBLE=$((ACCESSIBLE + 1))
fi

# Optional Elasticsearch HTTP (host-mapped port)
_ES_HTTP_PORT="${ELASTIC_HTTP_HOST_PORT:-59200}"
if check_container "elasticsearch-dev"; then
    if check_service "http://localhost:${_ES_HTTP_PORT}" "Elasticsearch"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

_SW_GRPC_PORT="${SEARCH_WORKER_GRPC_HOST_PORT:-59202}"
if check_container "search-worker-dev"; then
    if nc -z localhost "$_SW_GRPC_PORT" 2>/dev/null; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

_PUSH_GRPC_PORT="${PUSH_WORKER_GRPC_HOST_PORT:-59203}"
if check_container "push-worker-dev"; then
    if nc -z localhost "$_PUSH_GRPC_PORT" 2>/dev/null; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

_MAILER_GRPC_PORT="${MAILER_WORKER_GRPC_HOST_PORT:-59204}"
if check_container "mailer-worker-dev"; then
    if nc -z localhost "$_MAILER_GRPC_PORT" 2>/dev/null; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

if [ $NOT_FOUND -gt 0 ]; then
    echo -e "  Containers: ${GREEN}$RUNNING running${NC}, ${YELLOW}$STOPPED stopped${NC}, ${BLUE}$NOT_FOUND not found${NC}"
else
    echo -e "  Containers: ${GREEN}$RUNNING running${NC}, ${YELLOW}$STOPPED stopped${NC}"
fi
echo -e "  Services: ${GREEN}$ACCESSIBLE accessible${NC}, ${YELLOW}$NOT_ACCESSIBLE not accessible${NC}"
echo ""

# Quick links
echo "  Quick Links:"
if check_container "$BE_CONTAINER"; then
    echo "    • Backend API: http://localhost:8000"
    echo "    • Swagger: http://localhost:8000/swagger/index.html"
fi
if [ "$FE_ACCESSIBLE" = true ]; then
    echo "    • Frontend: https://localhost:9081 or http://localhost:9080 (Docker) — https://localhost:8081 (yarn dev on host)"
fi
if check_container "$ADMIN_CONTAINER"; then
    echo "    • Admin: https://localhost:8082"
fi
if check_container "$PGADMIN_CONTAINER"; then
    echo "    • pgAdmin: http://localhost:5050"
fi
if check_container "$SEQ_CONTAINER"; then
    echo "    • Seq Logs: http://localhost:5341"
fi
if check_container "elasticsearch-dev"; then
    echo "    • Elasticsearch: http://localhost:${ELASTIC_HTTP_HOST_PORT:-59200}"
fi
if check_container "search-worker-dev"; then
    echo "    • Search worker gRPC (host): localhost:${SEARCH_WORKER_GRPC_HOST_PORT:-59202}"
fi
if check_container "push-worker-dev"; then
    echo "    • Push worker gRPC (host): localhost:${PUSH_WORKER_GRPC_HOST_PORT:-59203}"
fi
if check_container "mailer-worker-dev"; then
    echo "    • Mailer worker gRPC (host): localhost:${MAILER_WORKER_GRPC_HOST_PORT:-59204}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
