# Building a semi-autonomous AI coding pipeline in 2026

**A dual-agent system using OpenAI Codex for overnight autonomous implementation and Claude Code for morning architecture review is the strongest architecture available today — and you can set it up in an afternoon.** The ecosystem has matured dramatically: Codex excels at sustained spec-following over long sessions (OpenAI demonstrated 25-hour continuous runs), while Claude Code brings superior architectural judgment for review and complex reasoning. Combined with Qwen 3.5 27B running locally via Ollama for grunt work, this stack delivers spec-driven, test-validated code while you sleep — then gets intelligent review when you wake up. A student on Windows/WSL with a 24GB GPU can run this system for **~$40/month** ($20 ChatGPT Plus + $20 Claude Pro, plus $100 student Codex credits), producing production-quality code overnight.

---

## The recommended architecture at a glance

The system follows a **dual-agent orchestration pattern** where OpenAI Codex handles sustained overnight autonomous implementation while Claude Code handles morning review, architecture, and complex reasoning. Local Qwen models handle routine grunt work for both agents. Two categories of quality gates enforce standards: **mechanical gates** (Codex-enforced during overnight runs) and **judgment gates** (Claude-enforced during morning review).

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR SPEC (CLAUDE.md)                 │
│         Constitution + Feature Specs + Acceptance        │
│                                                         │
│  AGENTS.md ← Codex reads this for overnight instructions │
│  STATUS.md ← Handoff state between Codex and Claude     │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌───────────────────────┐   ┌───────────────────────────────┐
│   OVERNIGHT: CODEX    │   │     MORNING: CLAUDE CODE      │
│   (The Grinder)       │   │     (The Architect)           │
├───────────────────────┤   ├───────────────────────────────┤
│                       │   │                               │
│  codex exec loop      │   │  Read STATUS.md + git log     │
│  ├── Read AGENTS.md   │   │  ├── Understand what happened │
│  ├── Process tasks    │   │  ├── Run review subagents:    │
│  │   sequentially     │   │  │   ├── security-reviewer    │
│  ├── Native subagent  │   │  │   ├── architecture-reviewer│
│  │   spawning (║)     │   │  │   ├── quality-reviewer     │
│  ├── Auto context     │   │  │   └── simplification-agent │
│  │   compaction       │   │  ├── Identify tech debt/drift │
│  ├── Commit on pass   │   │  ├── Complex debugging        │
│  ├── Update STATUS.md │   │  ├── Architectural decisions  │
│  └── Open PR on done  │   │  └── Update spec for next run │
│                       │   │                               │
│  ENFORCES:            │   │  ENFORCES:                    │
│  • Tests pass         │   │  • Architectural coherence    │
│  • Linter clean       │   │  • No spec drift              │
│  • Coverage threshold │   │  • No accumulated tech debt   │
│  • Types check        │   │  • Solves RIGHT problem       │
│                       │   │                               │
│  Can drop to GPT-5.4  │   │  Uses Opus for architecture   │
│  -mini for simple     │   │  Sonnet for subagent work     │
│  tasks to save rate   │   │  Qwen for grunt work (local)  │
│  limits               │   │                               │
└───────────────────────┘   └───────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│              LOCAL MODEL (Ollama + Qwen)                 │
│    Qwen 2.5 Coder 32B — autocomplete, simple edits     │
│    Qwen 3.5 27B — implementation, test generation       │
│    Qwen 3.5 35B-A3B — fast agentic tasks (112 tok/s)   │
│                                                         │
│    Handles 70-80% of token volume for BOTH agents       │
└─────────────────────────────────────────────────────────┘
```

**The daily workflow:**
1. **Evening**: Write/update specs, ensure AGENTS.md has clear task list
2. **Night**: Start Codex overnight loop (`./scripts/overnight-codex.sh`)
3. **Morning**: Claude Code reviews what was built, runs judgment gates
4. **Day**: Claude handles creative/ambiguous work, updates spec for next overnight run

---

## Codex handles the overnight grind

**OpenAI Codex** is the overnight workhorse — better at sustained spec-following over long sessions without context drift. OpenAI demonstrated 25-hour continuous runs maintaining coherence. For overnight autonomous implementation, this consistency matters more than peak reasoning ability.

**Why Codex for overnight, not Claude?** Three reasons:
1. **Sustained coherence**: Codex's automatic context compaction preserves understanding across very long sessions better than RALPH loops that accumulate context
2. **Native subagent spawning**: Up to 8 parallel subagents via the manager-subagent pattern for concurrent implementation
3. **Student economics**: $100 free credits via SheerID verification, plus the current 2x rate limit promo

**`codex exec`** is the key for non-interactive scripted runs. Unlike the interactive `codex` command, `exec` runs headlessly with full-auto approval — perfect for overnight bash loops:

```bash
codex exec "Implement task 1 per AGENTS.md spec. Run tests. If pass, commit and update STATUS.md." \
  --full-auto \
  --timeout 3600
