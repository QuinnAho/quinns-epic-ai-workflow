#!/bin/bash

# Codex Coding Time Runner
# Runs Codex in a loop, processing tasks from AGENTS.md sequentially
# Updates STATUS.md after each task for the next autonomous run or manual checkpoint

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Configuration (can be overridden by complexity tier)
MAX_TASKS="${MAX_TASKS:-10}"
TASK_TIMEOUT="${TASK_TIMEOUT:-3600}"  # 60 minutes per task
MAX_CONSECUTIVE_FAILURES=3
RATE_LIMIT_PAUSE=1800  # 30 minutes
TASK_RETRYABLE_TOOL_RETRIES="${TASK_RETRYABLE_TOOL_RETRIES:-1}"
LOG_DIR=".codex-logs"
SANDBOX_DIR="sandbox"
SESSION_ID=$(date +%Y%m%d_%H%M%S)
CODEX_RUN_MODEL="${CODEX_RUN_MODEL:-gpt-5.4}"

# Optimization flags
ENABLE_EARLY_TERMINATION="${ENABLE_EARLY_TERMINATION:-1}"
SKIP_SELF_REVIEW="${SKIP_SELF_REVIEW:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create log and sandbox directories
mkdir -p "$LOG_DIR" "$SANDBOX_DIR"
LOG_FILE="$LOG_DIR/session_$SESSION_ID.log"
CODEX_LAUNCHER=(node "$PROJECT_ROOT/scripts/codex-cli.mjs")

# Load game-specific config if available
load_game_config() {
    local game_slug=$1
    local config_file="$SANDBOX_DIR/$game_slug/config.env"

    if [ -f "$config_file" ]; then
        source "$config_file"

        # Apply complexity-based overrides
        case "${complexity_tier:-3}" in
            1|2)
                CODEX_RUN_MODEL="${CODEX_RUN_MODEL_OVERRIDE:-gpt-5.4-mini}"
                MAX_TASKS="${MAX_TASKS_OVERRIDE:-5}"
                TASK_TIMEOUT="${TASK_TIMEOUT_OVERRIDE:-1800}"
                SKIP_SELF_REVIEW=1
                ;;
            3)
                CODEX_RUN_MODEL="${CODEX_RUN_MODEL_OVERRIDE:-gpt-5.4}"
                MAX_TASKS="${MAX_TASKS_OVERRIDE:-8}"
                ;;
            4|5)
                CODEX_RUN_MODEL="${CODEX_RUN_MODEL_OVERRIDE:-gpt-5.4}"
                MAX_TASKS="${MAX_TASKS_OVERRIDE:-12}"
                ;;
        esac

        log "Loaded config for $game_slug (tier ${complexity_tier:-?})"
    fi
}

# Check if game meets acceptance criteria (early termination)
check_early_termination() {
    local game_slug=$1

    if [ "$ENABLE_EARLY_TERMINATION" -ne 1 ]; then
        return 1
    fi

    if [ -z "$game_slug" ]; then
        return 1
    fi

    if node "$PROJECT_ROOT/scripts/check-game-done.mjs" "$game_slug" 2>/dev/null; then
        log "${GREEN}Game $game_slug meets acceptance criteria - enabling early termination${NC}"
        return 0
    fi

    return 1
}

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
    sed -n "$((line_num+1)),$((line_num+5))p" AGENTS.md | grep -oP 'specs/[^`\s]+' | head -1
}

get_task_slug() {
    local task_spec=$1

    if [ -z "$task_spec" ]; then
        return 1
    fi

    basename "$task_spec" .md
}

get_task_brief() {
    local task_spec=$1

    if [ -z "$task_spec" ]; then
        return 1
    fi

    local spec_name
    spec_name="$(basename "$task_spec" .md)"
    local brief_path="sandbox/$spec_name/idea.txt"

    if [ -f "$brief_path" ]; then
        echo "$brief_path"
        return 0
    fi

    return 1
}

mark_task_complete() {
    local line_num=$1
    sed -i "${line_num}s/\[ \]/[x]/" AGENTS.md
}

mark_task_blocked() {
    local line_num=$1
    sed -i "${line_num}s/\[ \]/[B]/" AGENTS.md
}

