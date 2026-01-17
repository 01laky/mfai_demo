#!/bin/bash

# Script to check status of all containers and applications
# Checks: db_demo (PostgreSQL), be_demo (backend), fe_demo (frontend), admin_demo (admin), seq (logging)
# Usage: ./status-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════"
echo "  Container & Application Status"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Function to check if container exists (running or stopped)
check_container_exists() {
    local container_name=$1
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0
    else
        return 1
    fi
}

# Function to check if container is running
check_container() {
    local container_name=$1
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        return 0
    else
        return 1
    fi
}

# Function to check if service is accessible
check_service() {
    local url=$1
    local name=$2
    if curl -s -f -o /dev/null --max-time 2 "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get container status
get_container_status() {
    local container_name=$1
    if check_container_exists "$container_name"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        # Get started time - use docker's format directly
        local started_at=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null || echo "")
        if [ -n "$started_at" ] && [ "$started_at" != "<no value>" ]; then
            # Extract just the date and time part (YYYY-MM-DD HH:MM:SS)
            local uptime=$(echo "$started_at" | cut -d'.' -f1 | sed 's/T/ /' || echo "$started_at")
        else
            local uptime="unknown"
        fi
        echo "$status|$uptime"
    else
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
    echo "  Port: 5432 (localhost)"
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($DB_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 5432 (localhost)"
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
if check_container_exists "$FE_CONTAINER"; then
    if check_container "$FE_CONTAINER"; then
        STATUS_INFO=$(get_container_status "$FE_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${GREEN}✓ Running${NC} ($FE_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        
        # Check if frontend is accessible
        if check_service "http://localhost:8081" "Frontend"; then
            echo -e "  App: ${GREEN}✓ Accessible${NC} (http://localhost:8081)"
        else
            echo -e "  App: ${YELLOW}⚠ Not accessible${NC} (http://localhost:8081)"
        fi
    else
        STATUS_INFO=$(get_container_status "$FE_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($FE_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 8081 (http://localhost:8081)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($FE_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 8081 (http://localhost:8081)"
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
        if check_service "http://localhost:8082" "Admin"; then
            echo -e "  App: ${GREEN}✓ Accessible${NC} (http://localhost:8082)"
        else
            echo -e "  App: ${YELLOW}⚠ Not accessible${NC} (http://localhost:8082)"
        fi
    else
        STATUS_INFO=$(get_container_status "$ADMIN_CONTAINER")
        STATUS=$(echo "$STATUS_INFO" | cut -d'|' -f1)
        UPTIME=$(echo "$STATUS_INFO" | cut -d'|' -f2)
        
        echo -e "  Container: ${YELLOW}⚠ Stopped${NC} ($ADMIN_CONTAINER)"
        echo "  Status: $STATUS"
        echo "  Started: $UPTIME"
        echo "  Port: 8082 (http://localhost:8082)"
    fi
else
    echo -e "  Container: ${BLUE}○ Not found${NC} ($ADMIN_CONTAINER)"
    echo "  Status: Does not exist (removed)"
    echo "  Port: 8082 (http://localhost:8082)"
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

CONTAINERS=("$DB_CONTAINER" "$BE_CONTAINER" "$FE_CONTAINER" "$ADMIN_CONTAINER" "$SEQ_CONTAINER")

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

if check_container "$BE_CONTAINER"; then
    if check_service "http://localhost:8000/swagger/index.html" "Backend API"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

if check_container "$FE_CONTAINER"; then
    if check_service "http://localhost:8081" "Frontend"; then
        ACCESSIBLE=$((ACCESSIBLE + 1))
    else
        NOT_ACCESSIBLE=$((NOT_ACCESSIBLE + 1))
    fi
fi

if check_container "$ADMIN_CONTAINER"; then
    if check_service "http://localhost:8082" "Admin"; then
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
if check_container "$FE_CONTAINER"; then
    echo "    • Frontend: http://localhost:8081"
fi
if check_container "$ADMIN_CONTAINER"; then
    echo "    • Admin: http://localhost:8082"
fi
if check_container "$SEQ_CONTAINER"; then
    echo "    • Seq Logs: http://localhost:5341"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