```

**AGENTS.md is Codex's instruction file** (equivalent to CLAUDE.md for Claude Code). It contains the project constitution, current task list with acceptance criteria, and explicit completion signals. Codex reads this at session start.

**STATUS.md is the handoff file** between Codex and Claude. After each completed task, Codex updates STATUS.md with:
- Task completed and commit hash
- Tests that passed/failed
- Any blockers encountered
- Next task to attempt
- Time elapsed and tokens used

This lets Claude Code understand exactly what happened overnight without re-reading all the code.

**Codex runs in cloud sandboxes or locally via CLI in WSL.** For this pipeline, local WSL execution is preferred — it has full filesystem access and can run your actual test suite. Cloud sandboxes have network disabled.

**Rate limit management**: Codex should drop to **GPT-5.4-mini** for simple tasks (test generation, linting, simple edits) to preserve rate limits for complex implementation. The overnight script should track rate limit headers and back off appropriately.

---

## Claude Code handles the morning brain work

**Claude is just smarter** — better at architecture decisions, catching subtle bugs, understanding intent when specs are ambiguous, and making judgment calls about tradeoffs. It's the senior engineer reviewing what the junior (Codex) built overnight.

Claude Code v2.1.83 (current as of March 25, 2026) with **Claude Opus 4.6** and **1M token context window** on Pro plans is the review and architecture layer of this pipeline.

**The morning Claude Code session:**
1. Reads STATUS.md and `git log --oneline -20` to understand what Codex built
2. Runs code review subagents **in parallel**: security-reviewer, architecture-reviewer, quality-reviewer, simplification-agent
3. Identifies technical debt accumulation or spec drift
4. Does complex debugging and refactoring that requires real reasoning
5. Makes architectural decisions about ambiguous situations
6. Updates the spec (AGENTS.md) for the next overnight Codex run

**Reserve Opus for architecture decisions.** Use Sonnet for Claude's own subagent grunt work. Route simple tasks (test generation, linting, docs) to **Qwen 3.5 27B locally via Ollama**.

**The hooks system** provides 13 deterministic event hooks. The most critical for this pipeline:
- **PostToolUse** (auto-run linters and tests after every file edit)
- **Stop** (session end logging)
- **SubagentStop** (judgment gate verification)
- **PreToolUse** (block dangerous operations with exit code 2)

Configure hooks in `.claude/settings.json` — they receive JSON via stdin and control flow via exit codes.

**Subagents** run as specialized Claude instances with their own context windows, defined as Markdown files with YAML frontmatter in `.claude/agents/`. Each subagent gets a description field for automatic delegation, can inherit parent tools (including MCP servers), and runs in isolated context to prevent window pollution.

**Using Claude Code as a harness for local models works natively.** Point it at any Anthropic Messages API-compatible endpoint:

```bash
ANTHROPIC_AUTH_TOKEN=ollama \
ANTHROPIC_BASE_URL=http://localhost:11434 \
claude --model qwen3.5:27b
```

Set `CLAUDE_CODE_SUBAGENT_MODEL` to route subagent work to local models while keeping the orchestrator on cloud Opus/Sonnet. One critical performance fix: set `"CLAUDE_CODE_ATTRIBUTION_HEADER": "0"` in `~/.claude/settings.json` to prevent a header that invalidates KV cache and makes local inference **90% slower**.

---

## RALPH for interactive Claude sessions (secondary)

**RALPH** (named after Ralph Wiggum) remains useful for interactive Claude Code sessions during the day — when you want Claude to iterate on a problem without constant prompting. It's secondary to the Codex overnight loop but still valuable.

**When to use RALPH vs Codex overnight loop:**
- **RALPH**: Interactive daytime work, complex debugging sessions, architectural exploration
- **Codex overnight**: Fire-and-forget implementation, spec-following, parallel task execution

The **official Anthropic plugin** (`ralph-wiggum`) lives in the Claude Code plugin marketplace. Usage: `/ralph-loop "Your task" --max-iterations 20 --completion-promise "DONE"`. Install via `/plugin marketplace add anthropics/ralph-wiggum`.

**Frank Bria's community implementation** (`ralph-claude-code`) adds safety rails: dual exit gates, rate limiting at 100 calls/hour, circuit breaker pattern, and logging in `.ralph/`. With **566 tests at 100% pass rate**, this is the most robust option.

Keep iteration counts low (10-20) since you're paying Claude API rates. Use RALPH for complex problems that need Claude's reasoning, not routine implementation — that's what Codex does overnight for free (with student credits).

---

## Local models eliminate 70–80% of API costs

The local model landscape in March 2026 is dominated by the **Qwen family**, which outperforms everything else at every parameter count for coding tasks.

**For a 24GB GPU (RTX 3090/4090)** — the recommended consumer setup — three models cover all needs. **Qwen 2.5 Coder 32B** scores **92.7% on HumanEval** and excels at autocomplete and fill-in-the-middle tasks, fitting in ~20GB at Q4_K_M quantization. **Qwen 3.5 27B** (dense, ~16GB at Q4) achieves **72.4% on SWE-bench Verified** with native tool calling and 262K context — this ties GPT-5 mini and handles implementation, test generation, and multi-file refactoring. **Qwen 3.5 35B-A3B** is an MoE model hitting **112 tokens/second on an RTX 3090** while using only 3B active parameters per token — ideal for high-throughput agentic tasks where speed matters more than peak reasoning quality.

If you have 48GB+ of unified memory (Mac) or dual 24GB GPUs, **Qwen3-Coder-Next** (80B MoE, 3B active) is the crown jewel: **#1 on SWE-rebench at 64.6%**, beating Claude Opus 4.6 (58.3%) and GPT-5.2-medium (60.4%). It was specifically designed for agentic coding with direct tool-use support.

**Ollama is the correct inference engine** for this use case. One command to install, one command to run: `ollama pull qwen2.5-coder:32b`. It provides an **OpenAI-compatible API at `localhost:11434/v1`** that every coding tool supports, delivers within 13% of vLLM throughput for single-user workloads, and handles model management (pull, list, run) with Docker-like simplicity. For maximum VRAM efficiency, use Q4_K_M quantization (92% quality at 75% size reduction from FP16).

**WSL2 delivers 90–100% of native Linux inference speed** for GPU workloads. The critical setup steps: configure `.wslconfig` to allocate sufficient RAM (`memory=24GB`), keep all model files inside the WSL filesystem (not `/mnt/c/` — that's **3–5x slower**), and install the Windows NVIDIA driver (GPU passthrough works automatically with v580+). Do not install a separate CUDA driver inside WSL — the Windows driver provides the stub.

The model routing strategy for cost optimization:

| Task | Model | Cost |
|------|-------|------|
| Architecture, complex debugging | Claude Opus 4.6 (API) | $5/$25 per MTok |
| Feature implementation, code review | Claude Sonnet 4.6 (API) | $3/$15 per MTok |
| Routine implementation, test writing | Qwen 3.5 27B (local) | ~$0 |
| Autocomplete, simple edits | Qwen 2.5 Coder 32B (local) | ~$0 |
| Fast agentic grunt work | Qwen 3.5 35B-A3B (local) | ~$0 |

This routing alone drops typical daily costs from **$6–12/day to $2–4/day** by shifting 70–80% of token volume to local models.

---

## MCP servers wire everything together without custom code

The Model Context Protocol ecosystem has exploded to **7,260+ servers** with 97 million monthly SDK downloads. For this pipeline, six MCP servers form the essential stack.

**Context7** (by Upstash) is the single most-recommended MCP server across every developer survey. It injects **live, version-specific documentation** for 9,000+ libraries directly into the AI's context, eliminating hallucinated APIs — the #1 frustration in AI-assisted coding. Setup is one line in your MCP config: `npx -y @upstash/context7-mcp@latest`. Free to use, with optional API key for higher rate limits.

**GitHub MCP Server** provides full repository lifecycle management: create and merge PRs, manage issues, monitor Actions workflow runs, analyze build failures, re-run failed jobs, and handle code security alerts. The official server from GitHub supports OAuth or Personal Access Token auth, with toolset filtering to reduce context overhead: `--toolsets repos,issues,pull_requests,actions`.

**Desktop Commander** (5,300+ GitHub stars) goes far beyond basic filesystem access: terminal command execution, long-running process management, fuzzy file search, diff-based editing, and in-memory code execution. It replaces multiple simpler MCP servers with one capable tool.

**Playwright MCP** (by Microsoft, 30K+ stars) enables browser automation for UI testing. It runs entirely locally, takes accessibility snapshots, and integrates directly into Claude Code's testing workflow — critical for full-stack web app testing in the autonomous pipeline.

**Memory/Knowledge Graph MCP** provides persistent cross-session memory. The official `@modelcontextprotocol/server-memory` stores entities and relations in JSONL format. For more sophisticated needs, **Codebase Memory MCP** indexes entire codebases into a persistent knowledge graph via Tree-sitter AST parsing, supporting 66 languages with sub-millisecond queries — it processed the Linux kernel (28M lines) in 3 minutes.

**ESLint MCP** (`@eslint/mcp`) exposes ESLint rules directly to the AI, enabling lint-compliant code generation rather than post-hoc fixing.

---

## The alternatives worth knowing about

**OpenClaw** (247K+ GitHub stars, MIT license) is the most interesting orchestration layer. Originally a general-purpose AI agent, it can manage Claude Code and Codex sessions, autonomously run tests, capture errors via Sentry webhooks, resolve them, and open PRs — all controlled from WhatsApp, Telegram, or Slack. Its sub-project "Symphony" enables isolated autonomous implementation runs, and "Lobster" provides composable workflow pipelines. Think of it as a **control plane that delegates to Claude Code as a sub-agent**, letting you monitor and steer overnight runs from your phone. It's model-agnostic (supports Ollama for local models) and free beyond API costs.

**OpenHands** (formerly OpenDevin) is the most mature open-source autonomous coding platform. It provides Docker/Kubernetes-sandboxed environments, model-agnostic operation (Claude, GPT, local models), and a CLI similar to Claude Code. It can scale to thousands of parallel agent runs and claims to solve **87% of bug tickets same-day**. The SDK enables custom agent construction. If you want something more self-contained than Claude Code, OpenHands is the strongest alternative.

**OpenCode** (70K+ stars, MIT) is a Go-based Claude Code alternative with a beautiful TUI built on Bubble Tea. It supports every major provider plus Ollama for local models, has GitHub integration (mention @opencode in issues to trigger fixes), and offers a "GO plan" at $10/month for managed model access. It's the leading open-source terminal coding agent if you want to avoid Anthropic lock-in.

**OpenAI Codex** — now integrated as the overnight implementation layer in this dual-agent architecture (see above). Key specs: GPT-5.4-Codex with up to 8 parallel subagents, **$100 student credits** via SheerID, and demonstrated 25-hour continuous operation. Can run in cloud sandboxes or locally via CLI in WSL. Its strength is sustained spec-following without drift — that's why it handles overnight implementation while Claude handles morning review.

**Google Antigravity** is Google's agent-first IDE (VS Code fork) with a genuinely novel multi-agent "Mission Control" interface for dispatching 5+ parallel agents. It's free during public preview with generous Gemini 3 Pro usage. The browser subagent that launches Chrome, tests UI, and records walkthroughs is unique. Worth monitoring but still in preview with bugs.

**Aider** remains the gold standard for transparent, git-integrated AI pair programming. Every AI edit gets auto-committed with descriptive messages. It works with local models via Ollama (`aider --model ollama/qwen2.5-coder:32b`) and supports a three-tier model system: main model for complex tasks, weak model for commit messages, editor model for code changes. Not as autonomous as Claude Code + RALPH, but excellent for interactive sessions and maintains the best audit trail.

**Cursor** has evolved into a serious autonomous platform with Background Agents (isolated Ubuntu VMs that clone repos and push PRs) and Automations (always-on agents triggered by Slack, Linear, GitHub, or schedules). At $20/month for Pro, it's the most polished AI IDE experience but doesn't support local models well and has higher costs for background agent usage.

---

## Spec-driven development is the methodology that makes this work

The difference between autonomous coding that produces value and autonomous coding that produces technical debt is **specification quality**. Spec-Driven Development (SDD) has emerged as the standard methodology, and the tooling now supports it natively.

A good spec has four components. First, a **project constitution** (stored in `CLAUDE.md` at project root): stack versions, naming conventions, architectural principles, allowed/forbidden libraries, auth patterns, error handling standards, and explicit "do not do" rules. Claude Code reads this file at every session start. Second, **feature specifications** with precise behavior contracts, acceptance criteria with clear pass/fail conditions, integration points, and negative requirements (security constraints, performance bounds). Third, a **task decomposition** breaking features into independently implementable and testable chunks — "create user registration endpoint that validates email format" rather than "build authentication." Fourth, **dependency mapping** showing which tasks block which.

The **GitHub Spec Kit** (open source from GitHub) implements a 4-phase workflow: Specify → Plan → Tasks → Implement. It works with Claude Code, GitHub Copilot, and Gemini CLI. The **claude-sub-agent repo** (543 GitHub stars) provides a complete multi-agent pipeline with spec-analyst → spec-architect → spec-planner → spec-developer → spec-tester → spec-reviewer → spec-validator, with 3 quality gates and feedback loops.

Research from EPAM shows that safe delegation windows expanded from **10–20 minute tasks to multi-hour feature delivery** when specs include behavior contracts, architectural constraints, and task decomposition. The caveat from Martin Fowler's site: agents sometimes ignore spec details in brownfield codebases, and SDD overhead feels excessive for small features. Use it for features that justify upfront specification.

---

## Automated testing is the feedback signal that makes autonomy safe

Test-Driven AI Development works exceptionally well because tests give agents **binary, measurable exit criteria** — iterate until tests pass. The approach follows a modified Red-Green-Refactor cycle: the planning model generates a failing test expressing desired behavior, the implementation model writes minimum code to pass, then a refactoring pass cleans up while keeping tests green.

The critical insight from recent research: **mutation testing is essential** for validating AI-generated test quality. AI frequently produces tests with wrong expected values that happen to pass, over-mocking, missing edge cases, and tests that check implementation details rather than behavior. Running StrykerJS (JavaScript), mutmut (Python), or pitest (Java) with a target of **80%+ mutation score** on critical paths catches these problems. Track mutation scores, not just coverage — high coverage with low mutation scores means tests that lie.

Configure Claude Code hooks to enforce this automatically:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "npm run lint && npm test"
      }]
    }]
  }
}
```

