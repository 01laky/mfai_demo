#!/bin/bash

# status-all.sh - Script to check status of all containers and applications
# 
# This script provides a comprehensive status overview of all development services:
# - Database (PostgreSQL) - checks container status and database accessibility
# - pgAdmin - checks container status and UI accessibility
# - Backend API (ASP.NET Core) - checks container status and API accessibility
# - Frontend (React + Vite) - checks container status and app accessibility
# - Admin (React + Vite) - checks container status and app accessibility
# - AI Demo (Python gRPC) - checks container status
# - Logger Demo (Dozzle) - checks container status and UI accessibility
# - Seq Logging Server - checks container status and UI accessibility
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

# Docker FE on 9081 goes through fe-demo-proxy: wait page contains this marker until Vite is up.
fe_docker_vite_ready() {
    local body
    body=$(curl -sk --max-time 8 "https://localhost:9081/" 2>/dev/null) || return 1
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
# CHECK DATABASE (db_demo)
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
# CHECK REDIS (redis_demo)
# ============================================================================

echo "📦 Redis (redis_demo)"
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
    echo "  Status: Does not exist (run redis_demo/start-redis.sh)"
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
# CHECK BACKEND (be_demo)
# ============================================================================

echo "📦 Backend API (be_demo)"
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
# CHECK FRONTEND (fe_demo)
# ============================================================================

echo "📦 Frontend (fe_demo)"
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
            echo -e "  App: ${GREEN}✓ Accessible${NC} (https://localhost:9081 — Docker, Vite)"
            FE_ACCESSIBLE=true
        elif curl -sk --max-time 8 "https://localhost:9081/" 2>/dev/null | grep -qF '<!-- many-faces-fe-docker-wait-page -->'; then
            echo -e "  App: ${YELLOW}⏳ Čaká sa na Vite${NC} (https://localhost:9081 — obnovuje sa samo)"
        else
            echo -e "  App: ${YELLOW}⚠ Not accessible${NC} (https://localhost:9081)"
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
# CHECK ADMIN (admin_demo)
# ============================================================================

echo "📦 Admin (admin_demo)"
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
# CHECK AI DEMO (ai_demo)
# ============================================================================

echo "📦 AI Demo (ai_demo)"
echo "───────────────────────────────────────────────────────────"

AI_DEMO_CONTAINER="ai-demo-dev"
if check_container_exists "$AI_DEMO_CONTAINER"; then
    if check_container "$AI_DEMO_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$AI_DEMO_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($AI_DEMO_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Note: gRPC health check requires gRPC client, so we just check if container is running
        # In a full implementation, we would call the HealthCheck RPC method
        echo -e "  Service: ${GREEN}✓ Running${NC} (gRPC on port 50051)"
    else
        STATUS_INFO=$(get_container_status "$AI_DEMO_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($AI_DEMO_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 50051 (gRPC)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($AI_DEMO_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 50051 (gRPC)"
fi

echo ""

# ============================================================================
# CHECK LOGGER DEMO (logger_demo)
# ============================================================================

echo "📦 Logger Demo (logger_demo)"
echo "───────────────────────────────────────────────────────────"

LOGGER_DEMO_CONTAINER="dozzle-dev"
if check_container_exists "$LOGGER_DEMO_CONTAINER"; then
    if check_container "$LOGGER_DEMO_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$LOGGER_DEMO_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($LOGGER_DEMO_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if Logger Demo (Dozzle) is accessible
        # Dozzle may return 404 on root, but container is running if we got here
        # The web UI is available at http://localhost:8080 even if root returns 404
        echo -e "  Service: ${GREEN}✓ Running${NC} (http://localhost:8080)"
    else
        STATUS_INFO=$(get_container_status "$LOGGER_DEMO_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($LOGGER_DEMO_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 8080 (http://localhost:8080)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($LOGGER_DEMO_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 8080 (http://localhost:8080)"
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

CONTAINERS=("$DB_CONTAINER" "$PGADMIN_CONTAINER" "$BE_CONTAINER" "$FE_CONTAINER" "$ADMIN_CONTAINER" "$AI_DEMO_CONTAINER" "$SEQ_CONTAINER" "$LOGGER_DEMO_CONTAINER")

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

# Note: AI Demo uses gRPC, not HTTP, so we count it as accessible if container is running
if check_container "$AI_DEMO_CONTAINER"; then
    ACCESSIBLE=$((ACCESSIBLE + 1))
fi

# Check Logger Demo (Dozzle) accessibility
# If container is running, Dozzle is accessible (web UI works even if root returns 404)
if check_container "$LOGGER_DEMO_CONTAINER"; then
    ACCESSIBLE=$((ACCESSIBLE + 1))
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
    echo "    • Frontend: https://localhost:9081 (Docker) or https://localhost:8081 (yarn dev on host)"
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
if check_container "$LOGGER_DEMO_CONTAINER"; then
    echo "    • Logger Demo (Dozzle): http://localhost:8080"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
