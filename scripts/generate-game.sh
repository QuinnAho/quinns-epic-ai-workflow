#!/bin/bash

# Generate a detailed game spec from a short idea using Codex.
#
# Usage:
#   ./scripts/generate-game.sh
#   ./scripts/generate-game.sh "A top-down zombie survival game"
#   ./scripts/generate-game.sh --name "Zombie Siege" "A top-down zombie survival game"
#   ./scripts/generate-game.sh --file ideas/my-game.txt --name "Zombie Siege"
#   ./scripts/generate-game.sh "A dungeon crawler" dungeon-crawler-v0 --force

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"
SPEC_DIR="$PROJECT_ROOT/specs"
SANDBOX_DIR="$PROJECT_ROOT/sandbox"
CODEX_LAUNCHER=(node "$PROJECT_ROOT/scripts/codex-cli.mjs")

# Default config (will be overridden by complexity classifier)
CODEX_SPEC_MODEL="${CODEX_SPEC_MODEL:-gpt-5.4}"
CODEX_SPEC_TIMEOUT="${CODEX_SPEC_TIMEOUT:-1200}"
CODEX_SPEC_MAX_REPEAT_ERRORS="${CODEX_SPEC_MAX_REPEAT_ERRORS:-2}"
CODEX_SPEC_RETRYABLE_RETRIES="${CODEX_SPEC_RETRYABLE_RETRIES:-1}"
CODEX_SPEC_MAX_QUESTIONS="${CODEX_SPEC_MAX_QUESTIONS:-3}"

# Optimization flags
USE_COMPLEXITY_CLASSIFIER="${USE_COMPLEXITY_CLASSIFIER:-1}"
GAME_COMPLEXITY_TIER="${GAME_COMPLEXITY_TIER:-0}"  # 0 = auto-detect

usage() {
    echo "Usage:"
    echo "  ./scripts/generate-game.sh"
    echo "  ./scripts/generate-game.sh [--name \"<game name>\"] \"<game idea>\" [slug] [--force]"
    echo "  ./scripts/generate-game.sh --file <idea-file> [--name \"<game name>\"] [slug] [--force]"
    echo "  ./scripts/generate-game.sh --no-questions"
    echo "  ./scripts/generate-game.sh --no-agents-seed"
    echo ""
    echo "Running without arguments starts guided prompt mode."
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-48
}

# Classify game complexity and set optimal config
classify_and_configure() {
    local idea="$1"

    if [ "$USE_COMPLEXITY_CLASSIFIER" -ne 1 ]; then
        echo "Skipping complexity classification (disabled)"
        return 0
    fi

    if [ "$GAME_COMPLEXITY_TIER" -ne 0 ]; then
        echo "Using preset complexity tier: $GAME_COMPLEXITY_TIER"
        return 0
    fi

    echo "Analyzing game complexity..."
    local config_json
    config_json=$(node "$PROJECT_ROOT/scripts/classify-game-complexity.mjs" --json "$idea" 2>/dev/null || echo '{}')

    if [ "$config_json" = "{}" ]; then
        echo "Warning: Could not classify complexity, using defaults"
        return 0
    fi

    # Parse JSON config and set variables
    GAME_COMPLEXITY_TIER=$(echo "$config_json" | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).config.tier" 2>/dev/null || echo 3)
    local rec_model=$(echo "$config_json" | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).config.specModel" 2>/dev/null || echo "gpt-5.4")
    local rec_timeout=$(echo "$config_json" | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).config.specTimeout" 2>/dev/null || echo 1200)

    # Only override if not already set via environment
    if [ -z "${CODEX_SPEC_MODEL_OVERRIDE:-}" ]; then
        CODEX_SPEC_MODEL="$rec_model"
    fi
    if [ -z "${CODEX_SPEC_TIMEOUT_OVERRIDE:-}" ]; then
        CODEX_SPEC_TIMEOUT="$rec_timeout"
    fi

    local tier_name
    case "$GAME_COMPLEXITY_TIER" in
        1) tier_name="simple" ;;
        2) tier_name="basic" ;;
        3) tier_name="moderate" ;;
        4) tier_name="complex" ;;
        5) tier_name="ambitious" ;;
        *) tier_name="unknown" ;;
    esac

    echo "Complexity: Tier $GAME_COMPLEXITY_TIER ($tier_name)"
    echo "Using model: $CODEX_SPEC_MODEL, timeout: ${CODEX_SPEC_TIMEOUT}s"

    # Store config for later stages
    export GAME_COMPLEXITY_TIER
    export CODEX_SPEC_MODEL
    export CODEX_SPEC_TIMEOUT
}