is_retryable_tool_failure_log() {
    local log_path=$1

    if [ ! -f "$log_path" ]; then
        return 1
    fi

    if grep -E -q 'writing outside of the project|rejected by user approval settings|Access is denied' "$log_path"; then
        return 1
    fi

    grep -E -q 'Failed to write file|Failed to read file to update|patch rejected|patch: failed|BLOCKED: .*tool failure|BLOCKED: .*apply_patch|BLOCKED: .*patch|BLOCKED: .*write' "$log_path"
}

# Execute a single task with Codex
execute_task() {
    local task_num=$1
    local task_desc=$2
    local task_spec=$3
    local task_brief=$4

    log "${BLUE}Executing task $task_num: $task_desc${NC}"
    log "Spec file: $task_spec"
    if [ -n "$task_brief" ]; then
        log "Brief file: $task_brief"
    fi

    # Build self-review instruction based on complexity
    local self_review_instruction
    if [ "$SKIP_SELF_REVIEW" -eq 1 ]; then
        self_review_instruction="8. For this simple game, skip the subagent self-review pass to save tokens. Do a quick manual check that the code works."
    else
        self_review_instruction="8. Before declaring completion, perform a self-review pass. Use code_reviewer and spec_validator for non-trivial work to review the implementation against the spec, future-forward constraints, tests, and likely regressions."
    fi

    # Build the Codex prompt
    local base_prompt="You are implementing a task from AGENTS.md.

Task: $task_desc
Spec file: $task_spec
Brief file: ${task_brief:-not provided}
Model: $CODEX_RUN_MODEL

Instructions:
1. Read the spec file at $task_spec if it exists. If this task is creating the spec and the file does not exist yet, create it.
2. Read the original game brief at ${task_brief:-the sandbox brief file if it exists}.
3. Inspect the current implementation and artifact before editing.
4. Write failing tests when practical. Reuse and extend the existing sandbox test harness in sandbox/<game-slug>/tests/ when it exists.
5. If the task is browser-visual and tests are not practical, add the smallest useful smoke check or document the limitation.
6. Implement the minimum change that moves the game toward a more playable state.
7. When the spec identifies likely follow-on systems, prepare the code for those future additions with light-weight seams, shared data models, or module boundaries, but do not overbuild.
$self_review_instruction
9. Fix any material findings from that self-review, or document the remaining limitation clearly in STATUS.md if it is intentionally deferred.
10. Run relevant checks and update STATUS.md with artifact status or blocker details when useful.
11. When creating a brand-new file, use `apply_patch` with `*** Add File:` and a repo-relative path. Do not use absolute filesystem paths in patch headers.
12. If an in-repo `apply_patch` write fails with `Failed to write file`, assume a patch-shape or file-creation-mode problem before assuming the directory is missing. Adjust the patch materially instead of re-probing the repo root.
13. Do not output BLOCKED for ordinary in-repo tool-format failures until you have tried at least 3 materially different fixes. Reserve BLOCKED for true boundary, approval, access-denied, or missing-input failures.
14. If the task is complete, output TASK_COMPLETE.
15. If blocked, output BLOCKED: <reason>.

Follow the project constitution in PROJECT.md. This repo is Codex-only. Do not wait for an external review step; perform the reviewer pass yourself before TASK_COMPLETE. Prefer browser-playable increments, delta-time-safe logic, and explicit follow-up notes.
Unless you are editing shared workflow files, keep game-specific HTML, code, and assets inside sandbox/<game-slug>/ and follow the artifact path defined by the spec.
When delegation helps, use the project-scoped custom agents in .codex/agents, especially spec_analyst, spec_architect, spec_developer, spec_tester, spec_validator, code_reviewer, and workflow_integrator.
Before completing visual tasks, consult the game-ux-polish skill to ensure player experience polish: no debug artifacts, proper feedback on hits/actions, smooth camera, and clean UI.

Begin by reading the available context and the spec."
    local prompt="$base_prompt"
    local attempt=1
    local max_attempts=$((TASK_RETRYABLE_TOOL_RETRIES + 1))

    while [ "$attempt" -le "$max_attempts" ]; do
        local output_file="$LOG_DIR/task_${task_num}_$SESSION_ID.log"
        if [ "$attempt" -gt 1 ]; then
            output_file="$LOG_DIR/task_${task_num}_retry${attempt}_$SESSION_ID.log"
        fi

        if timeout $TASK_TIMEOUT "${CODEX_LAUNCHER[@]}" exec "$prompt" \
            -C "$PROJECT_ROOT" \
            --full-auto \
            --model "$CODEX_RUN_MODEL" \
            2>&1 | tee "$output_file"; then

            if grep -q "TASK_COMPLETE" "$output_file"; then
                log "${GREEN}Task completed successfully${NC}"
                return 0
            elif grep -q "BLOCKED" "$output_file"; then
                local blocker=$(grep "BLOCKED:" "$output_file" | head -1 | sed 's/.*BLOCKED: //')
                if [ "$attempt" -lt "$max_attempts" ] && is_retryable_tool_failure_log "$output_file"; then
                    log "${YELLOW}Retrying after retryable tool blocker: $blocker${NC}"
                    attempt=$((attempt + 1))
                    prompt=$(cat <<EOF
$base_prompt

Previous attempt result:
- BLOCKED due to a retryable in-repo tool failure: $blocker

Retry instructions:
- Continue from the current workspace state instead of restarting discovery.
- Focus on repairing the failed tool step.
- Do not output BLOCKED for patch-shape, wrong add/update mode, or similar in-repo tool-format problems until you have tried at least 3 materially different fixes.
- Reserve BLOCKED for true project-boundary, approval, access-denied, or missing-human-input failures.
EOF
)
                    continue
                fi

                log "${YELLOW}Task blocked: $blocker${NC}"
                return 2
            else
                log "${YELLOW}Task finished without clear completion signal${NC}"
                if ./scripts/quality-gate.sh >> "$output_file" 2>&1; then
                    return 0
                else
                    return 1
                fi
            fi
        else
            if [ "$attempt" -lt "$max_attempts" ] && is_retryable_tool_failure_log "$output_file"; then
                log "${YELLOW}Retrying after retryable tool execution failure${NC}"
                attempt=$((attempt + 1))
                prompt=$(cat <<EOF
$base_prompt

Previous attempt result:
- Retryable in-repo tool failure during execution.

Retry instructions:
- Continue from the current workspace state instead of restarting discovery.
- Focus on repairing the failed tool step.
- Do not output BLOCKED for patch-shape, wrong add/update mode, or similar in-repo tool-format problems until you have tried at least 3 materially different fixes.
- Reserve BLOCKED for true project-boundary, approval, access-denied, or missing-human-input failures.
EOF
)
                continue
            fi

            log "${RED}Task execution failed or timed out${NC}"
            return 1
        fi
    done

    log "${RED}Task exhausted retryable tool retries${NC}"
    return 1
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
    local game_slug=$2

    git add -A
    if git diff --cached --quiet; then
        log "${YELLOW}No changes to commit${NC}"
        echo "no-changes"
    else
        local commit_prefix="workflow"
        if [ -n "$game_slug" ]; then
            commit_prefix="$game_slug"
        fi

        local commit_msg="$commit_prefix: $task_desc

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

    local current_game_slug=""

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
        local task_slug=$(get_task_slug "$task_spec" || true)
        local task_brief=$(get_task_brief "$task_spec" || true)

        # Load game-specific config on first task or when game changes
        if [ -n "$task_slug" ] && [ "$task_slug" != "$current_game_slug" ]; then
            current_game_slug="$task_slug"
            load_game_config "$task_slug"
        fi

        log "Found task: $task_desc"

        # Check for early termination (game already meets criteria)
        if [ "$tasks_completed" -ge 1 ] && check_early_termination "$task_slug"; then
            log "${GREEN}Early termination: $task_slug is playable, skipping remaining tasks${NC}"
            log_status "EARLY_TERMINATION: Game meets acceptance criteria"
            # Mark remaining tasks as skipped (optional)
            break
        fi

        # Execute task
        local result
        if execute_task "$i" "$task_desc" "$task_spec" "$task_brief"; then
            result=0
        else
            result=$?
        fi

        case $result in
            0)  # Success
                # Run quality gates
                if run_quality_gates; then
                    local commit_hash=$(commit_task "$task_desc" "$task_slug")
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
                update_status "$task_desc" "blocked" "" "Needs human follow-up"
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
    if ! "${CODEX_LAUNCHER[@]}" --version &> /dev/null; then
        echo -e "${RED}Error: codex CLI not available through scripts/codex-cli.mjs. Install with: npm install -g @openai/codex${NC}"
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
