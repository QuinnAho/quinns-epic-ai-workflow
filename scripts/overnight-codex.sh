#!/bin/bash

# Overnight Codex Runner
# Runs Codex in a loop, processing tasks from AGENTS.md sequentially
# Updates STATUS.md after each task for morning handoff to Claude

set -e

# Configuration
MAX_TASKS=10
TASK_TIMEOUT=3600  # 60 minutes per task
MAX_CONSECUTIVE_FAILURES=3
RATE_LIMIT_PAUSE=1800  # 30 minutes
LOG_DIR=".codex-logs"
SESSION_ID=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'1
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create log directory
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/session_$SESSION_ID.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$msg" | tee -a "$LOG_FILE"
}

log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> STATUS.md
}

# Initialize STATUS.md for this session
init_status() {
    log "${BLUE}Initializing STATUS.md for session $SESSION_ID${NC}"

    # Update the header
    sed -i "s/- \*\*Timestamp\*\*:.*/- **Timestamp**: $(date '+%Y-%m-%d %H:%M:%S')/" STATUS.md
    sed -i "s/- \*\*Session ID\*\*:.*/- **Session ID**: $SESSION_ID/" STATUS.md

    # Add to change log
    echo "" >> STATUS.md
    log_status "Session $SESSION_ID started"
}

# Run quality gates
run_quality_gates() {
    log "${BLUE}Running quality gates...${NC}"

    if ./scripts/quality-gate.sh >> "$LOG_FILE" 2>&1; then
        log "${GREEN}Quality gates passed${NC}"
        return 0
    else
        log "${RED}Quality gates failed${NC}"
        return 1
    fi
}

# Parse tasks from AGENTS.md
get_next_task() {
    # Find the first unchecked task in Priority 1 or Priority 2
    grep -n "^\s*[0-9]*\. \[ \]" AGENTS.md | head -1 | cut -d: -f1
}

get_task_description() {
    local line_num=$1
    sed -n "${line_num}p" AGENTS.md | sed 's/^[[:space:]]*[0-9]*\. \[ \] \*\*\(.*\)\*\*.*/\1/'
}

get_task_spec() {
    local line_num=$1
    # Look for spec path in the lines following the task
    sed -n "$((line_num+1)),$((line_num+5))p" AGENTS.md | grep -oP '\.claude/specs/[^`\s]+' | head -1
}

mark_task_complete() {
    local line_num=$1
    sed -i "${line_num}s/\[ \]/[x]/" AGENTS.md
}

mark_task_blocked() {
    local line_num=$1
    sed -i "${line_num}s/\[ \]/[B]/" AGENTS.md
}

# Execute a single task with Codex
execute_task() {
    local task_num=$1
    local task_desc=$2
    local task_spec=$3

    log "${BLUE}Executing task $task_num: $task_desc${NC}"
    log "Spec file: $task_spec"

    # Build the Codex prompt
    local prompt="You are implementing a task from AGENTS.md.

Task: $task_desc
Spec file: $task_spec

Instructions:
1. Read the spec file at $task_spec
2. Write failing tests for the acceptance criteria
3. Implement minimum code to pass tests
4. Run the test suite
5. If all tests pass, output TASK_COMPLETE
6. If blocked, output BLOCKED: <reason>

Follow the project constitution in CLAUDE.md. Do not make architectural decisions - flag those as blockers for Claude.

Begin by reading the spec file."

    # Run Codex with full-auto and timeout
    local output_file="$LOG_DIR/task_${task_num}_$SESSION_ID.log"

    if timeout $TASK_TIMEOUT codex exec "$prompt" \
        --full-auto \
        --model gpt-5.4-codex \
        2>&1 | tee "$output_file"; then

        # Check for completion signals in output
        if grep -q "TASK_COMPLETE" "$output_file"; then
            log "${GREEN}Task completed successfully${NC}"
            return 0
        elif grep -q "BLOCKED" "$output_file"; then
            local blocker=$(grep "BLOCKED:" "$output_file" | head -1 | sed 's/.*BLOCKED: //')
            log "${YELLOW}Task blocked: $blocker${NC}"
            return 2
        else
            log "${YELLOW}Task finished without clear completion signal${NC}"
            # Check if tests pass
            if npm test --if-present 2>/dev/null; then
                return 0
            else
                return 1
            fi
        fi
    else
        log "${RED}Task execution failed or timed out${NC}"
        return 1
    fi
}

# Update STATUS.md with task result
update_status() {
    local task_desc=$1
    local result=$2  # "completed", "blocked", "failed"
    local commit_hash=$3
    local notes=$4

    case $result in
        "completed")
            # Add to completed table
            sed -i "/^| (none yet) | - | - | - |$/d" STATUS.md
            sed -i "/^### Tasks Completed$/,/^### Tasks Blocked$/{
                /^| Task | Commit | Tests | Notes |$/a\\
