#!/bin/bash

# Script to run tests in all subrepositories
# Usage: ./test-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧪 Running tests in all subrepositories..."
echo ""

# Results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_REPOS=0

declare -a TEST_RESULTS

# ============================================================================
# TEST BACKEND (be_demo)
# ============================================================================

echo "═══════════════════════════════════════════════════════════"
echo "  Testing Backend (be_demo)"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "be_demo" ] && [ -f "be_demo/BeDemo.Api.Tests/BeDemo.Api.Tests.csproj" ]; then
    cd be_demo
    
    echo "📦 Running .NET tests..."
    # Run tests from the test project directory or use solution/project file
    if [ -f "BeDemo.Api.Tests/BeDemo.Api.Tests.csproj" ]; then
        TEST_OUTPUT=$(dotnet test BeDemo.Api.Tests/BeDemo.Api.Tests.csproj --verbosity minimal 2>&1 || true)
    elif [ -f "*.sln" ]; then
        TEST_OUTPUT=$(dotnet test *.sln --verbosity minimal 2>&1 || true)
    else
        TEST_OUTPUT=$(dotnet test --verbosity minimal 2>&1 || true)
    fi
    TEST_EXIT_CODE=$?
    
    # Parse test results - look for summary line
    # Format: "Passed!  - Failed:     0, Passed:   118, Skipped:     0, Total:   118, Duration: 4 s"
    # Try multiple patterns to match different output formats
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
    
    # Parse Vitest output
    TEST_FILES=$(echo "$TEST_OUTPUT" | grep -oE "Test Files +[0-9]+" | grep -oE "[0-9]+" || echo "0")
    TOTAL=$(echo "$TEST_OUTPUT" | grep -oE "Tests +[0-9]+" | grep -oE "[0-9]+" | head -1 || echo "0")
    PASSED=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1 || echo "0")
    FAILED=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1 || echo "0")
    
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
    
    # Parse Vitest output
    TEST_FILES=$(echo "$TEST_OUTPUT" | grep -oE "Test Files +[0-9]+" | grep -oE "[0-9]+" || echo "0")
    TOTAL=$(echo "$TEST_OUTPUT" | grep -oE "Tests +[0-9]+" | grep -oE "[0-9]+" | head -1 || echo "0")
    PASSED=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1 || echo "0")
    FAILED=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1 || echo "0")
    
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