titleize_slug() {
    echo "$1" | awk -F'-' '{
        for (i = 1; i <= NF; i++) {
            $i = toupper(substr($i, 1, 1)) substr($i, 2)
        }
        OFS = " "
        $1 = $1
        print
    }'
}

print_ui_header() {
    printf '\n'
    printf '%s\n' "============================================================"
    printf '%s\n' "                    Game Spec Generator"
    printf '%s\n' "============================================================"
    printf '%s\n' "This guided mode collects the game name and brief,"
    printf '%s\n' "lets Codex suggest a few useful clarification questions,"
    printf '%s\n' "and then writes the spec and starter queue."
    printf '\n'
}

prompt_for_game_name() {
    printf '%s\n' "Game Name"
    read -r -p "What should this game be called? " GAME_NAME
    printf '\n'
}

prompt_for_idea() {
    local line
    local idea_lines=()

    printf '%s\n' "Game Description"
    printf '%s\n' "Describe the game you want Codex to build."
    printf '%s\n' "Finish with an empty line."
    printf '\n'

    while IFS= read -r line; do
        if [ -z "$line" ]; then
            break
        fi
        idea_lines+=("$line")
    done

    IDEA_TEXT="$(printf '%s\n' "${idea_lines[@]}")"
    IDEA_TEXT="${IDEA_TEXT%$'\n'}"
}

print_summary() {
    printf '\n'
    printf '%s\n' "Summary"
    printf '%s\n' "-------"
    printf '%s\n' "Game name: $GAME_NAME"
    printf '%s\n' "Slug: $SLUG"
    printf '%s\n' "Spec file: $SPEC_PATH"
    printf '%s\n' "Game workspace: $GAME_DIR_REL"
    printf '%s\n' "Saved brief: $IDEA_RECORD_PATH"
    printf '\n'
    printf '%s\n' "Brief"
    printf '%s\n' "-----"
    printf '%s\n' "$IDEA_TEXT"
    printf '\n'
}

prompt_for_confirmation() {
    local response

    while true; do
        read -r -p "Proceed with this game intake? [Y]es / [E]dit / [N]o: " response
        case "${response,,}" in
            ""|"y"|"yes")
                return 0
                ;;
            "e"|"edit")
                return 1
                ;;
            "n"|"no")
                echo "Cancelled."
                exit 1
                ;;
            *)
                echo "Enter Y, E, or N."
                ;;
        esac
    done
}

refresh_paths() {
    SPEC_PATH="$SPEC_DIR/${SLUG}.md"
    GAME_DIR_REL="sandbox/${SLUG}"
    GAME_DIR="$PROJECT_ROOT/$GAME_DIR_REL"
    TARGET_ARTIFACT_REL="$GAME_DIR_REL/index.html"
    BASELINE_REF_PATH="$GAME_DIR/baseline-ref.txt"
    IDEA_RECORD_PATH="$GAME_DIR/idea.txt"
    CLARIFICATION_QUESTIONS_PATH="$GAME_DIR/clarification-questions.txt"
    CLARIFICATIONS_PATH="$GAME_DIR/clarifications.txt"
    INTAKE_PATH="$GAME_DIR/intake.md"
    SPEC_QUESTION_LOG_PATH="$GAME_DIR/spec-question-run.log"
    SPEC_CONTEXT_PATH="$GAME_DIR/spec-generation-context.md"
    SPEC_RUN_LOG_PATH="$GAME_DIR/spec-generation-run.log"
}

