#!/bin/bash

# clear-all-dev.sh - Script to completely remove all development containers and volumes
# 
# This script performs a complete cleanup of all development infrastructure:
# - Stops and removes all Docker containers (database, backend, frontend, admin, seq, ai_demo, logger_demo)
# - Removes all Docker volumes (including database data - this is destructive!)
# - Removes Docker networks
# - Kills any remaining processes
# 
# WARNING: This script is DESTRUCTIVE and will permanently delete:
# - All database data (PostgreSQL volumes)
# - All application data
# - All container configurations
# 
# The script requires user confirmation before proceeding.
# 
# Usage: ./clear-all-dev.sh

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
# This allows the script to be run from any directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧹 Clearing all development containers and volumes..."
echo ""
echo "⚠️  WARNING: This will completely remove all containers and volumes!"
echo "   All data will be lost (including database data)!"
echo ""

# Request user confirmation before proceeding with destructive operations
# Only accepts "yes" (case-insensitive) as confirmation
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

# Validate user input - must be "yes" (case-insensitive)
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

echo "🧹 Starting cleanup..."
echo ""

# ============================================================================
# CLEAR ALL APPLICATIONS
# ============================================================================
# Remove containers and volumes for each application in the monorepo
# Each application has its own cleanup script, but we also provide fallback manual cleanup

# Clear backend (be_demo) - ASP.NET Core API and Seq logging server
if [ -f "be_demo/clear-dev.sh" ]; then
    # Use dedicated backend cleanup script if available
    echo "  📦 Clearing backend (be_demo)..."
    cd be_demo
    ./clear-dev.sh 2>/dev/null || true  # Suppress errors if script fails
    cd ..
else
    # Fallback: manually remove backend containers and volumes
    echo "  ⚠️  be_demo/clear-dev.sh not found, clearing manually..."
    # Stop and remove containers defined in docker-compose.dev.yml
    docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true
    # Force remove containers by name (in case they're not in docker-compose)
    docker rm -f be-demo-dev seq-dev 2>/dev/null || true
    # Remove volumes used by backend (HTTPS certificates, data)
    docker volume rm be-demo-https be-demo-data 2>/dev/null || true
fi

# Clear frontend (fe_demo) - React + Vite application
if [ -f "fe_demo/clear-dev.sh" ]; then
    # Use dedicated frontend cleanup script if available
    echo "  📦 Clearing frontend (fe_demo)..."
    cd fe_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    # Fallback: manually remove frontend containers and volumes
    echo "  ⚠️  fe_demo/clear-dev.sh not found, clearing manually..."
    # Stop and remove frontend container
    docker-compose -f docker-compose.dev.yml stop fe-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f fe-demo-dev 2>/dev/null || true
    # Force remove container by name
    docker rm -f fe-demo-dev 2>/dev/null || true
    # Remove volumes used by frontend (node_modules cache, yarn cache)
    docker volume rm fe-demo-node-modules fe-demo-yarn-cache 2>/dev/null || true
fi

# Clear admin (admin_demo) - React + Vite admin panel
if [ -f "admin_demo/clear-dev.sh" ]; then
    # Use dedicated admin cleanup script if available
    echo "  📦 Clearing admin (admin_demo)..."
    cd admin_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    # Fallback: manually remove admin containers and volumes
    echo "  ⚠️  admin_demo/clear-dev.sh not found, clearing manually..."
    # Stop and remove admin container
    docker-compose -f docker-compose.dev.yml stop admin-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f admin-demo-dev 2>/dev/null || true
    # Force remove container by name
    docker rm -f admin-demo-dev 2>/dev/null || true
    # Remove volumes used by admin (node_modules cache, yarn cache)
    docker volume rm admin-demo-node-modules admin-demo-yarn-cache 2>/dev/null || true
fi

# Clear AI Demo (ai_demo) - Python gRPC server
if [ -f "ai_demo/clear-dev.sh" ]; then
    # Use dedicated AI Demo cleanup script if available
    echo "  📦 Clearing AI Demo (ai_demo)..."
    cd ai_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    # Fallback: manually remove AI Demo containers
    echo "  ⚠️  ai_demo/clear-dev.sh not found, clearing manually..."
    # Stop and remove AI Demo container
    docker-compose -f docker-compose.dev.yml stop ai-demo-dev 2>/dev/null || true
    docker-compose -f docker-compose.dev.yml rm -f ai-demo-dev 2>/dev/null || true
    # Force remove container by name
    docker rm -f ai-demo-dev 2>/dev/null || true
fi

# Clear Logger Demo (logger_demo) - Dozzle log viewer
if [ -f "logger_demo/clear-dev.sh" ]; then
    # Use dedicated Logger Demo cleanup script if available
    echo "  📦 Clearing Logger Demo (logger_demo)..."
    cd logger_demo
    ./clear-dev.sh 2>/dev/null || true
    cd ..
