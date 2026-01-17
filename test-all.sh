#!/bin/bash

/**
 * test-all.sh - Script to run tests in all subrepositories
 * 
 * This script orchestrates test execution across all subrepositories in the monorepo:
 * - Backend (be_demo) - runs .NET xUnit tests using 'dotnet test'
 * - Frontend (fe_demo) - runs Vitest tests using 'yarn test --run'
 * - Admin (admin_demo) - runs Vitest tests using 'yarn test --run'
 * - Database (db_demo) - infrastructure only, no tests
 * 
 * The script:
 * - Parses test output from different test frameworks (.NET, Vitest)
 * - Aggregates results across all repositories
 * - Displays a consolidated summary with pass/fail counts
 * - Handles repositories that don't have tests gracefully
 * 
 * Usage: ./test-all.sh
 */

set -e  # Exit immediately if a command exits with a non-zero status

# Get the directory where this script is located
# This allows the script to be run from any directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
# TEST BACKEND (be_demo)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Backend (be_demo)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if backend directory exists and has test project
if [ -d "be_demo" ] && [ -f "be_demo/BeDemo.Api.Tests/BeDemo.Api.Tests.csproj" ]; then
    cd be_demo
    
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
            TEST_RESULTS+=("⚠️  be_demo: Tests completed but no count found")
            echo "⚠️  Backend tests completed but no count found"
        else
            TOTAL="0"
            PASSED="0"
            FAILED="1"
            TEST_RESULTS+=("❌ be_demo: Tests failed (exit code: $TEST_EXIT_CODE)")
            echo "❌ Backend tests failed (exit code: $TEST_EXIT_CODE)"
        fi
    else
        TOTAL_TESTS=$((TOTAL_TESTS + ${TOTAL:-0}))
        PASSED_TESTS=$((PASSED_TESTS + ${PASSED:-0}))
        FAILED_TESTS=$((FAILED_TESTS + ${FAILED:-0}))
        
        if [ $TEST_EXIT_CODE -eq 0 ] && [ "${FAILED:-0}" = "0" ]; then
            TEST_RESULTS+=("✅ be_demo: $PASSED/$TOTAL passed")
            echo "✅ Backend tests: $PASSED/$TOTAL passed"
        else
            TEST_RESULTS+=("❌ be_demo: $FAILED failed, $PASSED/$TOTAL passed")
            echo "❌ Backend tests: $FAILED failed, $PASSED/$TOTAL passed"
        fi
    fi
    
    cd ..
else
    TEST_RESULTS+=("⏭️  be_demo: No tests found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Backend: No tests found, skipping"
fi

echo ""

# ============================================================================
# TEST FRONTEND (fe_demo)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Frontend (fe_demo)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "fe_demo" ] && [ -f "fe_demo/package.json" ]; then
    cd fe_demo
    
    # Check if dependencies are installed
    if [ ! -d "node_modules" ] && [ ! -f ".yarn/cache/.gitignore" ]; then
        echo "📦 Installing dependencies..."
        yarn install --silent 2>/dev/null || true
    fi
    
    echo "📦 Running Vitest tests..."
    TEST_OUTPUT=$(yarn test --run 2>&1 || true)
    TEST_EXIT_CODE=$?
    
    # Parse Vitest output using Python for better regex support
    # Format: "Tests  11 passed (11)" or "Tests  23 passed | 8 skipped (31)"
    TEST_FILES=$(echo "$TEST_OUTPUT" | grep -oE "Test Files[ ]+[0-9]+" | grep -oE "[0-9]+" || echo "0")
    
    # Use Python to parse the Tests line more reliably
    TESTS_LINE=$(echo "$TEST_OUTPUT" | grep -E "Tests[ ]+[0-9]+" | head -1)
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
        TEST_RESULTS+=("✅ fe_demo: $PASSED/$TOTAL passed ($TEST_FILES test files)")
        echo "✅ Frontend tests: $PASSED/$TOTAL passed ($TEST_FILES test files)"
    else
        TEST_RESULTS+=("❌ fe_demo: $FAILED failed, $PASSED/$TOTAL passed")
        echo "❌ Frontend tests: $FAILED failed, $PASSED/$TOTAL passed"
    fi
    
    cd ..
else
    TEST_RESULTS+=("⏭️  fe_demo: No tests found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Frontend: No tests found, skipping"
fi

echo ""

# ============================================================================
# TEST ADMIN (admin_demo)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Admin (admin_demo)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "admin_demo" ] && [ -f "admin_demo/package.json" ]; then
    cd admin_demo
    
    # Check if dependencies are installed
    if [ ! -d "node_modules" ] && [ ! -f ".yarn/cache/.gitignore" ]; then
        echo "📦 Installing dependencies..."
        yarn install --silent 2>/dev/null || true
    fi
    
    echo "📦 Running Vitest tests..."
    TEST_OUTPUT=$(yarn test --run 2>&1 || true)
    TEST_EXIT_CODE=$?
    
    # Parse Vitest output using Python for better regex support
    # Format: "Tests  23 passed | 8 skipped (31)" or "Tests  11 passed (11)"
    TEST_FILES=$(echo "$TEST_OUTPUT" | grep -oE "Test Files[ ]+[0-9]+" | grep -oE "[0-9]+" || echo "0")
    
    # Use Python to parse the Tests line more reliably
    TESTS_LINE=$(echo "$TEST_OUTPUT" | grep -E "Tests[ ]+[0-9]+" | head -1)
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
        TEST_RESULTS+=("✅ admin_demo: $PASSED/$TOTAL passed ($TEST_FILES test files)")
        echo "✅ Admin tests: $PASSED/$TOTAL passed ($TEST_FILES test files)"
    else
        TEST_RESULTS+=("❌ admin_demo: $FAILED failed, $PASSED/$TOTAL passed")
        echo "❌ Admin tests: $FAILED failed, $PASSED/$TOTAL passed"
    fi
    
    cd ..
else
    TEST_RESULTS+=("⏭️  admin_demo: No tests found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Admin: No tests found, skipping"
fi

echo ""

# ============================================================================
# TEST DATABASE (db_demo)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Database (db_demo)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "db_demo" ]; then
    # Database setup doesn't have tests, just verify it's configured correctly
    if [ -f "db_demo/docker-compose.yml" ]; then
        TEST_RESULTS+=("⏭️  db_demo: No tests (infrastructure only)")
        SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        echo "⏭️  Database: No tests (infrastructure only)"
    else
        TEST_RESULTS+=("⏭️  db_demo: No tests found")
        SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        echo "⏭️  Database: No tests found, skipping"
    fi
else
    TEST_RESULTS+=("⏭️  db_demo: Not found")
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    echo "⏭️  Database: Not found, skipping"
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