interactive_setup() {
    while true; do
        print_ui_header
        prompt_for_game_name
        prompt_for_idea

        if [ -z "$GAME_NAME" ]; then
            echo "Error: no game name provided"
            exit 1
        fi

        if [ -z "$IDEA_TEXT" ]; then
            echo "Error: no game idea provided"
            exit 1
        fi

        if [ -z "$SLUG" ]; then
            SLUG="$(slugify "$GAME_NAME")"
        fi

        if [ -z "$SLUG" ]; then
            SLUG="game-spec"
        fi

        refresh_paths
        print_summary

        if prompt_for_confirmation; then
            break
        fi

        GAME_NAME=""
        IDEA_TEXT=""
        SLUG=""
    done
}

write_default_clarifications() {
    cat > "$CLARIFICATIONS_PATH" <<EOF
No clarification questions were collected.
EOF
}

run_codex_exec() {
    local prompt="$1"
    local log_path="$2"
    shift 2

    # Send the prompt via stdin so larger deterministic context bundles do not hit Windows argv limits.
    if command -v timeout >/dev/null 2>&1; then
        printf '%s\n' "$prompt" | timeout "$CODEX_SPEC_TIMEOUT" "${CODEX_LAUNCHER[@]}" exec - \
            -C "$PROJECT_ROOT" \
            --full-auto \
            --model "$CODEX_SPEC_MODEL" \
            "$@" 2>&1 | tee "$log_path"
        return "${PIPESTATUS[1]}"
    fi

    printf '%s\n' "$prompt" | "${CODEX_LAUNCHER[@]}" exec - \
        -C "$PROJECT_ROOT" \
        --full-auto \
        --model "$CODEX_SPEC_MODEL" \
        "$@" 2>&1 | tee "$log_path"
    return "${PIPESTATUS[1]}"
}

build_spec_generation_context() {
    node "$PROJECT_ROOT/scripts/build-spec-generation-context.mjs" \
        --slug "$SLUG" \
        --game-name "$GAME_NAME" \
        --complexity-tier "$GAME_COMPLEXITY_TIER" > "$SPEC_CONTEXT_PATH"
}

count_repeat_errors() {
    local log_path="$1"
    if [ ! -f "$log_path" ]; then
        echo 0
        return 0
    fi

    grep -E -c 'writing outside of the project|rejected by user approval settings|Access is denied' "$log_path" || true
}

is_retryable_tool_failure_log() {
    local log_path="$1"
    if [ ! -f "$log_path" ]; then
        return 1
    fi

    if grep -E -q 'writing outside of the project|rejected by user approval settings|Access is denied' "$log_path"; then
        return 1
    fi

    grep -E -q 'Failed to write file|Failed to read file to update|patch rejected|patch: failed|BLOCKED: .*tool failure|BLOCKED: .*apply_patch|BLOCKED: .*patch|BLOCKED: .*write' "$log_path"
}

validate_spec_run() {
    local log_path="$1"

    if grep -q 'BLOCKED:' "$log_path"; then
        echo "Error: spec generation reported BLOCKED."
        echo "See: $log_path"
        exit 1
    fi

    if [ -f "$SPEC_PATH" ] && grep -q 'TASK_COMPLETE' "$log_path"; then
        return 0
    fi

    if [ -f "$SPEC_PATH" ] && [ -s "$SPEC_PATH" ]; then
        return 0
    fi

    echo "Error: spec generation did not leave a usable spec file."
    echo "See: $log_path"
    exit 1
}

guard_against_repeat_errors() {
    local log_path="$1"
    local phase_label="$2"
    local repeat_count

    repeat_count="$(count_repeat_errors "$log_path")"
    if [ "$repeat_count" -ge "$CODEX_SPEC_MAX_REPEAT_ERRORS" ]; then
        echo "Error: $phase_label hit repeated tool/path failures ($repeat_count)."
        echo "See: $log_path"
        exit 1
    fi
}