This runs linting and tests after every file edit. Failed tests feed back into Claude's context as error signals, triggering the self-correction loop. Research on Test-Driven Agentic Development achieved **97.2% regression safety** with graph-based impact analysis.

---

## Code review subagents prevent the "army of juniors" problem

Ox Security's research found AI-generated code is "highly functional but systematically lacking in architectural judgment." GitClear data shows copy-pasted code rising while refactored/reorganized code approaches zero. The multi-agent code review pattern addresses this directly.

The strongest pattern deploys **9 parallel subagents**, each analyzing a specific aspect: test runner (runs relevant tests for changed files), linter/static analysis (collects IDE diagnostics), code reviewer (up to 5 concrete improvements ranked by impact), security reviewer (injection risks, auth issues, secrets), quality reviewer (complexity, dead code, duplication), dependency checker, architecture reviewer, documentation reviewer, and simplification agent. Each returns findings ranked by severity. The orchestrator combines results into Ready to Merge, Needs Attention, or Needs Work verdicts.

For cost efficiency, run the linter, test runner, and simplification agents on **local Qwen models** (they don't need frontier reasoning). Reserve the security reviewer and architecture reviewer for Claude Sonnet/Opus. The curated catalog at `VoltAgent/awesome-claude-code-subagents` provides **100+ pre-built subagent definitions** covering review, testing, documentation, and refactoring tasks.

---

## Additional tools that complement the pipeline

**Google Stitch** is a legitimate AI UI design tool (not vaporware) that generates production-ready frontend code from natural language or uploaded images. Its March 2026 update added an AI-native infinite canvas, voice design critiques, and multi-screen generation. The key feature for this pipeline: a **Stitch MCP server** connects directly to Claude Code, enabling a design-to-code pipeline — design in Stitch, export via MCP, generate code with Claude Code. Free during beta (350 generations/month).

**Claude-Mem** (community plugin by thedotmack) provides structured memory capture far beyond Claude Code's built-in auto-memory. It uses SQLite with FTS5 and Chroma vector embeddings for semantic search, AI-compressed session summaries, and layered context retrieval (search → review → fetch). Essential for multi-day projects where context from previous sessions matters. Install via `/plugin marketplace add thedotmack/claude-mem`.

**/dream** (Auto Dream) is a memory consolidation feature analogous to REM sleep — a background sub-agent that periodically reviews and reorganizes Claude's memory files, merging duplicates, updating stale entries, and resolving contradictions. Useful after 20+ sessions when memory notes become messy. Still experimental and rolling out gradually.

**Remotion** enables programmatic video generation using React components. The **Remotion MCP App** (`mcp-use/remotion-mcp-app`) creates videos inline during chat — AI writes React/Remotion code, the server compiles and renders. Useful if your workflow produces video artifacts (demos, changelogs, marketing).

---

## Step-by-step setup guide

**Prerequisites**: Windows with WSL2, NVIDIA GPU (24GB recommended — RTX 3090 at ~$750 used is the value sweet spot), 32GB system RAM, Node.js 18+, Python 3.10+, Git. Student email for Codex credits.

**Step 1: Install and configure Ollama in WSL2** (15 minutes)
```bash
# In WSL2
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:32b    # Autocomplete + simple edits
ollama pull qwen3.5:27b           # Implementation + test generation
# Verify GPU: ollama run qwen3.5:27b "Write a hello world in Python"
```

Configure `.wslconfig` in Windows: `memory=24GB`. Keep all files in WSL filesystem, not `/mnt/c/`.

**Step 2: Install OpenAI Codex CLI** (10 minutes)
```bash
npm install -g @openai/codex
codex auth  # Follow auth flow with ChatGPT Plus account
# Verify student credits: codex credits
```

**Step 3: Install Claude Code** (5 minutes)
```bash
npm install -g @anthropic-ai/claude-code
claude  # Follow auth flow with Claude Pro account
```

**Step 4: Configure local model routing for Claude** (10 minutes)
Add to `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0",
    "CLAUDE_CODE_SUBAGENT_MODEL": "qwen3.5:27b"
  }
}
```

**Step 5: Install essential MCP servers for Claude** (10 minutes)
```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add github -- npx -y @modelcontextprotocol/server-github
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
claude mcp add eslint -- npx -y @eslint/mcp
claude mcp add playwright -- npx -y @anthropic-ai/mcp-playwright
claude mcp add desktop-commander -- npx -y @anthropic-ai/mcp-desktop-commander
```

**Step 6: Install RALPH plugin for Claude** (5 minutes)
```bash
# In Claude Code session:
/plugin marketplace add anthropics/ralph-wiggum
```

**Step 7: Clone this workflow template** (5 minutes)
```bash
git clone https://github.com/yourrepo/quinns-epic-ai-workflow
cd quinns-epic-ai-workflow
```
Copy `.claude/`, `CLAUDE.md`, `AGENTS.md`, `STATUS.md`, and `scripts/` to your project root.

**Step 8: Create your project constitution** (30 minutes — this is the important part)
Edit `CLAUDE.md` with your: tech stack and versions, architectural principles, naming conventions, testing requirements, forbidden patterns, directory structure.

Edit `AGENTS.md` with your: current task list, acceptance criteria, completion signals.

**Step 9: Configure hooks for Claude's automated quality** (10 minutes)
Hooks are pre-configured in `.claude/settings.json`. Review and adjust paths if needed.

**Step 10: Run your first overnight Codex session**
```bash
# Evening: Start the overnight loop
./scripts/overnight-codex.sh

# Morning: Review with Claude
claude
# Then read STATUS.md and run /review
```

---

## Cost math for a student developer

| Component | Monthly cost |
|-----------|-------------|
| ChatGPT Plus (includes Codex access) | $20 |
| Claude Pro (for Claude Code) | $20 |
| Codex student credits (one-time $100) | ~$0/month amortized |
| Ollama + local models | $0 (electricity only) |
| GitHub (free for students) | $0 |
| Context7, MCP servers | $0 |
| **Total** | **~$40/month** |

**The student advantage:**
- **$100 Codex credits** via SheerID verification (one-time)
- **2x rate limit promo** currently active for Codex
- **GitHub Student Pack** includes Pro features free
- **Claude Pro at $20** is sufficient — Max ($100+) is overkill for this workflow

**Cost optimization strategies:**
1. **Codex for overnight grunt work**: Uses student credits, not subscription
2. **GPT-5.4-mini for simple Codex tasks**: Drop from full model for test generation, linting, simple edits to preserve rate limits
3. **Local Qwen models handle 70-80%**: Both Codex and Claude can route to Ollama
4. **Reserve Opus for architecture only**: Use Sonnet for Claude's subagent work
5. **Prompt caching on Claude**: 90% reduction on cached input tokens

When student credits run out, the $20 ChatGPT Plus subscription still includes Codex access — just with standard rate limits. The dual-agent architecture naturally load-balances: expensive Claude reasoning happens once per day (morning review), while Codex handles volume overnight.

---

## Conclusion

The autonomous coding pipeline is no longer theoretical. Every component exists as a cloneable repo or installable tool. **Codex (overnight) + Claude Code (morning) + Ollama/Qwen (grunt work) + spec-driven development** is the stack that maximizes capability while minimizing cost. The dual-agent architecture plays to each system's strengths: Codex's sustained spec-following for implementation grind, Claude's superior reasoning for review and architecture.

The critical success factors are not technical — they're methodological:
1. **Write good specs**: AGENTS.md must be unambiguous for Codex to follow overnight
2. **Enforce quality gates**: Mechanical gates (Codex) + Judgment gates (Claude)
3. **Use mutation testing**: Validate AI-generated test quality
4. **Morning review is mandatory**: Claude catches what Codex missed

For a student developer, this architecture costs ~$40/month and produces professional-quality code. The overnight Codex loop handles volume; the morning Claude session ensures quality. Local Qwen models eliminate 70-80% of what would otherwise be API costs.

Start with the overnight Codex script (`./scripts/overnight-codex.sh`), configure Claude Code for morning review, and write your first spec. The compounding effect of autonomous overnight implementation + intelligent morning review will transform your development velocity within a week.