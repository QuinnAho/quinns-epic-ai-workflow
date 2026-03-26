# A Day in an AI Agent

*A dual-agent semi-autonomous AI coding pipeline*

## Welcome to the Factory

Think of this workflow like a factory running two shifts.

The night shift (Codex, autonmous) works hard, they get a lot done. But it's dark out, they're tired, and they're cheap labor, they're pretty smart but nonetheless mistakes happen. They follow the work orders to the letter, bolt by bolt, but they won't notice if the blueprint itself was wrong.

The day shift (Claude, supervised) comes in each morning and inspects the work. They figure out what got done right, what got botched, and what the night crew should tackle next. They also help you tighten the blueprint before the next run. They're expensive and burn through their hours fast, so you don't want them tightening screws, you want them thinking. Architecture, judgment calls, quality checks.

In the evening, you, the manager, use Claude to help turn vague ideas into clear work orders, write up what you want done in `AGENTS.md`, hand them off, and go to bed.

Optionally, the local crew (Qwen models running on your machine) can handle grunt work for both shifts, fetching parts, carrying materials, so neither shift burns expensive hours on busywork.

If you do not want to use Qwen at all, skip the local crew. The workflow still works with just Codex and Claude.

**Target cost: ~$40/month** ($20 ChatGPT Plus + $20 Claude Pro + $100 student Codex credits)

## Run the Cycle

```bash
# Evening: queue tonight's work
vim AGENTS.md  # Add thin tasks with acceptance criteria

# Night shift: let Codex work through the queue
./scripts/overnight-codex.sh

# Morning handoff: review what the night shift left behind
claude
# Read the morning handoff in STATUS.md, then:
/review
```

## The Daily Rhythm

The loop is simple on purpose: the evening sets direction, the night shift does the grinding, the morning handoff restores context, and the day shift handles the parts that should not be left to a blind executor.

| Time | Lead | Role |
|------|------|------|
| Evening | You + Claude | Write specs, tighten acceptance criteria, and queue thin tasks in `AGENTS.md`. |
| Night Shift | Codex | Read the queue, implement against the spec, run tests and gates, commit passing work, and update `STATUS.md`. |
| Morning Handoff | Claude | Read the overnight results, review blockers and drift, and decide what should move forward. |
| Day Shift | Claude + You | Handle architecture, debugging, ambiguous requirements, and the next round of specs. |
| Background Crew | Optional local Qwen models | Take routine grunt work off the paid models whenever possible. |

## Directory Structure

```
project-root/
|-- CLAUDE.md                    # Project constitution (Claude reads)
|-- AGENTS.md                    # Tonight's queue for Codex
|-- STATUS.md                    # Morning handoff between Codex and Claude
|-- .claude/
|   |-- settings.json            # Hooks, MCP servers, model routing
|   |-- agents/                  # Claude subagent definitions
|   |-- commands/                # Claude slash commands
|   `-- specs/                   # Feature specifications
|-- scripts/
|   |-- overnight-codex.sh       # Overnight Codex runner
|   |-- quality-gate.sh          # Mechanical gates (Codex)
|   `-- judgment-gate.sh         # Judgment gates (Claude)
`-- src/                         # Your application code
```

## Setup

### Automated Setup (Recommended)

First copy the workflow files into your project root:

```powershell
# From your project root, clone and copy workflow files
git clone https://github.com/QuinnAho/quinns-epic-ai-workflow.git .ai-workflow

# Copy core files to project root (AI agents look here)
Copy-Item -Path ".ai-workflow\.claude" -Destination ".\" -Recurse
Copy-Item -Path ".ai-workflow\CLAUDE.md" -Destination ".\"
Copy-Item -Path ".ai-workflow\AGENTS.md" -Destination ".\"
Copy-Item -Path ".ai-workflow\STATUS.md" -Destination ".\"
Copy-Item -Path ".ai-workflow\scripts" -Destination ".\" -Recurse
Copy-Item -Path ".ai-workflow\docs" -Destination ".\" -Recurse

# Append to .gitignore (don't overwrite existing)
Get-Content ".ai-workflow\.gitignore" | Add-Content ".gitignore"

