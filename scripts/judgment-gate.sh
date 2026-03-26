#!/bin/bash

# Judgment Quality Gate Script
# Run by Claude Code during morning review sessions
# These require reasoning and judgment - not just binary checks
#
# Exit codes: 0 = pass, 1 = needs attention, 2 = block (requires human)
#
# For mechanical gates (tests, lint), see quality-gate.sh

echo "========================================="
echo "    JUDGMENT QUALITY GATES (Claude)     "
echo "========================================="

CONCERNS=0
BLOCKERS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

concern() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CONCERNS++))
}

block() {
    echo -e "${RED}✗${NC} $1"
    ((BLOCKERS++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Gate 1: Check STATUS.md for overnight blockers
echo ""
echo "Gate 1: Overnight Blockers"
echo "---------------------------"
if [ -f "STATUS.md" ]; then
    BLOCKED_TASKS=$(grep -c "\[B\]" AGENTS.md 2>/dev/null || echo "0")
    if [ "$BLOCKED_TASKS" -gt 0 ]; then
        concern "Found $BLOCKED_TASKS blocked tasks from overnight run"
        info "Review STATUS.md for blocker details"
    else
        pass "No blocked tasks from overnight"
    fi
else
    concern "STATUS.md not found - was overnight run executed?"
fi

# Gate 2: Check for spec drift indicators
echo ""
echo "Gate 2: Spec Drift Detection"
echo "----------------------------"
# Look for TODO/FIXME comments added overnight that suggest drift
NEW_TODOS=$(git diff HEAD~5 --unified=0 2>/dev/null | grep -c "^\+.*TODO\|^\+.*FIXME\|^\+.*HACK" || echo "0")
if [ "$NEW_TODOS" -gt 3 ]; then
    concern "Found $NEW_TODOS new TODO/FIXME comments - possible spec drift"
    info "Review if implementation matches spec intent"
elif [ "$NEW_TODOS" -gt 0 ]; then
    info "$NEW_TODOS new TODO/FIXME comments added"
    pass "Within acceptable range"
else
    pass "No new TODO/FIXME comments"
fi

# Gate 3: Check for architectural concerns
echo ""
echo "Gate 3: Architectural Coherence"
echo "--------------------------------"
# Check for new dependencies added
if [ -f "package.json" ]; then
    NEW_DEPS=$(git diff HEAD~5 package.json 2>/dev/null | grep -c "^\+.*\":" || echo "0")
    if [ "$NEW_DEPS" -gt 5 ]; then
        concern "Many new dependencies added ($NEW_DEPS) - review for necessity"
    elif [ "$NEW_DEPS" -gt 0 ]; then
        info "$NEW_DEPS dependencies changed"
        pass "Review dependency changes"
    else
        pass "No dependency changes"
    fi
fi

# Check for large files added (potential code dump)
LARGE_FILES=$(find . -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" 2>/dev/null | \
    xargs wc -l 2>/dev/null | \
    awk '$1 > 500 {print $2}' | \
    grep -v node_modules | \
    grep -v ".min." | \
    head -5)
if [ -n "$LARGE_FILES" ]; then
    concern "Large files detected (>500 lines):"
    echo "$LARGE_FILES" | while read file; do
        info "  - $file"
    done
    info "Consider if these should be split"
fi

# Gate 4: Technical debt accumulation
echo ""
echo "Gate 4: Technical Debt Check"
echo "----------------------------"
# Count complexity indicators
ANY_TYPES=$(grep -rn ":\s*any" --include="*.ts" --include="*.tsx" src/ 2>/dev/null | wc -l || echo "0")
if [ "$ANY_TYPES" -gt 10 ]; then
    concern "Found $ANY_TYPES 'any' type usages - potential type safety debt"
elif [ "$ANY_TYPES" -gt 0 ]; then
    info "$ANY_TYPES 'any' types found"
else
    pass "No 'any' type shortcuts"
fi

# Check for console.log in production code
CONSOLE_LOGS=$(grep -rn "console\.log" --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" src/ 2>/dev/null | grep -v ".test." | grep -v ".spec." | wc -l || echo "0")
if [ "$CONSOLE_LOGS" -gt 5 ]; then
    concern "Found $CONSOLE_LOGS console.log statements in production code"
elif [ "$CONSOLE_LOGS" -gt 0 ]; then
    info "$CONSOLE_LOGS console.log statements (may be intentional)"
else
    pass "No debug logging in production code"
fi

# Gate 5: Check if overnight work solves the right problem
echo ""
echo "Gate 5: Intent Verification"
echo "---------------------------"
info "This requires human/Claude judgment:"
echo "  • Does the implementation match the spec INTENT, not just literal words?"
echo "  • Are there edge cases the spec didn't explicitly mention?"
echo "  • Would a user be satisfied with this implementation?"
echo ""
info "Run code review subagents for detailed analysis:"
echo "  claude> /review"

# Summary
echo ""
echo "========================================="
echo "              SUMMARY                    "
echo "========================================="
echo "Concerns: $CONCERNS"
echo "Blockers: $BLOCKERS"
echo ""

if [ "$BLOCKERS" -gt 0 ]; then
    echo -e "${RED}JUDGMENT GATE: BLOCKED${NC}"
    echo "Human intervention required before proceeding."
    exit 2
elif [ "$CONCERNS" -gt 2 ]; then
    echo -e "${YELLOW}JUDGMENT GATE: NEEDS ATTENTION${NC}"
    echo "Review concerns before updating spec for next overnight run."
    exit 1
else
    echo -e "${GREEN}JUDGMENT GATE: PASSED${NC}"
    echo "Overnight work looks good. Update AGENTS.md for next run."
    exit 0
fi