else
    # Fallback: manually remove Logger Demo containers
    echo "  ⚠️  logger_demo/clear-dev.sh not found, clearing manually..."
    # Stop and remove Logger Demo container
    docker-compose -f logger_demo/docker-compose.dev.yml stop dozzle-dev 2>/dev/null || true
    docker-compose -f logger_demo/docker-compose.dev.yml rm -f dozzle-dev 2>/dev/null || true
    # Force remove container by name
    docker rm -f dozzle-dev 2>/dev/null || true
fi

# Clear database (db_demo) - PostgreSQL database
# WARNING: This removes all database data permanently!
if [ -f "db_demo/clear-db.sh" ]; then
    # Use dedicated database cleanup script if available
    echo "  📦 Clearing database (db_demo)..."
    cd db_demo
    ./clear-db.sh 2>/dev/null || true
    cd ..
else
    # Fallback: manually remove database container and volumes
    echo "  ⚠️  db_demo/clear-db.sh not found, clearing manually..."
    cd db_demo
    # Stop and remove database container and volumes
    docker-compose down -v 2>/dev/null || true
    # Force remove container by name
    docker rm -f postgres-dev 2>/dev/null || true
    # Remove database volume (contains all database data - this is destructive!)
    docker volume rm postgres-data 2>/dev/null || true
    cd ..
fi

# Clear all remaining containers from docker-compose.dev.yml
# This catches any containers that weren't removed by individual cleanup scripts
echo "  🧹 Clearing remaining containers from docker-compose.dev.yml..."
docker-compose -f docker-compose.dev.yml down -v 2>/dev/null || true

# Remove all containers by name (force removal)
# This ensures containers are removed even if they're in a stopped or error state
echo "  🧹 Removing containers by name..."
docker rm -f be-demo-dev fe-demo-dev admin-demo-dev ai-demo-dev postgres-dev seq-dev dozzle-dev 2>/dev/null || true
# Also remove any old containers with different names (from previous configurations)
# This handles containers that may have been created with different naming conventions
docker rm -f be-demo-seq be-demo-api seq 2>/dev/null || true

# Remove all volumes used by development environment
# WARNING: This permanently deletes all data stored in volumes!
echo "  🧹 Removing all volumes..."
# Backend volumes (HTTPS certificates, application data, Seq logs)
docker volume rm be-demo-https be-demo-data seq-data 2>/dev/null || true
# Frontend volumes (node_modules cache, yarn package cache)
docker volume rm fe-demo-node-modules fe-demo-yarn-cache 2>/dev/null || true
# Admin volumes (node_modules cache, yarn package cache)
docker volume rm admin-demo-node-modules admin-demo-yarn-cache 2>/dev/null || true
# Database volume (PostgreSQL data - all database content will be lost!)
docker volume rm postgres-data 2>/dev/null || true

# Remove Docker network used by development environment
# This network connects all containers together
echo "  🧹 Removing network..."
docker network rm dev-network 2>/dev/null || true

# Kill any remaining processes that might be running outside Docker
# This is a fallback for processes that weren't properly stopped
echo "  🧹 Cleaning up remaining processes..."
# Kill Vite dev servers (frontend on port 8081, admin on port 8082)
pkill -f "vite.*8081" 2>/dev/null || true
pkill -f "vite.*8082" 2>/dev/null || true
# Kill .NET backend processes
pkill -f "dotnet.*BeDemo" 2>/dev/null || true

# Wait a moment for Docker to finish cleanup operations
sleep 2

echo ""
echo "✅ All containers and volumes cleared"
echo ""

# ============================================================================
# VERIFY CLEANUP STATUS
# ============================================================================
# Verify that cleanup was successful by checking for remaining containers and volumes

echo "🔍 Verifying cleanup..."
echo ""

# Check if any development containers are still running or exist
# grep searches for container names matching our development containers
# Returns empty string if no containers found (cleanup successful)
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "be-demo-dev|fe-demo-dev|admin-demo-dev|ai-demo-dev|postgres-dev|seq-dev|dozzle-dev" || true)

if [ -z "$RUNNING_CONTAINERS" ]; then
    # No containers found - cleanup successful
    echo "✅ All containers removed"
else
    # Some containers still exist - provide instructions for manual removal
    echo "⚠️  Some containers are still running:"
    echo "$RUNNING_CONTAINERS"
    echo ""
    echo "💡 To force remove, run:"
    echo "   docker rm -f $RUNNING_CONTAINERS"
fi

# Check if any development volumes still exist
# grep searches for volume names matching our development volumes
# Returns empty string if no volumes found (cleanup successful)
REMAINING_VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "be-demo|fe-demo|admin-demo|postgres-data|seq-data" || true)

if [ -z "$REMAINING_VOLUMES" ]; then
    # No volumes found - cleanup successful
    echo "✅ All volumes removed"
else
    # Some volumes still exist - provide instructions for manual removal
    # Note: These volumes may contain data, so user should verify before removing
    echo "⚠️  Some volumes still exist:"
    echo "$REMAINING_VOLUMES"
    echo ""
    echo "💡 To remove volumes, run:"
    echo "   docker volume rm $REMAINING_VOLUMES"
fi

echo ""
echo "🎉 Cleanup complete!"