# Clean up
Remove-Item -Path ".ai-workflow" -Recurse -Force
```

Then run the actual dependency/bootstrap script from the project root.

Pick the mode you want:

```bash
chmod +x ./scripts/setup.sh

# Simplest setup: Codex + Claude only
./scripts/setup.sh --cloud-only

# Optional local crew: add Ollama + Qwen too
./scripts/setup.sh
```

`./scripts/setup.sh` is the command that installs and verifies the workflow dependencies:
- Checks `node`, `npm`, `git`, and optional `python3`
- Installs the OpenAI Codex CLI
- Installs Claude Code
- Configures Claude MCP servers
- Makes workflow scripts executable
- Creates `.env.example`
- Optionally installs Ollama and pulls the Qwen models
- Optionally installs LiteLLM for local model routing

Useful variants:

```bash
./scripts/setup.sh --cloud-only
./scripts/setup.sh --skip-ollama
./scripts/setup.sh --verify-only
./scripts/setup.sh --help
```

`--cloud-only` is the easiest path if you do not want local models. `--skip-ollama` is kept as a compatible alias.

If you want to enable the local crew later, install Ollama/Qwen, start the gateway, and then set your Claude environment to route subagent work locally:

```bash
./scripts/start-litellm.sh --bg
# then set CLAUDE_CODE_SUBAGENT_MODEL=qwen3.5:27b in your Claude environment/settings
```

If you are on Windows, run the shell script from WSL or Git Bash after copying the files with PowerShell.

Then customize `CLAUDE.md` with your project's stack, conventions, and forbidden patterns.

### Manual Setup

<details>
<summary>Click to expand manual steps</summary>

These are the manual equivalents of what `./scripts/setup.sh` automates.

If you do not want to use Qwen, skip the optional Ollama/LiteLLM steps entirely. Codex and Claude still run the workflow on their own.

#### 1. Optional: Install Ollama & Local Models

```powershell
# Install Ollama (download from https://ollama.com/download/windows)
# Or via winget:
winget install Ollama.Ollama

# Pull models
ollama pull qwen2.5-coder:32b    # Autocomplete
ollama pull qwen3.5:27b           # Implementation
```

#### 2. Install OpenAI Codex CLI

```powershell
npm install -g @openai/codex
codex auth  # Use ChatGPT Plus account
# If student: codex credits  # Verify $100 credits
```

#### 3. Install Claude Code

```powershell
npm install -g @anthropic-ai/claude-code
claude  # Use Claude Pro account
```

#### 4. Copy This Template

```powershell
git clone https://github.com/QuinnAho/quinns-epic-ai-workflow.git .workflow

# Copy to project root
Copy-Item -Path ".workflow\.claude" -Destination ".\" -Recurse
Copy-Item -Path ".workflow\CLAUDE.md" -Destination ".\"
Copy-Item -Path ".workflow\AGENTS.md" -Destination ".\"
Copy-Item -Path ".workflow\STATUS.md" -Destination ".\"
Copy-Item -Path ".workflow\scripts" -Destination ".\" -Recurse

