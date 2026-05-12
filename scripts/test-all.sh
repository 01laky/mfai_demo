#!/bin/bash

# test-all.sh - Script to run tests in all subrepositories
# 
# This script orchestrates test execution across all subrepositories in the monorepo:
# - Backend (many_faces_backend) - runs .NET xUnit tests using 'dotnet test'
# - Frontend (many_faces_portal) - runs Vitest tests using 'yarn test --run' and Cypress e2e tests
# - Admin (many_faces_admin) - runs Vitest tests using 'yarn test --run'
# - Database (many_faces_database) - infrastructure only, no tests
# - Redis (many_faces_redis) - infrastructure only, no tests
# - AI Demo (many_faces_ai) - verify-ci.sh (ruff + pytest, same as GitHub Actions)
# 
# The script:
# - Parses test output from different test frameworks (.NET, Vitest, Cypress)
# - Aggregates results across all repositories
# - Displays a consolidated summary with pass/fail counts
# - Handles repositories that don't have tests gracefully
# - For Cypress e2e tests: automatically starts DB, BE, FE if not running
# 
# Environment:
#   SKIP_CYPRESS=1  Skip Cypress e2e (default in scripts/ci-local.sh / monorepo CI job)
#
# Usage: ./scripts/test-all.sh (from repository root)

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
# This allows the script to be run from any directory
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

echo "🧪 Running tests in all subrepositories..."
echo ""

# Results tracking variables
# These accumulate totals across all repositories
TOTAL_TESTS=0      # Total number of tests across all repositories
PASSED_TESTS=0     # Number of tests that passed
FAILED_TESTS=0     # Number of tests that failed
SKIPPED_REPOS=0    # Number of repositories that don't have tests

# Array to store test results for each repository
# Used to display a summary at the end
declare -a TEST_RESULTS

