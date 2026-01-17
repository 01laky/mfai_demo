#!/bin/bash

# rebuild-all-dev.sh - Script to rebuild all development Docker images from scratch
#
# This script performs clean rebuilds of all development services:
# 1. Database (db_demo) - PostgreSQL (no rebuild needed, uses official image)
# 2. Backend (be_demo) - ASP.NET Core API
# 3. Frontend (fe_demo) - React + Vite
# 4. Admin (admin_demo) - React + Vite admin panel
# 5. AI Demo (ai_demo) - Python gRPC server
# 6. Logger Demo (logger_demo) - Dozzle log viewer
#
# The script rebuilds each service's Docker image with --no-cache
# to ensure a completely clean build.
#
# NOTE: This script only builds images, it does NOT start containers.
# Use ./start-all-dev.sh to start containers after rebuilding images.
#
# Usage: ./rebuild-all-dev.sh

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Rebuilding all development Docker images (clean builds)..."
echo ""
echo "⚠️  This will rebuild all Docker images from scratch (--no-cache)"
echo "   This may take several minutes..."
echo ""

# ============================================================================
# REBUILD BACKEND (be_demo)
# ============================================================================
echo "📦 Rebuilding backend (be_demo)..."
if [ -f "be_demo/rebuild-dev.sh" ]; then
    cd be_demo
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  be_demo/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD FRONTEND (fe_demo)
# ============================================================================
echo "📦 Rebuilding frontend (fe_demo)..."
if [ -f "fe_demo/rebuild-dev.sh" ]; then
    cd fe_demo
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  fe_demo/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD ADMIN (admin_demo)
# ============================================================================
echo "📦 Rebuilding admin (admin_demo)..."
if [ -f "admin_demo/rebuild-dev.sh" ]; then
    cd admin_demo
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  admin_demo/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD AI DEMO (ai_demo)
# ============================================================================
echo "📦 Rebuilding AI Demo (ai_demo)..."
if [ -f "ai_demo/rebuild-dev.sh" ]; then
    cd ai_demo
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  ai_demo/rebuild-dev.sh not found, skipping..."
fi
echo ""

# ============================================================================
# REBUILD LOGGER DEMO (logger_demo)
# ============================================================================
echo "📦 Rebuilding Logger Demo (logger_demo)..."
if [ -f "logger_demo/rebuild-dev.sh" ]; then
    cd logger_demo
    ./rebuild-dev.sh
    cd ..
else
    echo "  ⚠️  logger_demo/rebuild-dev.sh not found, skipping..."
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
echo "   ✅ Backend (be_demo)"
echo "   ✅ Frontend (fe_demo)"
echo "   ✅ Admin (admin_demo)"
echo "   ✅ AI Demo (ai_demo)"
echo "   ✅ Logger Demo (logger_demo)"
echo ""
echo "💡 Note: Database (db_demo) uses official PostgreSQL image"
echo "   and doesn't need rebuilding."
echo ""
echo "💡 Note: Images were built but containers were NOT started."
echo "   Use ./start-all-dev.sh to start containers with the new images."
echo "═══════════════════════════════════════════════════════════"