Remove-Item -Path ".workflow" -Recurse -Force
```

#### 5. Configure MCP Servers

```powershell
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add github -- npx -y @modelcontextprotocol/server-github
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
claude mcp add eslint -- npx -y @eslint/mcp
claude mcp add playwright -- npx -y @anthropic-ai/mcp-playwright
claude mcp add desktop-commander -- npx -y @anthropic-ai/mcp-desktop-commander
```

</details>

## Starting From a Project Document

If you have a product brief, PRD, notes file, or brainstorming doc, start with **Claude**, not Codex.

Codex works best when `AGENTS.md` already contains small, testable tasks linked to concrete spec files. Claude is the better tool for turning a high-level document into:
- A project-specific `CLAUDE.md`
- One or more feature specs in `.claude/specs/`
- A first-pass task list in `AGENTS.md`

### Recommended Flow

1. Put your idea document somewhere in the repo, for example `docs/idea.md`
2. Start `claude`
3. Ask Claude to convert the document into specs before any implementation
4. Run `/analyze-spec <spec>` on each drafted spec
5. Update `AGENTS.md` with only the first 1-3 thin, executable tasks
6. Run `./scripts/overnight-codex.sh`

### Use Claude the Intended Way

Use the workflow entry points directly. Change the file path, but keep the shape of the command or prompt the same.

You usually should **not** ask for named subagents manually.

| Job | Use this |
|-----|----------|
| Existing repo adoption | `/adopt-workflow [path]` |
| Check a spec before implementation | `/analyze-spec .claude/specs/<name>.md` |
| Implement a spec interactively in Claude | `/implement .claude/specs/<name>.md` |
| Review overnight Codex work | `/review` |
| Validate finished work against the spec | `/validate .claude/specs/<name>.md` |
| Generate tests for a file or feature | `/test [file-or-feature]` |

### Copy-Paste Workflow Prompts

#### 1. Start from an idea document

Use this when the repo does **not** already have specs:

```text
Read docs/idea.md.
Create a project-specific CLAUDE.md and 2-3 feature specs in .claude/specs/ using the template.
Break the work into thin vertical slices with explicit acceptance criteria.
Do not implement code yet.
```

Then run:

```text
/analyze-spec .claude/specs/<spec-name>.md
```

#### 2. Adopt the workflow in an existing repo

Use this when the repo already has code, tests, CI, docs, or existing agent files:

```text
/adopt-workflow docs/architecture.md
```

Other examples:

```text
/adopt-workflow docs/idea.md
/adopt-workflow docs/product-brief.md
```

#### 3. Tighten one spec before implementation

Use this when a spec exists but is still loose:

```text
Read .claude/specs/auth-bootstrap.md.
Tighten ambiguous requirements.
Make acceptance criteria objectively testable.
Call out missing edge cases and open questions.
Do not implement code yet.
```

Then run:

```text
/analyze-spec .claude/specs/auth-bootstrap.md
```

#### 4. Turn a spec into tonight's queue

Use this before the night shift:

```text
Read .claude/specs/auth-bootstrap.md.
Update AGENTS.md with only the next 1-3 executable tasks.
Keep each task thin, testable, and safe for an overnight Codex run.
Do not add stretch goals.
```

#### 5. Let Claude implement one approved spec

Use this when you want Claude to run the full spec pipeline itself instead of waiting for the night shift:

```text
/implement .claude/specs/auth-bootstrap.md
```

#### 6. Review the morning handoff

Use this after an overnight run:

```text
/review
```

#### 7. Validate finished work against the spec

Use this after implementation:

```text
/validate .claude/specs/auth-bootstrap.md
```

#### 8. Generate tests for a specific target

Use this when you already know what file or feature needs better coverage:

```text
/test src/auth/user-service.ts
```

### Simple Rules

- Use one workflow step at a time.
- Use the slash command when one exists.
- Use plain prompts only for shaping specs, queues, and clarifications.
- Always point Claude at the exact file you want it to work on.

## Adopting This Workflow in an Existing Project

If the repo already has code, tests, CI, docs, or even an existing `CLAUDE.md` or `AGENTS.md`, start with **Claude** and treat the first pass like an integration job, not a greenfield setup.

If you want this packaged instead of pasting prompts manually, use:

```text
/adopt-workflow [optional-context-path]
```

Examples:

```text
/adopt-workflow docs/idea.md
/adopt-workflow docs/architecture.md
```

The goal is to make this workflow fit the repo that already exists:
- preserve project-specific rules
- merge with existing agent files instead of overwriting them
- generate the smallest useful specs and first queue
- avoid breaking local conventions, scripts, or CI

Use a prompt like this:

```text
Read this repository before making changes.

Inspect:
- the current codebase structure
- package manifests / build files
- test setup and CI config
- docs and architecture notes
- any existing CLAUDE.md, AGENTS.md, STATUS.md, or agent workflow files

Integrate "A Day in an AI Agent" into this repo without clobbering project-specific rules.

Tasks:
1. Summarize the existing development workflow, stack, and constraints.
2. Identify what should be preserved from any existing CLAUDE.md / AGENTS.md.
3. Propose how to merge this workflow into the repo with minimal disruption.
4. Create or update CLAUDE.md so it reflects the real stack, conventions, and forbidden patterns of this project.
5. Create or update .claude/specs/ with 1-3 thin specs for the smallest useful next slices.
6. Create or update AGENTS.md with only the next 1-3 executable night-shift tasks.
7. Create or update STATUS.md only if needed for the morning handoff format.
8. Reuse existing scripts, checks, and conventions where possible instead of inventing parallel ones.