# ============================================================================
# TEST BACKEND (many_faces_backend)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Backend (many_faces_backend)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if backend directory exists and has test project
if [ -d "many_faces_backend" ] && [ -f "many_faces_backend/BeDemo.Api.Tests/BeDemo.Api.Tests.csproj" ]; then
    cd many_faces_backend
    
    echo "📦 Running .NET tests..."
    # Run tests from the test project directory or use solution/project file
    # Try multiple approaches to find and run tests
    if [ -f "BeDemo.Api.Tests/BeDemo.Api.Tests.csproj" ]; then
        # Explicitly target the test project file (most reliable)
        TEST_OUTPUT=$(dotnet test BeDemo.Api.Tests/BeDemo.Api.Tests.csproj --verbosity minimal 2>&1 || true)
    elif [ -f "*.sln" ]; then
        # Use solution file if test project not found directly
        TEST_OUTPUT=$(dotnet test *.sln --verbosity minimal 2>&1 || true)
    else
        # Fallback: run tests from current directory
        TEST_OUTPUT=$(dotnet test --verbosity minimal 2>&1 || true)
    fi
    TEST_EXIT_CODE=$?
    
    # Parse test results from .NET test output
    # .NET test output format: "Passed!  - Failed:     0, Passed:   118, Skipped:     0, Total:   118, Duration: 4 s"
    # Try multiple regex patterns to match different output formats
    # Extract numbers using grep with extended regex (-oE) and capture groups
    TOTAL=$(echo "$TEST_OUTPUT" | grep -oE "Total:[ ]*[0-9]+" | grep -oE "[0-9]+" || echo "0")
    PASSED=$(echo "$TEST_OUTPUT" | grep -oE "Passed:[ ]*[0-9]+" | grep -oE "[0-9]+" || echo "0")
    FAILED=$(echo "$TEST_OUTPUT" | grep -oE "Failed:[ ]*[0-9]+" | grep -oE "[0-9]+" || echo "0")
    
    # Alternative parsing if first didn't work
    if [ -z "$TOTAL" ] || [ "$TOTAL" = "0" ]; then
        TOTAL=$(echo "$TEST_OUTPUT" | grep -oE "Total tests: [0-9]+" | grep -oE "[0-9]+" || echo "0")
        PASSED=$(echo "$TEST_OUTPUT" | grep -oE "Passed! +[0-9]+" | grep -oE "[0-9]+" || echo "0")
        FAILED=$(echo "$TEST_OUTPUT" | grep -oE "Failed! +[0-9]+" | grep -oE "[0-9]+" || echo "0")
    fi
    
    # Another alternative - look for "Passed!" line with comma-separated values
    if [ -z "$TOTAL" ] || [ "$TOTAL" = "0" ]; then
        # Extract from line like: "Passed!  - Failed:     0, Passed:   118, Skipped:     0, Total:   118"
        LINE=$(echo "$TEST_OUTPUT" | grep "Passed!" | grep "Total:" | head -1)
        if [ -n "$LINE" ]; then
            TOTAL=$(echo "$LINE" | grep -oE "Total:[ ]*[0-9]+" | grep -oE "[0-9]+" || echo "0")
            PASSED=$(echo "$LINE" | grep -oE "Passed:[ ]*[0-9]+" | grep -oE "[0-9]+" || echo "0")
            FAILED=$(echo "$LINE" | grep -oE "Failed:[ ]*[0-9]+" | grep -oE "[0-9]+" || echo "0")
        fi
    fi
    
    # If still no results, check exit code
    if [ -z "$TOTAL" ] || [ "$TOTAL" = "0" ]; then
        if [ $TEST_EXIT_CODE -eq 0 ]; then
            TOTAL="0"
            PASSED="0"
            FAILED="0"
            TEST_RESULTS+=("⚠️  many_faces_backend: Tests completed but no count found")
            echo "⚠️  Backend tests completed but no count found"
        else
            TOTAL="0"
            PASSED="0"
            FAILED="1"
            TEST_RESULTS+=("❌ many_faces_backend: Tests failed (exit code: $TEST_EXIT_CODE)")
            echo "❌ Backend tests failed (exit code: $TEST_EXIT_CODE)"
        fi
    else
        TOTAL_TESTS=$((TOTAL_TESTS + ${TOTAL:-0}))
        PASSED_TESTS=$((PASSED_TESTS + ${PASSED:-0}))
        FAILED_TESTS=$((FAILED_TESTS + ${FAILED:-0}))
        
        if [ $TEST_EXIT_CODE -eq 0 ] && [ "${FAILED:-0}" = "0" ]; then
            TEST_RESULTS+=("✅ many_faces_backend: $PASSED/$TOTAL passed")
            echo "✅ Backend tests: $PASSED/$TOTAL passed"
        else
            TEST_RESULTS+=("❌ many_faces_backend: $FAILED failed, $PASSED/$TOTAL passed")
            echo "❌ Backend tests: $FAILED failed, $PASSED/$TOTAL passed"
        fi
    fi
    
    cd ..
