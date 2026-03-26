#!/bin/bash

# Mechanical Quality Gate Script
# Run by Codex during overnight sessions to verify mechanical standards
# These are objective, binary checks - no judgment required
#
# Exit codes: 0 = pass, 1 = fail, 2 = block (critical)
#
# For judgment gates (architecture, spec drift), see judgment-gate.sh

set -e

echo "========================================="
echo "    MECHANICAL QUALITY GATES (Codex)    "
echo "========================================="

FAILURES=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILURES++))
}

# Gate 1: Linting
echo ""
echo "Gate 1: Linting"
echo "---------------"
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    if npm run lint --if-present 2>/dev/null; then
        pass "Linting passed"
    else
        fail "Linting failed"
    fi
else
    warn "No npm project found, skipping lint"
fi

# Gate 2: Tests
echo ""
echo "Gate 2: Tests"
echo "-------------"
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    if npm test --if-present 2>/dev/null; then
        pass "Tests passed"
    else
        fail "Tests failed"
    fi
else
    warn "No npm project found, skipping tests"
fi

# Gate 3: Type Checking (TypeScript)
echo ""
echo "Gate 3: Type Checking"
echo "---------------------"
if [ -f "tsconfig.json" ]; then
    if npx tsc --noEmit 2>/dev/null; then
        pass "Type checking passed"
    else
        fail "Type errors found"
    fi
else
    warn "No TypeScript config found, skipping type check"
fi

# Gate 4: Security Audit
echo ""
echo "Gate 4: Security Audit"
echo "----------------------"
if command -v npm &> /dev/null && [ -f "package.json" ]; then
    AUDIT_RESULT=$(npm audit --json 2>/dev/null || true)
    CRITICAL=$(echo "$AUDIT_RESULT" | grep -o '"critical":[0-9]*' | grep -o '[0-9]*' || echo "0")
    HIGH=$(echo "$AUDIT_RESULT" | grep -o '"high":[0-9]*' | grep -o '[0-9]*' || echo "0")

    if [ "$CRITICAL" -gt 0 ]; then
        fail "Critical vulnerabilities found: $CRITICAL"
    elif [ "$HIGH" -gt 0 ]; then
        warn "High vulnerabilities found: $HIGH"
    else
        pass "No critical/high vulnerabilities"
    fi
else
    warn "No npm project found, skipping security audit"
fi

# Gate 5: No Debug Code
echo ""
echo "Gate 5: Debug Code Check"
echo "------------------------"
DEBUG_PATTERNS="console\.log|debugger|TODO:|FIXME:|HACK:"
if command -v grep &> /dev/null; then
    DEBUG_COUNT=$(grep -rn --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" \
        -E "$DEBUG_PATTERNS" src/ 2>/dev/null | wc -l || echo "0")
    if [ "$DEBUG_COUNT" -gt 0 ]; then
        warn "Found $DEBUG_COUNT lines with debug code/TODOs"
    else
        pass "No debug code found"
    fi
else
    warn "grep not available, skipping debug code check"
fi

# Gate 6: No Secrets
echo ""
echo "Gate 6: Secrets Check"
echo "---------------------"
SECRET_PATTERNS="password\s*=|api_key\s*=|secret\s*=|token\s*="
if command -v grep &> /dev/null; then
    SECRET_COUNT=$(grep -rni --include="*.ts" --include="*.js" --include="*.json" \
        -E "$SECRET_PATTERNS" . 2>/dev/null | grep -v node_modules | grep -v ".env" | wc -l || echo "0")
    if [ "$SECRET_COUNT" -gt 0 ]; then
        fail "Potential secrets found in code: $SECRET_COUNT occurrences"
    else
        pass "No secrets detected in code"
    fi
else
    warn "grep not available, skipping secrets check"
fi

# Summary
echo ""
echo "========================================="
echo "              SUMMARY                    "
echo "========================================="
echo "Failures: $FAILURES"
echo "Warnings: $WARNINGS"
echo ""

if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}QUALITY GATE: FAILED${NC}"
    echo "Please fix the above failures before proceeding."
    exit 1
else
    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "${YELLOW}QUALITY GATE: PASSED WITH WARNINGS${NC}"
    else
        echo -e "${GREEN}QUALITY GATE: PASSED${NC}"
    fi
    exit 0
fi