Important constraints:
- Do not overwrite existing CLAUDE.md or AGENTS.md blindly; merge carefully.
- Do not add duplicate workflows if the repo already has equivalent automation.
- Do not implement product code yet unless I explicitly ask.
- Call out conflicts, ambiguities, or missing information before making architectural decisions.
- Use subagents or slash-command workflows if useful, but keep the result grounded in this repo's actual structure.

Output:
- a short integration plan
- proposed file changes
- the first night-shift queue
- open questions that need human judgment
```

After Claude drafts the merged specs and queue, use:

```text
/analyze-spec .claude/specs/<spec-name>.md
```

Then either:
- keep refining the integration interactively in Claude
- or let Codex take the first night shift with the new `AGENTS.md`

This repo packages that flow as `/adopt-workflow`, backed by the `workflow-integrator` subagent. If you want the same behavior outside this repo, the next step is promoting it into a global Claude or Codex skill.

## One Full Day

### Evening (15 min)
1. Update `AGENTS.md` with tonight's tasks
2. Link each task to a spec file in `.claude/specs/`
3. Define acceptance criteria
4. Run `./scripts/overnight-codex.sh`

### Night Shift (Automated)
- Codex reads AGENTS.md
- Processes tasks sequentially
- Commits after each passing task
- Updates STATUS.md
- Stops on circuit breaker (3 consecutive failures)

### Morning Handoff (30 min)
1. `claude` - Start Claude Code session
2. Read `STATUS.md` to see what the night shift left behind
3. `/review` - Run code review subagents
4. Review blocked tasks, make architectural decisions
5. Update AGENTS.md for next night

### Day Shift (As needed)
- Claude handles creative/ambiguous work
- Design new features
- Write specs
- Complex debugging with RALPH

## Slash Commands

| Command | Description |
|---------|-------------|
| `/review` | Morning handoff review of overnight Codex work |
| `/implement <spec>` | Full Claude implementation pipeline |
| `/test [file]` | Generate tests |
| `/analyze-spec <spec>` | Validate a specification |
| `/adopt-workflow [path]` | Merge this workflow into an existing repo and draft the first cycle |
| `/validate <spec>` | Verify implementation meets spec |
| `/setup-ralph` | Install RALPH for interactive sessions |
| `/ralph-loop "<task>"` | Run RALPH autonomous loop (after installing) |

## Quality Gates

### Mechanical (Codex Enforces)
- Tests pass
- Linter clean
- Types check
- Coverage threshold
- No secrets in code

### Judgment (Claude Enforces)
- Architectural coherence
- No spec drift
- No technical debt accumulation
- Solves the RIGHT problem

## Model Routing

| Agent | Task | Model |
|-------|------|-------|
| Codex | Implementation | GPT-5.4-Codex |
| Codex | Simple tasks | GPT-5.4-mini |
| Claude | Architecture | Opus |
| Claude | Subagents | Sonnet |
| Both | Grunt work | Qwen 3.5 27B (local, optional) |

## Cost Breakdown

| Component | Monthly |
|-----------|---------|
| ChatGPT Plus (Codex) | $20 |
| Claude Pro | $20 |
| Student credits | ~$0 amortized |
| Local models | $0 |
| GitHub (student) | $0 |
| **Total** | **~$40** |

## Files That Matter

- **CLAUDE.md**: Project constitution, stack versions, forbidden patterns
- **AGENTS.md**: Tonight's queue for Codex, with acceptance criteria and completion signals
- **STATUS.md**: The morning handoff, including overnight results, blockers, and metrics

## Troubleshooting

**Codex not completing tasks?**
- Check task descriptions are specific and unambiguous
- Ensure spec files exist at referenced paths
- Review `.codex-logs/` for error details

**Morning handoff missing context?**
- `STATUS.md` should have task summaries from the night shift
- Run `git log --oneline --since="12 hours ago"` to see commits

**Rate limits?**
- Codex drops to GPT-5.4-mini automatically
- Student credits help during 2x promo period
- If you use the local crew, route more work to local Qwen models