| $task_desc | $commit_hash | PASS | $notes |
            }" STATUS.md
            log_status "Task '$task_desc' completed (commit $commit_hash)"
            ;;
        "blocked")
            sed -i "/^| (none yet) | - | - |$/d" STATUS.md
            sed -i "/^### Tasks Blocked$/,/^### Tasks Remaining$/{
                /^| Task | Blocker | Attempted Solutions |$/a\\
| $task_desc | $notes | See logs |
            }" STATUS.md
            log_status "Task '$task_desc' blocked: $notes"
            ;;
        "failed")
            log_status "Task '$task_desc' failed: $notes"
            ;;
    esac
}

# Commit changes for a completed task
commit_task() {
    local task_desc=$1

    git add -A
    if git diff --cached --quiet; then
        log "${YELLOW}No changes to commit${NC}"
        echo "no-changes"
    else
        local commit_msg="feat: $task_desc

Implemented by Codex overnight session $SESSION_ID

Co-Authored-By: OpenAI Codex <codex@openai.com>"

        git commit -m "$commit_msg"
        local hash=$(git rev-parse --short HEAD)
        log "${GREEN}Committed: $hash${NC}"
        echo "$hash"
    fi
}

# Main loop
main() {
    log "${GREEN}=========================================${NC}"
    log "${GREEN}   OVERNIGHT CODEX SESSION STARTING     ${NC}"
    log "${GREEN}   Session ID: $SESSION_ID              ${NC}"
    log "${GREEN}=========================================${NC}"

    init_status

    local tasks_completed=0
    local tasks_blocked=0
    local consecutive_failures=0

    for ((i=1; i<=MAX_TASKS; i++)); do
        log ""
        log "${BLUE}--- Task iteration $i of $MAX_TASKS ---${NC}"

        # Get next task
        local task_line=$(get_next_task)

        if [ -z "$task_line" ]; then
            log "${GREEN}No more tasks to process${NC}"
            log_status "ALL_TASKS_DONE"
            break
        fi

        local task_desc=$(get_task_description "$task_line")
        local task_spec=$(get_task_spec "$task_line")

        log "Found task: $task_desc"

        # Execute task
        execute_task "$i" "$task_desc" "$task_spec"
        local result=$?

        case $result in
            0)  # Success
                # Run quality gates
                if run_quality_gates; then
                    local commit_hash=$(commit_task "$task_desc")
                    mark_task_complete "$task_line"
                    update_status "$task_desc" "completed" "$commit_hash" "Automated implementation"
                    ((tasks_completed++))
                    consecutive_failures=0
                else
                    update_status "$task_desc" "failed" "" "Quality gates failed"
                    ((consecutive_failures++))
                fi
                ;;
            1)  # Failure
                update_status "$task_desc" "failed" "" "Implementation failed"
                ((consecutive_failures++))
                ;;
            2)  # Blocked
                mark_task_blocked "$task_line"
                update_status "$task_desc" "blocked" "" "Requires Claude review"
                ((tasks_blocked++))
                consecutive_failures=0  # Blocked doesn't count as failure
                ;;
        esac

        # Circuit breaker
        if [ $consecutive_failures -ge $MAX_CONSECUTIVE_FAILURES ]; then
            log "${RED}Circuit breaker triggered: $MAX_CONSECUTIVE_FAILURES consecutive failures${NC}"
            log_status "CIRCUIT_BREAKER: $consecutive_failures consecutive failures"
            break
        fi

        # Brief pause between tasks
        sleep 5
    done

    # Final summary
    log ""
    log "${GREEN}=========================================${NC}"
    log "${GREEN}         SESSION COMPLETE               ${NC}"
    log "${GREEN}=========================================${NC}"
    log "Tasks completed: $tasks_completed"
    log "Tasks blocked: $tasks_blocked"
    log "Session log: $LOG_FILE"

    # Update final metrics in STATUS.md
    sed -i "s/- Tasks attempted:.*/- Tasks attempted: $i/" STATUS.md
    sed -i "s/- Tasks completed:.*/- Tasks completed: $tasks_completed/" STATUS.md
    sed -i "s/- Tasks blocked:.*/- Tasks blocked: $tasks_blocked/" STATUS.md
    sed -i "s/- Total commits:.*/- Total commits: $tasks_completed/" STATUS.md
    sed -i "s/- \*\*Total runtime\*\*:.*/- **Total runtime**: $(date '+%H:%M:%S')/" STATUS.md

    log_status "Session ended. Completed: $tasks_completed, Blocked: $tasks_blocked"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v codex &> /dev/null; then
        echo -e "${RED}Error: codex CLI not found. Install with: npm install -g @openai/codex${NC}"
        exit 1
    fi

    if [ ! -f "AGENTS.md" ]; then
        echo -e "${RED}Error: AGENTS.md not found. Create it with task list first.${NC}"
        exit 1
    fi

    if [ ! -f "STATUS.md" ]; then
        echo -e "${RED}Error: STATUS.md not found.${NC}"
        exit 1
    fi

    if [ ! -f "./scripts/quality-gate.sh" ]; then
        echo -e "${RED}Error: quality-gate.sh not found.${NC}"
        exit 1
    fi
}

# Run
check_prerequisites
main
