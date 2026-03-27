# A Day in an AI Agent

*A dual-agent semi-autonomous AI coding pipeline*

## Welcome to the Factory

Think of this workflow like a factory running two shifts.

The night shift (Codex, autonomous) works hard, they get a lot done. But it's dark out, they're tired, and they're cheap labor, they're pretty smart but nonetheless mistakes happen. They follow the work orders to the letter, bolt by bolt, but sometimes they won't notice if the blueprint itself was wrong.

The day shift (Claude, supervised) comes in each morning and inspects the work. They figure out what got done right, what got botched, and what the night crew should tackle next. They also help you tighten the blueprint before the next run. They're expensive and burn through their hours fast, so you don't want them tightening screws, you want them thinking. Architecture, judgment calls, quality checks.

In the evening, you, the manager, use Claude to help turn vague ideas into clear work orders, write up what you want done in `AGENTS.md`, hand them off, and go to bed.

Optionally, the local crew (Qwen models running on your machine) can handle grunt work for both shifts, fetching parts, carrying materials, so neither shift burns expensive hours on busywork.

If you do not want to use Qwen at all, skip the local crew. The workflow still works with just Codex and Claude.

The workflow is simple: write clear specifications, let autonomous agents handle implementation, then use your judgment to review and guide the work forward.

## Two Ways to Work

### Option 1: Interactive (Claude)
```bash
claude
# First: Example: "Create a spec for user authentication"
# Then: /implement
```
Claude creates the spec, then implements it while you watch.

### Option 2: Autonomous (Codex)
```bash
# Evening: Queue work (manually or with Claude)
Open AGENTS.md              # Manual: add tasks yourself
# OR
claude                     # Agent: "Break down my specs into detailed tasks for AGENTS.md"

# Night: Let Codex work
./scripts/overnight-codex.sh

# Morning: Review with Claude
claude
/review
```
Codex implements overnight while you sleep, Claude reviews in the morning.

## Setup

### Start from a Doc
```bash
git clone https://github.com/QuinnAho/a-day-in-an-ai-agent.git .ai-workflow
cd .ai-workflow
./scripts/setup.sh --cloud-only
claude
/setup-workflow docs/idea.md
```

### Add to Existing Project
```bash
# Same setup as above, then:
claude
/adopt-workflow docs/architecture.md
```

## Daily Commands

| When | Command/Prompt | Purpose |
|------|----------------|---------|
| Start a feature | "Create a spec for [feature]" | Claude writes spec in `.claude/specs/` |
| Validate spec | `/analyze-spec <spec>` | Check spec before implementing |
| Queue for tonight | "Update AGENTS.md with tasks from [spec]" | Add tasks for Codex |
| Want it now | `/implement <spec>` | Claude does it interactively |
| Want it overnight | `./scripts/overnight-codex.sh` | Codex works while you sleep |
| Morning review | `/review` | Check what got built overnight |
| Need tests | `/test [file]` | Generate comprehensive tests |

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Your project rules - stack, patterns, constraints |
| `AGENTS.md` | Tonight's task queue for Codex |
| `STATUS.md` | Morning handoff between agents |
| `.claude/specs/` | Feature specifications |

---

<details>
<summary><b>How It Works (Technical Details)</b></summary>

### The Spec-Driven Pipeline

Everything starts with specifications. Claude helps you turn vague ideas into concrete specs with testable acceptance criteria. These specs live in `.claude/specs/` and define exactly what success looks like.

```
Idea → Claude writes spec → You review → Choose path:
├── Interactive: /implement → Claude builds it now
└── Autonomous: AGENTS.md → Codex builds overnight → /review
```

### What Each Agent Does

**Codex (Night Shift)**
- Reads AGENTS.md for tonight's tasks
- Follows specs exactly, test-first development
- Can spawn up to 8 parallel subagents
- Commits on each passing task
- Updates STATUS.md with results
- Runs mechanical quality gates (tests, linting, coverage)

**Claude (Day Shift)**
- Interactive implementation via `/implement`
- Morning review via `/review` with parallel subagents:
  - security-reviewer
  - architecture-reviewer
  - quality-reviewer
  - simplification-agent
- Makes judgment calls on ambiguous situations
- Updates specs and AGENTS.md for next cycle

### Quality Gates

**Mechanical (Codex)**
- Tests pass
- Linter clean
- Coverage met
- No secrets

**Judgment (Claude)**
- Architecture sound
- No spec drift
- Security reviewed
- Solves RIGHT problem

### The Daily Rhythm

```
Evening: You + Claude
├── Review STATUS.md from last night
├── Update specs based on learnings
├── Write tonight's AGENTS.md tasks
└── Each task links to a spec file

Night: Codex (autonomous)
├── codex exec loop reads AGENTS.md
├── Process tasks sequentially
├── Write failing tests first
├── Implement until tests pass
├── Commit if all gates pass
└── Update STATUS.md

Morning: Claude + You
├── Read STATUS.md handoff
├── /review launches parallel subagents
├── Identify issues and make decisions
├── Complex debugging if needed
└── Update AGENTS.md for tonight
```

</details>

<details>
<summary><b>Scripts & Setup Details</b></summary>

### Scripts
- `./scripts/setup.sh` - Install dependencies
- `./scripts/overnight-codex.sh` - Run autonomous loop
- `./scripts/copy-workflow.ps1` - Windows file copy
- `./scripts/copy-workflow.sh` - Unix file copy

### Slash Commands
- `/setup-workflow [doc]` - Initial setup
- `/adopt-workflow [path]` - Integrate into existing project
- `/analyze-spec <spec>` - Validate specifications
- `/implement <spec>` - Interactive implementation
- `/review` - Morning review of overnight work
- `/test [file]` - Generate tests
- `/validate <spec>` - Verify against spec

### Quick Prompts
```text
# Turn doc into specs:
Read docs/idea.md. Create CLAUDE.md, 2-3 specs in .claude/specs/, and initial AGENTS.md tasks.

# Queue tonight's work:
Read .claude/specs/<name>.md. Update AGENTS.md with next 1-3 thin tasks.
```

</details>

**Full documentation:**
- [AI Workflow Architecture](docs/AI_WORKFLOW_ARCHITECTURE.md) - Deep dive into the dual-agent architecture
- [Workflow Guide](docs/workflow-guide.md) - Detailed setup and usage