generate_clarification_questions() {
    local question_prompt

    question_prompt=$(cat <<EOF
You are helping with intake for this repository's deterministic game generator.

Use the bundled context below as authoritative for repo rules, the current game workspace, and the user intake.
Do not begin by re-reading PROJECT.md, AGENTS.md, STATUS.md, specs/_template.md, or scanning the sandbox workspace unless the context bundle is missing a critical fact.

Context bundle path: $SPEC_CONTEXT_PATH

$(cat "$SPEC_CONTEXT_PATH")

Decide whether the spec generator needs clarification from the user before drafting a first playable v0.

Return exactly one of these outputs:
1. NO_QUESTIONS
2. Up to $CODEX_SPEC_MAX_QUESTIONS short clarification questions, one per line, with no numbering, bullets, or commentary

Only ask questions that materially change the implementation spec for the first playable version.
Do not use subagents.
Do this in one pass.
If the same project-boundary, approval, or access-denied failure happens twice, stop and output NO_QUESTIONS.
Do not give up immediately for ordinary in-repo tool-format failures. Change approach materially before giving up.
EOF
)

    if ! run_codex_exec "$question_prompt" "$SPEC_QUESTION_LOG_PATH" \
        --output-last-message "$CLARIFICATION_QUESTIONS_PATH" >/dev/null; then
        return 1
    fi

    guard_against_repeat_errors "$SPEC_QUESTION_LOG_PATH" "Clarification generation"

    return 0
}

collect_clarifications() {
    local question_count=0
    local question
    local answer

    if [ "$ENABLE_QUESTIONS" -ne 1 ] || [ ! -t 0 ]; then
        write_default_clarifications
        return 0
    fi

    echo "Codex is checking whether a few clarification questions would improve the spec..."
    if ! generate_clarification_questions; then
        echo "Warning: Codex could not generate clarification questions. Continuing from the original brief."
        write_default_clarifications
        return 0
    fi

    mapfile -t CLARIFICATION_QUESTIONS < <(
        tr -d '\r' < "$CLARIFICATION_QUESTIONS_PATH" \
            | sed '/^[[:space:]]*$/d' \
            | sed -E 's/^[[:space:]]*([0-9]+[.)][[:space:]]*|[-*][[:space:]]*)//'
    )

    if [ "${#CLARIFICATION_QUESTIONS[@]}" -eq 0 ] || [ "${CLARIFICATION_QUESTIONS[0]}" = "NO_QUESTIONS" ]; then
        write_default_clarifications
        return 0
    fi

    printf '\n'
    printf '%s\n' "Codex Clarification Questions"
    printf '%s\n' "----------------------------"
    printf '%s\n' "Press Enter to leave an answer blank and let Codex make the smallest reasonable assumption."
    printf '\n'

    : > "$CLARIFICATIONS_PATH"
    for question in "${CLARIFICATION_QUESTIONS[@]}"; do
        question_count=$((question_count + 1))
        printf '%s\n' "$question_count. $question"
        read -r -p "> " answer
        if [ -z "$answer" ]; then
            answer="No additional answer provided. Make the smallest reasonable assumption."
        fi
        {
            printf 'Q%d: %s\n' "$question_count" "$question"
            printf 'A%d: %s\n\n' "$question_count" "$answer"
        } >> "$CLARIFICATIONS_PATH"
        printf '\n'
    done
}

write_intake_file() {
    cat > "$INTAKE_PATH" <<EOF
# Game Intake

## Game Name
$GAME_NAME

## Original Brief
$IDEA_TEXT

## Clarifications
$(cat "$CLARIFICATIONS_PATH")
EOF
}

record_baseline_ref() {
    local baseline_commit=""
    local baseline_branch=""

    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        baseline_commit="$(git rev-parse HEAD 2>/dev/null || true)"
        baseline_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    fi

    cat > "$BASELINE_REF_PATH" <<EOF
game_slug=$SLUG
captured_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
baseline_commit=${baseline_commit:-unknown}
baseline_branch=${baseline_branch:-unknown}
EOF
}