else
    TEST_RESULTS+=("⏭️  many_faces_backend: No tests found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Backend: No tests found, skipping"
fi

echo ""

# ============================================================================
# TEST FRONTEND (many_faces_portal)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Frontend (many_faces_portal)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "many_faces_portal" ] && [ -f "many_faces_portal/package.json" ]; then
    cd many_faces_portal
    
    # Check if dependencies are installed
    if [ ! -d "node_modules" ] && [ ! -f ".yarn/cache/.gitignore" ]; then
        echo "📦 Installing dependencies..."
        yarn install --silent 2>/dev/null || true
    fi
    
    echo "📦 Running Vitest tests..."
    TEST_OUTPUT=$(yarn test 2>&1 || true)
    TEST_EXIT_CODE=$?
    
    # Parse Vitest output using Python for better regex support
    # Format: "Tests  11 passed (11)" or "Tests  23 passed | 8 skipped (31)"
    TEST_FILES=$(echo "$TEST_OUTPUT" | grep -oE "Test Files[ ]+[0-9]+" | grep -oE "[0-9]+" || echo "0")
    
    # Use Python to parse the Tests line more reliably
    # Get the full line containing "Tests" - important for parsing "passed (X)" and "(X)"
    TESTS_LINE=$(echo "$TEST_OUTPUT" | grep "Tests" | head -1)
    if [ -n "$TESTS_LINE" ]; then
        PARSED=$(echo "$TESTS_LINE" | python3 -c "
import sys
import re
line = sys.stdin.read().strip()
# Extract total from parentheses: (11) or (31)
total_match = re.search(r'\((\d+)\)', line)
total = total_match.group(1) if total_match else '0'
# Extract passed count
passed_match = re.search(r'(\d+) passed', line)
passed = passed_match.group(1) if passed_match else '0'
# Extract failed count
failed_match = re.search(r'(\d+) failed', line)
failed = failed_match.group(1) if failed_match else '0'
print(f'{total}|{passed}|{failed}')
" 2>/dev/null || echo "0|0|0")
        TOTAL=$(echo "$PARSED" | cut -d'|' -f1)
        PASSED=$(echo "$PARSED" | cut -d'|' -f2)
        FAILED=$(echo "$PARSED" | cut -d'|' -f3)
    else
        TOTAL="0"
        PASSED="0"
        FAILED="0"
    fi
    
    VITEST_TOTAL=${TOTAL:-0}
    VITEST_PASSED=${PASSED:-0}
    VITEST_FAILED=${FAILED:-0}
    
    TOTAL_TESTS=$((TOTAL_TESTS + ${TOTAL:-0}))
    PASSED_TESTS=$((PASSED_TESTS + ${PASSED:-0}))
    FAILED_TESTS=$((FAILED_TESTS + ${FAILED:-0}))
    
    VITEST_EXIT_CODE=$TEST_EXIT_CODE
    
    # Run Cypress e2e tests if cypress is installed
    E2E_TOTAL=0
    E2E_PASSED=0
    E2E_FAILED=0
    E2E_SERVICES_STARTED=false
    
    if [ "${SKIP_CYPRESS:-}" = "1" ]; then
        echo ""
        echo "⏭️  Cypress e2e skipped (SKIP_CYPRESS=1)"
    elif [ -f "cypress.config.ts" ] || [ -f "cypress.config.mjs" ] || [ -d "cypress" ]; then
        echo ""
        echo "📦 Running Cypress e2e tests..."
        
        # Check if required services are running for e2e tests
        # Vite runs on port 8081 by default (see vite.config.ts)
        FRONTEND_PORT=8081
        BACKEND_URL="http://localhost:8000"
        E2E_SERVICES_STARTED=false
        
        echo "🔍 Checking required services for e2e tests..."
        echo ""
        
        # Start database if not running
        DB_RUNNING=false
        if docker ps --format '{{.Names}}' | grep -q "postgres-dev"; then
            echo "✅ Database is already running"
            DB_RUNNING=true
        else
            echo "📦 Starting database..."
            if [ -d "../many_faces_database" ]; then
                cd ../many_faces_database
                docker-compose up -d > /dev/null 2>&1 || true
                sleep 3
                cd ../many_faces_portal
                E2E_SERVICES_STARTED=true
                DB_RUNNING=true
            else
                echo "⚠️  Database directory not found"
            fi
        fi
        
        # Start backend if not running
        BACKEND_RUNNING=false
        if curl -s "$BACKEND_URL/swagger" > /dev/null 2>&1; then
            echo "✅ Backend is already running"
            BACKEND_RUNNING=true
        else
            echo "📦 Starting backend..."
            if [ -d "../many_faces_backend" ]; then
                cd ../many_faces_backend
                # Try start-dev.sh, fallback to docker-compose
                ./start-dev.sh > /dev/null 2>&1 || docker-compose -f docker-compose.dev.yml up -d > /dev/null 2>&1 || true
                cd ../many_faces_portal
                E2E_SERVICES_STARTED=true
                
                # Wait for backend to be ready (it can take 30-60s)
                echo "⏳ Waiting for backend to start (this may take up to 60 seconds)..."
                for i in {1..60}; do
                    if curl -s "$BACKEND_URL/swagger" > /dev/null 2>&1; then
                        echo "✅ Backend is ready!"
                        BACKEND_RUNNING=true
                        break
                    fi
                    if [ $((i % 10)) -eq 0 ]; then
                        echo "   Still waiting... ($i/60 seconds)"
                    fi
                    sleep 1
                done
                
                if [ "$BACKEND_RUNNING" = false ]; then
                    echo "❌ Backend failed to start within timeout"
                fi
            else
                echo "⚠️  Backend directory not found"
            fi
        fi
        
        # Check if frontend is running
        if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
            echo "✅ Frontend is already running on localhost:$FRONTEND_PORT"
            FRONTEND_ALREADY_RUNNING=true
        else
            FRONTEND_ALREADY_RUNNING=false
        fi
        
        # Only proceed if database and backend are ready
        if [ "$DB_RUNNING" = true ] && [ "$BACKEND_RUNNING" = true ]; then
            echo ""
            echo "✅ All required services are ready (DB, BE)"
            
            if [ "$FRONTEND_ALREADY_RUNNING" = true ]; then
                # Frontend is already running, run e2e tests
                E2E_OUTPUT=$(CYPRESS_BASE_URL=http://localhost:$FRONTEND_PORT yarn test:e2e 2>&1 || true)
                E2E_EXIT_CODE=$?
            else
                # Start frontend if not running
                echo "📦 Starting frontend for e2e tests..."
                yarn dev > /dev/null 2>&1 &
                FE_PID=$!
                E2E_SERVICES_STARTED=true
                
                # Wait for frontend to be ready (give it more time - Vite can take 30-60s)
                echo "⏳ Waiting for frontend to start on port $FRONTEND_PORT (this may take up to 60 seconds)..."
                for i in {1..60}; do
                    if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
                        echo "✅ Frontend is ready!"
                        break
                    fi
                    if [ $((i % 10)) -eq 0 ]; then
                        echo "   Still waiting... ($i/60 seconds)"
                    fi
                    sleep 1
                done
                
                # Give frontend a bit more time to fully initialize
                sleep 3
                
                # Check if frontend is accessible
                if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
                    # Frontend is ready, run e2e tests (keep frontend running!)
                    E2E_OUTPUT=$(CYPRESS_BASE_URL=http://localhost:$FRONTEND_PORT yarn test:e2e 2>&1 || true)
                    E2E_EXIT_CODE=$?
                else
                    echo "❌ Frontend failed to start within timeout. Skipping e2e tests."
                    E2E_OUTPUT=""
                    E2E_EXIT_CODE=1
                    kill $FE_PID 2>/dev/null || true
                fi
            fi
        else
            echo ""
            echo "❌ Required services (DB, BE) are not ready. Skipping e2e tests."
            E2E_OUTPUT=""
            E2E_EXIT_CODE=1
        fi
        
        # Parse Cypress output (common for both branches)
        if [ -n "$E2E_OUTPUT" ]; then
            # Cypress output format example:
            # "✖  4 of 4 failed (100%)   03:05   18    -    18    -    -"
            # Format: "Spec Tests Passing Failing Pending Skipped"
            # The summary line has numbers in this order
            SUMMARY_LINE=$(echo "$E2E_OUTPUT" | grep -E "✖.*failed.*%|✔.*passed.*%|Tests.*Passing.*Failing" | tail -1)
            
            if [ -n "$SUMMARY_LINE" ]; then
                # Extract numbers from the summary line (format: "✖  X of Y failed ... 18  -  18  -  -")
                # The pattern is: total_tests, passing, failing
                # Use Python to parse reliably
                PARSED=$(echo "$SUMMARY_LINE" | python3 -c "
import sys
import re
line = sys.stdin.read().strip()
# Find pattern like '18  -  18' or numbers separated by spaces/hyphens
# Format is usually: TotalTests  Passing  Failing  Pending  Skipped
numbers = re.findall(r'\d+', line)
if len(numbers) >= 3:
    # Usually: [total_or_spec_count, passing, failing, ...]
    total = numbers[0] if numbers[0] else '0'
    passing = numbers[1] if len(numbers) > 1 and numbers[1] else '0'
    failing = numbers[2] if len(numbers) > 2 and numbers[2] else '0'
    # If 'X of Y' pattern, use Y as total
    of_match = re.search(r'(\d+)\s+of\s+(\d+)', line)
    if of_match:
        failing = of_match.group(1)
        total = of_match.group(2)
        passing = str(int(total) - int(failing))
    print(f'{total}|{passing}|{failing}')
else:
    print('0|0|0')
" 2>/dev/null || echo "0|0|0")
                
                E2E_TOTAL=$(echo "$PARSED" | cut -d'|' -f1)
                E2E_PASSING=$(echo "$PARSED" | cut -d'|' -f2)
                E2E_FAILING=$(echo "$PARSED" | cut -d'|' -f3)
            else
                E2E_TOTAL=0
                E2E_PASSING=0
                E2E_FAILING=0
            fi
            
            # Fallback: Try simple grep patterns
            if [ -z "$E2E_PASSING" ] || [ "$E2E_PASSING" = "0" ]; then
                E2E_PASSING=$(echo "$E2E_OUTPUT" | grep -oE "([0-9]+) passing" | grep -oE "[0-9]+" | head -1 || echo "0")
                E2E_FAILING=$(echo "$E2E_OUTPUT" | grep -oE "([0-9]+) failing" | grep -oE "[0-9]+" | head -1 || echo "0")
            fi
            
            # Calculate total and assign
            E2E_PASSED=${E2E_PASSING:-0}
            E2E_FAILED=${E2E_FAILING:-0}
            if [ -z "$E2E_TOTAL" ] || [ "$E2E_TOTAL" = "0" ]; then
                E2E_TOTAL=$((E2E_PASSED + E2E_FAILED))
            fi
            
            # Add E2E tests to global totals (even if parsing failed, we still ran tests)
            TOTAL_TESTS=$((TOTAL_TESTS + E2E_TOTAL))
            PASSED_TESTS=$((PASSED_TESTS + E2E_PASSED))
            FAILED_TESTS=$((FAILED_TESTS + E2E_FAILED))
            
            if [ $E2E_EXIT_CODE -eq 0 ] && [ "$E2E_FAILED" = "0" ]; then
                echo "✅ Cypress e2e tests: $E2E_PASSED/$E2E_TOTAL passed"
            else
                echo "❌ Cypress e2e tests: $E2E_FAILED failed, $E2E_PASSED/$E2E_TOTAL passed"
            fi
        else
            # E2E tests were skipped, but E2E_TOTAL is still 0, so no need to add
            echo "⏭️  Cypress e2e tests: skipped (services not ready)"
        fi
        
        # Stop frontend if we started it (after e2e tests are done)
        if [ "$E2E_SERVICES_STARTED" = true ]; then
            echo "🛑 Stopping frontend server..."
            kill $FE_PID 2>/dev/null || true
            sleep 1
        fi
    fi
    
    # Combine Vitest and Cypress results
    COMBINED_TOTAL=$((VITEST_TOTAL + E2E_TOTAL))
    COMBINED_PASSED=$((VITEST_PASSED + E2E_PASSED))
    COMBINED_FAILED=$((VITEST_FAILED + E2E_FAILED))
    
    if [ $VITEST_EXIT_CODE -eq 0 ] && [ "${VITEST_FAILED:-0}" = "0" ] && [ "$E2E_FAILED" = "0" ]; then
        if [ "$E2E_TOTAL" -gt 0 ]; then
            TEST_RESULTS+=("✅ many_faces_portal: $COMBINED_PASSED/$COMBINED_TOTAL passed ($TEST_FILES test files, $E2E_TOTAL e2e)")
            echo "✅ Frontend tests: $COMBINED_PASSED/$COMBINED_TOTAL passed ($VITEST_TOTAL unit, $E2E_TOTAL e2e)"
        elif [ "${SKIP_CYPRESS:-}" = "1" ] && { [ -f "cypress.config.ts" ] || [ -f "cypress.config.mjs" ] || [ -d "cypress" ]; }; then
            TEST_RESULTS+=("✅ many_faces_portal: $COMBINED_PASSED/$COMBINED_TOTAL passed ($TEST_FILES test files, e2e skipped via SKIP_CYPRESS)")
            echo "✅ Frontend tests: $COMBINED_PASSED/$COMBINED_TOTAL passed ($VITEST_TOTAL unit, e2e skipped via SKIP_CYPRESS)"
        elif [ -f "cypress.config.ts" ] || [ -f "cypress.config.mjs" ] || [ -d "cypress" ]; then
            # Cypress is installed but tests were skipped (frontend not running)
            TEST_RESULTS+=("✅ many_faces_portal: $COMBINED_PASSED/$COMBINED_TOTAL passed ($TEST_FILES test files, e2e skipped - frontend not running)")
            echo "✅ Frontend tests: $COMBINED_PASSED/$COMBINED_TOTAL passed ($VITEST_TOTAL unit, e2e skipped - frontend not running)"
        else
            TEST_RESULTS+=("✅ many_faces_portal: $COMBINED_PASSED/$COMBINED_TOTAL passed ($TEST_FILES test files)")
            echo "✅ Frontend tests: $COMBINED_PASSED/$COMBINED_TOTAL passed ($VITEST_TOTAL unit)"
        fi
    else
        TEST_RESULTS+=("❌ many_faces_portal: $COMBINED_FAILED failed, $COMBINED_PASSED/$COMBINED_TOTAL passed")
        echo "❌ Frontend tests: $COMBINED_FAILED failed, $COMBINED_PASSED/$COMBINED_TOTAL passed"
    fi
    
    cd ..
else
    TEST_RESULTS+=("⏭️  many_faces_portal: No tests found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Frontend: No tests found, skipping"
fi

echo ""

# ============================================================================
# TEST ADMIN (many_faces_admin)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Admin (many_faces_admin)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "many_faces_admin" ] && [ -f "many_faces_admin/package.json" ]; then
    cd many_faces_admin
    
    # Check if dependencies are installed
    if [ ! -d "node_modules" ] && [ ! -f ".yarn/cache/.gitignore" ]; then
        echo "📦 Installing dependencies..."
        yarn install --silent 2>/dev/null || true
    fi
    
    echo "📦 Running Vitest tests..."
    TEST_OUTPUT=$(yarn test 2>&1 || true)
    TEST_EXIT_CODE=$?
    
    # Parse Vitest output using Python for better regex support
    # Format: "Tests  23 passed | 8 skipped (31)" or "Tests  11 passed (11)"
    TEST_FILES=$(echo "$TEST_OUTPUT" | grep -oE "Test Files[ ]+[0-9]+" | grep -oE "[0-9]+" || echo "0")
    
    # Use Python to parse the Tests line more reliably
    # Get the full line containing "Tests" - important for parsing "passed (X)" and "(X)"
    TESTS_LINE=$(echo "$TEST_OUTPUT" | grep "Tests" | head -1)
    if [ -n "$TESTS_LINE" ]; then
        PARSED=$(echo "$TESTS_LINE" | python3 -c "
import sys
import re
line = sys.stdin.read().strip()
# Extract total from parentheses: (11) or (31)
total_match = re.search(r'\((\d+)\)', line)
total = total_match.group(1) if total_match else '0'
# Extract passed count
passed_match = re.search(r'(\d+) passed', line)
passed = passed_match.group(1) if passed_match else '0'
# Extract failed count
failed_match = re.search(r'(\d+) failed', line)
failed = failed_match.group(1) if failed_match else '0'
print(f'{total}|{passed}|{failed}')
" 2>/dev/null || echo "0|0|0")
        TOTAL=$(echo "$PARSED" | cut -d'|' -f1)
        PASSED=$(echo "$PARSED" | cut -d'|' -f2)
        FAILED=$(echo "$PARSED" | cut -d'|' -f3)
    else
        TOTAL="0"
        PASSED="0"
        FAILED="0"
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + ${TOTAL:-0}))
    PASSED_TESTS=$((PASSED_TESTS + ${PASSED:-0}))
    FAILED_TESTS=$((FAILED_TESTS + ${FAILED:-0}))
    
    if [ $TEST_EXIT_CODE -eq 0 ] && [ "${FAILED:-0}" = "0" ]; then
        TEST_RESULTS+=("✅ many_faces_admin: $PASSED/$TOTAL passed ($TEST_FILES test files)")
        echo "✅ Admin tests: $PASSED/$TOTAL passed ($TEST_FILES test files)"
    else
        TEST_RESULTS+=("❌ many_faces_admin: $FAILED failed, $PASSED/$TOTAL passed")
        echo "❌ Admin tests: $FAILED failed, $PASSED/$TOTAL passed"
    fi
    
    cd ..
else
    TEST_RESULTS+=("⏭️  many_faces_admin: No tests found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Admin: No tests found, skipping"
fi

echo ""

# ============================================================================
# TEST MOBILE (many_faces_mobile)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Mobile (many_faces_mobile)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "many_faces_mobile" ] && [ -f "many_faces_mobile/package.json" ]; then
    cd many_faces_mobile
    find scripts -maxdepth 1 -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    if [ ! -d "node_modules" ]; then
        echo "📦 Installing npm dependencies..."
        npm ci --silent 2>/dev/null || npm ci
    fi
    echo "📦 Running Jest (jest-expo) via scripts/test.sh..."
    if [ -f "./scripts/test.sh" ]; then
        if ./scripts/test.sh 2>&1; then
            TEST_RESULTS+=("✅ many_faces_mobile: npm test passed")
            echo "✅ many_faces_mobile: npm test passed"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            TEST_RESULTS+=("❌ many_faces_mobile: npm test failed")
            echo "❌ many_faces_mobile: npm test failed"
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    elif npm test 2>&1; then
        TEST_RESULTS+=("✅ many_faces_mobile: npm test passed")
        echo "✅ many_faces_mobile: npm test passed"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        TEST_RESULTS+=("❌ many_faces_mobile: npm test failed")
        echo "❌ many_faces_mobile: npm test failed"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    cd ..
else
    TEST_RESULTS+=("⏭️  many_faces_mobile: not found, skipping")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  many_faces_mobile: not found, skipping"
fi

echo ""

# ============================================================================
# TEST AI (many_faces_ai) — same as CI: verify-ci.sh
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing AI service (many_faces_ai)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "many_faces_ai" ] && [ -f "many_faces_ai/scripts/verify-ci.sh" ]; then
    find many_faces_ai/scripts -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
    if (cd many_faces_ai && ./scripts/verify-ci.sh); then
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("✅ many_faces_ai: verify-ci (ruff + pytest) passed")
        echo "✅ many_faces_ai: verify-ci passed"
    else
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("❌ many_faces_ai: verify-ci failed")
        echo "❌ many_faces_ai: verify-ci failed"
    fi
else
    TEST_RESULTS+=("⏭️  many_faces_ai: scripts/verify-ci.sh not found, skipping")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  many_faces_ai: not found or no scripts/verify-ci.sh, skipping"
fi

echo ""

# ============================================================================
# TEST DATABASE (many_faces_database)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Database (many_faces_database)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "many_faces_database" ]; then
    # Database setup doesn't have tests, just verify it's configured correctly
    if [ -f "many_faces_database/docker-compose.yml" ]; then
        TEST_RESULTS+=("⏭️  many_faces_database: No tests (infrastructure only)")
        SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        echo "⏭️  Database: No tests (infrastructure only)"
    else
        TEST_RESULTS+=("⏭️  many_faces_database: No tests found")
        SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        echo "⏭️  Database: No tests found, skipping"
    fi
else
    TEST_RESULTS+=("⏭️  many_faces_database: Not found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Database: Not found, skipping"
fi

echo ""

# ============================================================================
# TEST REDIS (many_faces_redis)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Redis (many_faces_redis)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "many_faces_redis" ]; then
    if [ -f "many_faces_redis/docker-compose.yml" ]; then
        TEST_RESULTS+=("⏭️  many_faces_redis: No tests (infrastructure only)")
        SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        echo "⏭️  Redis: No tests (infrastructure only)"
    else
        TEST_RESULTS+=("⏭️  many_faces_redis: No compose file")
        SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        echo "⏭️  Redis: No compose file, skipping"
    fi
else
    TEST_RESULTS+=("⏭️  many_faces_redis: Not found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Redis: Not found, skipping"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "                    TEST RESULTS SUMMARY"
echo "═══════════════════════════════════════════════════════════"
echo ""

for result in "${TEST_RESULTS[@]}"; do
    echo "  $result"
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total Tests: $TOTAL_TESTS"
echo "  ✅ Passed:   $PASSED_TESTS"
echo "  ❌ Failed:   $FAILED_TESTS"
echo "  ⏭️  Skipped: $SKIPPED_REPOS repositories"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL_TESTS -gt 0 ]; then
    echo "✅ All tests passed!"
    exit 0
elif [ $TOTAL_TESTS -eq 0 ]; then
    echo "⚠️  No tests were executed"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
