# Quinn's Epic AI Workflow

A dual-agent semi-autonomous AI coding pipeline using **OpenAI Codex** for overnight implementation and **Claude Code** for morning review/architecture, with local **Qwen models** for grunt work.

**Target cost: ~$40/month** ($20 ChatGPT Plus + $20 Claude Pro + $100 student Codex credits)

## Quick Start

```bash
# Evening: Update task list
vim AGENTS.md  # Add tasks with acceptance criteria

# Night: Start overnight Codex loop
./scripts/overnight-codex.sh

# Morning: Review with Claude
claude
# Read STATUS.md, then:
/review
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│   EVENING: Write specs, update AGENTS.md with task list    │
└─────────────────────────────┬───────────────────────────────┘
                              ▼
┌───────────────────────┐         ┌───────────────────────────┐
│   OVERNIGHT: CODEX    │         │   MORNING: CLAUDE CODE    │
│   (The Grinder)       │         │   (The Architect)         │
├───────────────────────┤         ├───────────────────────────┤
│ • Reads AGENTS.md     │         │ • Reads STATUS.md         │
│ • Executes tasks      │   ───►  │ • Runs review subagents   │
│ • Commits on pass     │         │ • Judgment quality gates  │
│ • Updates STATUS.md   │         │ • Updates AGENTS.md       │
│                       │         │                           │
│ ENFORCES:             │         │ ENFORCES:                 │
│ • Tests pass          │         │ • Architectural coherence │
│ • Linter clean        │         │ • No spec drift           │
│ • Types check         │         │ • Right problem solved    │
└───────────────────────┘         └───────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              LOCAL MODELS (Ollama + Qwen)                   │
│   70-80% of token volume for both agents                    │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
project-root/
├── CLAUDE.md                    # Project constitution (Claude reads)
├── AGENTS.md                    # Codex instruction file (task list)
├── STATUS.md                    # Handoff state between agents
├── .claude/
│   ├── settings.json            # Hooks, MCP servers, model routing
│   ├── agents/                  # Claude subagent definitions
│   ├── commands/                # Claude slash commands
│   └── specs/                   # Feature specifications
├── scripts/
│   ├── overnight-codex.sh       # Overnight Codex runner
│   ├── quality-gate.sh          # Mechanical gates (Codex)
│   └── judgment-gate.sh         # Judgment gates (Claude)
└── src/                         # Your application code
```

## Setup

### Automated Setup (Recommended)

```bash
git clone https://github.com/yourrepo/quinns-epic-ai-workflow
cd quinns-epic-ai-workflow
./scripts/setup.sh
```

This installs Ollama, Codex CLI, Claude Code, MCP servers, and configures everything.

### Manual Setup

<details>
<summary>Click to expand manual steps</summary>

#### 1. Install Ollama & Local Models (WSL2)

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:32b    # Autocomplete
ollama pull qwen3.5:27b           # Implementation
```

#### 2. Install OpenAI Codex CLI

```bash
npm install -g @openai/codex
codex auth  # Use ChatGPT Plus account
# If student: codex credits  # Verify $100 credits
```

#### 3. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude  # Use Claude Pro account
```

#### 4. Copy This Template

```bash
git clone https://github.com/yourrepo/quinns-epic-ai-workflow .workflow
cp -r .workflow/{.claude,CLAUDE.md,AGENTS.md,STATUS.md,scripts} .
```

#### 5. Configure MCP Servers

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add github -- npx -y @modelcontextprotocol/server-github
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
claude mcp add eslint -- npx -y @eslint/mcp
claude mcp add playwright -- npx -y @anthropic-ai/mcp-playwright
claude mcp add desktop-commander -- npx -y @anthropic-ai/mcp-desktop-commander
```

</details>

## Daily Workflow

### Evening (15 min)
1. Update `AGENTS.md` with tonight's tasks
2. Link each task to a spec file in `.claude/specs/`
3. Define acceptance criteria
4. Run `./scripts/overnight-codex.sh`

### Overnight (Automated)
- Codex reads AGENTS.md
- Processes tasks sequentially
- Commits after each passing task
- Updates STATUS.md
- Stops on circuit breaker (3 consecutive failures)

### Morning (30 min)
1. `claude` - Start Claude Code session
2. Read STATUS.md to see what happened
3. `/review` - Run code review subagents
4. Review blocked tasks, make architectural decisions
5. Update AGENTS.md for next night

### Daytime (As needed)
- Claude handles creative/ambiguous work
- Design new features
- Write specs
- Complex debugging with RALPH

## Slash Commands

| Command | Description |
|---------|-------------|
| `/review` | Morning review of overnight Codex work |
| `/implement <spec>` | Full Claude implementation pipeline |
| `/test [file]` | Generate tests |
| `/analyze-spec <spec>` | Validate a specification |
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
| Both | Grunt work | Qwen 3.5 27B (local) |

## Cost Breakdown

| Component | Monthly |
|-----------|---------|
| ChatGPT Plus (Codex) | $20 |
| Claude Pro | $20 |
| Student credits | ~$0 amortized |
| Local models | $0 |
| GitHub (student) | $0 |
| **Total** | **~$40** |

## Key Files

- **CLAUDE.md**: Project constitution, stack versions, forbidden patterns
- **AGENTS.md**: Task list for Codex, acceptance criteria, completion signals
- **STATUS.md**: Handoff state, overnight results, metrics

## Troubleshooting

**Codex not completing tasks?**
- Check task descriptions are specific and unambiguous
- Ensure spec files exist at referenced paths
- Review `.codex-logs/` for error details

**Claude missing overnight context?**
- STATUS.md should have task summaries
- Run `git log --oneline --since="12 hours ago"` to see commits

**Rate limits?**
- Codex drops to GPT-5.4-mini automatically
- Student credits help during 2x promo period
- Route more to local Qwen models