seed_agents_queue() {
    local queue_file
    local temp_agents

    if [ "$SEED_AGENTS" -ne 1 ] || [ ! -f "$PROJECT_ROOT/AGENTS.md" ]; then
        return 0
    fi

    queue_file="$(mktemp)"
    temp_agents="$(mktemp)"

    cat > "$queue_file" <<EOF
<!-- Queue generated by scripts/generate-game.sh for $GAME_NAME -->

### Priority 1 (Current Run)

1. [ ] **Generate the first playable $GAME_NAME prototype**
   - Spec: \`specs/$SLUG.md\`
   - Acceptance criteria:
     - [ ] Produces a local browser artifact under \`$GAME_DIR_REL/\` that loads without immediate crashes
     - [ ] Implements the core v0 loop defined in \`specs/$SLUG.md\`
     - [ ] Keeps the game-specific files inside \`$GAME_DIR_REL/\`
   - Tests required: Yes, extend the sandbox harness or add smoke checks
   - Estimated complexity: High

2. [ ] **Playtest and log the first failure inventory for $GAME_NAME**
   - Spec: \`specs/$SLUG.md\`
   - Acceptance criteria:
     - [ ] \`STATUS.md\` records the artifact path and launch method
     - [ ] The first visible gameplay failures are grouped by system
     - [ ] Gaps between the brief, spec, and artifact are documented clearly
   - Tests required: No
   - Estimated complexity: Medium

3. [ ] **Fix the highest-leverage issue from the first $GAME_NAME playtest**
   - Spec: \`specs/$SLUG.md\`
   - Acceptance criteria:
     - [ ] Resolves one major blocker to the playable core or records a concrete blocker
     - [ ] Updates tests or smoke checks when practical
     - [ ] Leaves the artifact in a better or more inspectable state than before
   - Tests required: Yes, when practical
   - Estimated complexity: Medium
EOF

    awk -v queue_file="$queue_file" '
        BEGIN {
            skip = 0
            while ((getline line < queue_file) > 0) {
                replacement = replacement line ORS
            }
            close(queue_file)
        }
        /^## Current Task List$/ {
            print
            printf "%s", replacement
            skip = 1
            next
        }
        /^## Task Execution Protocol$/ {
            skip = 0
        }
        skip == 0 {
            print
        }
    ' "$PROJECT_ROOT/AGENTS.md" > "$temp_agents"

    mv "$temp_agents" "$PROJECT_ROOT/AGENTS.md"
    rm -f "$queue_file"
}

GAME_NAME=""
IDEA_TEXT=""
SLUG=""
FORCE=0
ENABLE_QUESTIONS=1
SEED_AGENTS=1

if [ $# -eq 0 ]; then
    interactive_setup
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --name)
            if [ $# -lt 2 ]; then
                echo "Error: --name requires a value"
                exit 1
            fi
            GAME_NAME="$2"
            shift 2
            ;;
        --file)
            if [ $# -lt 2 ]; then
                echo "Error: --file requires a path"
                exit 1
            fi
            if [ ! -f "$2" ]; then
                echo "Error: idea file not found: $2"
                exit 1
            fi
            IDEA_TEXT="$(cat "$2")"
            if [ -z "$SLUG" ]; then
                SLUG="$(slugify "$(basename "$2")")"
            fi
            shift 2
            ;;
        --no-questions)
            ENABLE_QUESTIONS=0
            shift
            ;;
        --no-agents-seed)
            SEED_AGENTS=0
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        *)
            if [ -z "$IDEA_TEXT" ]; then
                IDEA_TEXT="$1"
            elif [ -z "$SLUG" ]; then
                SLUG="$1"
            else
                echo "Error: unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$IDEA_TEXT" ]; then
    echo "Error: no game idea provided"
    exit 1
fi

if [ -z "$SLUG" ]; then
    if [ -n "$GAME_NAME" ]; then
        SLUG="$(slugify "$GAME_NAME")"
    else
        SLUG="$(slugify "$IDEA_TEXT")"
    fi
fi

if [ -z "$SLUG" ]; then
    SLUG="game-spec"
fi

if [ -z "$GAME_NAME" ]; then
    GAME_NAME="$(titleize_slug "$SLUG")"
fi

if [ -z "$GAME_NAME" ]; then
    GAME_NAME="Game Spec"
fi

refresh_paths
mkdir -p "$SPEC_DIR" "$SANDBOX_DIR" "$GAME_DIR"

# Classify complexity and set optimal configuration
classify_and_configure "$IDEA_TEXT"

# Save complexity tier for later stages
echo "complexity_tier=$GAME_COMPLEXITY_TIER" >> "$GAME_DIR/config.env"

if [ -f "$SPEC_PATH" ] && [ "$FORCE" -ne 1 ]; then
    echo "Error: spec already exists at $SPEC_PATH"
    echo "Re-run with --force to overwrite it."
    exit 1
fi

if ! "${CODEX_LAUNCHER[@]}" --version >/dev/null 2>&1; then
    echo "Error: codex CLI not available through scripts/codex-cli.mjs."
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "Error: node is required to scaffold game tests."
    exit 1
fi

node "$PROJECT_ROOT/scripts/scaffold-game-tests.mjs" "$GAME_DIR_REL"

record_baseline_ref
printf '%s\n' "$IDEA_TEXT" > "$IDEA_RECORD_PATH"
build_spec_generation_context
collect_clarifications
write_intake_file
build_spec_generation_context

PROMPT=$(cat <<EOF
You are creating a detailed implementation spec for this repository's autonomous web-game workflow.

Use the bundled context below as authoritative for repo state, workflow rules, template shape, and current game workspace state.
Do not start by re-reading PROJECT.md, AGENTS.md, STATUS.md, specs/_template.md, or scanning the sandbox workspace unless the context bundle explicitly indicates something is missing or you are about to overwrite a file.

Context bundle path: $SPEC_CONTEXT_PATH

$(cat "$SPEC_CONTEXT_PATH")

Write the final spec to $SPEC_PATH.

Instructions:
1. Treat the bundled context as the source of truth for repo state, workflow rules, current game workspace files, and the intake.
2. Use the repository skills game-spec-generator, game-movement-systems, game-character-systems, game-environment-systems, game-gameplay-systems, game-ui-hud-systems, game-collision-systems, game-ai-systems, game-ux-polish, and library-selector when relevant.
3. Use the library-selector skill to determine if any CDN libraries should be included. For tier 1-2 games, prefer vanilla JS. For tier 3+ games, consider frameworks only if they genuinely reduce complexity.
4. Do not spend tokens rediscovering repo state that is already present in the bundle.
5. For simple games (tier 1-2: Snake, Pong, Breakout, Flappy Bird), do not use subagents. Write the spec directly in one pass.
6. For moderate games (tier 3), use at most one refinement pass total. If you use spec_analyst or spec_architect, do one narrow pass and then write the final spec. Do not loop.
7. For complex games (tier 4-5), you may use spec_analyst and spec_architect once each, but keep iteration minimal. Prefer a stable v0 over comprehensive feature coverage.
8. If the same project-boundary, sandbox-permission, approval, or access-denied failure happens twice, stop immediately and output BLOCKED: repeated boundary failure.
9. For ordinary in-repo tool failures such as patch shape, wrong add/update mode, or similar `apply_patch` formatting mistakes, do not block immediately. Make at least 3 materially different repair attempts before concluding the tool path is truly blocked.
10. Do not retry writes outside the repo root. The target spec path is inside this project.
11. The game workspace for this idea is $GAME_DIR_REL.
12. The default v0 browser artifact path should be $TARGET_ARTIFACT_REL unless the spec has a strong reason to use a nested entry path such as $GAME_DIR_REL/public/index.html or $GAME_DIR_REL/dist/index.html.
13. Keep all game-specific code, assets, and generated files inside $GAME_DIR_REL. Only shared workflow files should live outside that folder.
14. Baseline test files already exist in $GAME_DIR_REL/tests/. The spec should treat those as the default validation harness and expand them as pure logic is extracted.
15. Produce an implementation-ready v0 spec for a browser-playable game, not a vague design note.
16. Be explicit about workspace path, artifact path, run method, controls, camera, world structure, systems, failure modes, acceptance criteria, validation steps, and thin task breakdown.
17. Keep the scope realistic for autonomous implementation. Prefer a stable playable core over feature sprawl.
18. Treat the bundled intake snapshot as the source of truth. Keep the implemented game aligned with the user's name, brief, and clarification answers.
19. If any external libraries are recommended, include them in the Technical Architecture section with pinned CDN URLs.
20. Save the spec to $SPEC_PATH and overwrite any existing contents there if needed.
21. Because the bundled context already states whether the spec exists, use `apply_patch` with a repo-relative path. If the target spec does not exist, create it with `*** Add File: specs/$SLUG.md`; do not use an absolute filesystem path in the patch header.
22. If an in-repo `apply_patch` write fails with `Failed to write file`, treat it as a patch-shape or file-creation-mode problem first, not as evidence that the parent directory is missing. Change the patch materially before retrying.
23. Output TASK_COMPLETE when the spec is written.
EOF
)

echo "Generating spec at $SPEC_PATH"
echo "Game workspace: $GAME_DIR"
echo "Saved brief: $IDEA_RECORD_PATH"
echo "Saved context bundle: $SPEC_CONTEXT_PATH"
SPEC_PROMPT="$PROMPT"
SPEC_MAX_ATTEMPTS=$((CODEX_SPEC_RETRYABLE_RETRIES + 1))
SPEC_ATTEMPT=1

while true; do
    if ! run_codex_exec "$SPEC_PROMPT" "$SPEC_RUN_LOG_PATH"; then
        SPEC_RUN_EXIT=$?
    else
        SPEC_RUN_EXIT=0
    fi

    guard_against_repeat_errors "$SPEC_RUN_LOG_PATH" "Spec generation"

    if [ -f "$SPEC_PATH" ] && grep -q 'TASK_COMPLETE' "$SPEC_RUN_LOG_PATH"; then
        break
    fi

    if [ -f "$SPEC_PATH" ] && [ -s "$SPEC_PATH" ]; then
        break
    fi

    if [ "$SPEC_ATTEMPT" -lt "$SPEC_MAX_ATTEMPTS" ] && is_retryable_tool_failure_log "$SPEC_RUN_LOG_PATH"; then
        SPEC_ATTEMPT=$((SPEC_ATTEMPT + 1))
        echo "Retrying spec generation after retryable in-repo tool failure ($SPEC_ATTEMPT/$SPEC_MAX_ATTEMPTS)..."
        SPEC_PROMPT=$(cat <<EOF
$PROMPT

Previous attempt result:
- Retryable in-repo tool failure while writing or patching inside this repo.

Retry instructions:
- Continue from the current workspace state instead of restarting analysis.
- Focus on repairing the failed tool step.
- Do not output BLOCKED for patch-shape, wrong add/update mode, or similar in-repo tool-format problems until you have tried at least 3 materially different fixes.
- Reserve BLOCKED for true project-boundary, approval, access-denied, or missing-human-input failures.
EOF
)
        continue
    fi

    if [ "$SPEC_RUN_EXIT" -ne 0 ]; then
        echo "Error: spec generation failed."
        echo "See: $SPEC_RUN_LOG_PATH"
        exit 1
    fi

    validate_spec_run "$SPEC_RUN_LOG_PATH"
done
seed_agents_queue
if [ "$SEED_AGENTS" -eq 1 ]; then
    echo "Seeded AGENTS.md with a starter queue for $GAME_NAME"
fi
echo "Done: $SPEC_PATH"
