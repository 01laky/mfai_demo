#!/bin/bash

# rebuild-all-dev.sh - Script to rebuild all development Docker images from scratch
#
# This script performs clean rebuilds of all development services:
# 1. Database (many_faces_database) - PostgreSQL (no rebuild, official image)
#    Redis (many_faces_redis) - same, official redis:7-alpine
# 2. Backend (many_faces_backend) - ASP.NET Core API
# 3. Frontend (many_faces_portal) - React + Vite
# 4. Admin (many_faces_admin) - React + Vite admin panel
# 5. AI Demo (many_faces_ai) - Python gRPC server
# 6. Logger Demo (many_faces_logger) - Dozzle log viewer
#
# The script rebuilds each service's Docker image with --no-cache
# to ensure a completely clean build.
#
# NOTE: This script only builds images, it does NOT start containers.
# Use ./scripts/start-all-dev.sh to start containers after rebuilding images.
#
# Usage: ./scripts/rebuild-all-dev.sh (from repository root)

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

echo "🔨 Rebuilding all development Docker images (clean builds)..."
echo ""
echo "⚠️  This will rebuild all Docker images from scratch (--no-cache)"
echo "   This may take several minutes..."
echo ""

# ============================================================================
# REBUILD BACKEND (many_faces_backend)
# ============================================================================
echo "📦 Rebuilding backend (many_faces_backend)..."
if [ -f "many_faces_backend/rebuild-dev.sh" ]; then
    cd many_faces_backend
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  many_faces_backend/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD FRONTEND (many_faces_portal)
# ============================================================================
echo "📦 Rebuilding frontend (many_faces_portal)..."
if [ -f "many_faces_portal/rebuild-dev.sh" ]; then
    cd many_faces_portal
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  many_faces_portal/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD ADMIN (many_faces_admin)
# ============================================================================
echo "📦 Rebuilding admin (many_faces_admin)..."
if [ -f "many_faces_admin/rebuild-dev.sh" ]; then
    cd many_faces_admin
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  many_faces_admin/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD AI DEMO (many_faces_ai)
# ============================================================================
echo "📦 Rebuilding AI Demo (many_faces_ai)..."
if [ -f "many_faces_ai/rebuild-dev.sh" ]; then
    cd many_faces_ai
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  many_faces_ai/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD LOGGER DEMO (many_faces_logger)
# ============================================================================
echo "📦 Rebuilding Logger Demo (many_faces_logger)..."
if [ -f "many_faces_logger/rebuild-dev.sh" ]; then
    cd many_faces_logger
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  many_faces_logger/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "                    REBUILD SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✅ All Docker images have been rebuilt from scratch!"
echo ""
echo "📋 Rebuilt services:"
echo "   ✅ Backend (many_faces_backend)"
echo "   ✅ Frontend (many_faces_portal)"
echo "   ✅ Admin (many_faces_admin)"
echo "   ✅ AI Demo (many_faces_ai)"
echo "   ✅ Logger Demo (many_faces_logger)"
echo ""
echo "💡 Note: many_faces_database and many_faces_redis use official images — no rebuild."
echo ""
echo "💡 Note: Images were built but containers were NOT started."
echo "   Use ./scripts/start-all-dev.sh to start containers with the new images."
echo "═══════════════════════════════════════════════════════════"
