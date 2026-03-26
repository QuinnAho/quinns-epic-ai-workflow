# Project Constitution

This repository provides a reusable template for a **dual-agent semi-autonomous AI coding pipeline** using OpenAI Codex (overnight implementation) and Claude Code (morning review/architecture), with local Qwen models for grunt work.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│   EVENING: Write specs, update AGENTS.md with task list    │
└─────────────────────────────┬───────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│   OVERNIGHT: Codex loop (./scripts/overnight-codex.sh)      │
│   - Reads AGENTS.md, executes tasks sequentially            │
│   - Commits on each passing task, updates STATUS.md         │
│   - Enforces mechanical gates (tests, lint, types)          │
└─────────────────────────────┬───────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│   MORNING: Claude Code review session                        │
│   - Reads STATUS.md + git log to understand what happened   │
│   - Runs judgment gates (architecture, spec drift, debt)    │
│   - Complex debugging, architectural decisions              │
│   - Updates AGENTS.md for next overnight run                │
└─────────────────────────────────────────────────────────────┘
```

### Dual-Agent Orchestration
- **Codex (Overnight)**: Sustained spec-following, parallel subagents, mechanical quality gates
- **Claude (Morning)**: Architecture review, judgment gates, complex reasoning, spec updates
- **Local Qwen Models**: 70-80% of token volume for both agents

## Stack & Versions

- **Runtime**: Node.js 18+ / Python 3.10+
- **Codex Models**: GPT-5.4-Codex (implementation), GPT-5.4-mini (simple tasks)
- **Claude Models**: Claude Opus 4.6 (architecture), Claude Sonnet 4.6 (subagent work)
- **Local Models via Ollama**:
  - Qwen 2.5 Coder 32B (autocomplete, simple edits)
  - Qwen 3.5 27B (implementation, test generation)
  - Qwen 3.5 35B-A3B (fast agentic tasks)

## Architectural Principles

1. **Spec-Driven Development**: All features start with detailed specifications in `.claude/specs/`
2. **Test-First**: Write failing tests before implementation
3. **Quality Gates**: Every phase passes through automated validation
4. **Cost Optimization**: Route 70-80% of work to local models
5. **Autonomous-Safe**: Auto Mode + hooks prevent destructive actions

## Directory Structure

```
project-root/
├── CLAUDE.md                    # This file - project constitution (Claude reads)
├── AGENTS.md                    # Codex instruction file (task list, acceptance criteria)
├── STATUS.md                    # Handoff state between Codex and Claude
├── .claude/
│   ├── settings.json            # Hooks and local configuration
│   ├── agents/                  # Claude subagent definitions
│   │   ├── spec-analyst.md
│   │   ├── spec-architect.md
│   │   ├── spec-developer.md
│   │   ├── spec-tester.md
│   │   ├── code-reviewer.md
│   │   └── spec-validator.md
│   ├── commands/                # Claude slash commands
│   │   ├── review.md            # Morning review workflow
│   │   ├── test.md
│   │   └── implement.md
│   └── specs/                   # Feature specifications
│       └── _template.md
├── scripts/
│   ├── overnight-codex.sh       # Overnight Codex loop runner
│   ├── quality-gate.sh          # Mechanical quality gates (Codex)
│   └── judgment-gate.sh         # Judgment quality gates (Claude)
└── src/                         # Your application code
```

## Naming Conventions

- **Files**: kebab-case (`user-auth.ts`, `api-client.py`)
- **Classes**: PascalCase (`UserService`, `AuthController`)
- **Functions/Methods**: camelCase (`getUserById`, `validateToken`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_RETRIES`, `API_BASE_URL`)
- **Subagents**: `spec-{role}.md` format

## Testing Requirements

1. **All features require tests before implementation**
2. **Minimum coverage**: 80% line coverage
3. **Mutation testing**: 80%+ mutation score on critical paths
4. **Test location**: Co-located with source (`*.test.ts`) or in `__tests__/`

## Code Review Standards

Each PR/feature passes through parallel review subagents:
- Security reviewer (injection, auth, secrets)
- Quality reviewer (complexity, duplication)
- Architecture reviewer (patterns, coupling)
- Test reviewer (coverage, mutation score)
- Simplification agent (unnecessary complexity)

## Forbidden Patterns

- **DO NOT** commit secrets, API keys, or credentials
- **DO NOT** use `any` type in TypeScript without justification
- **DO NOT** skip tests with `.skip()` in committed code
- **DO NOT** use `--force` flags without explicit approval
- **DO NOT** introduce circular dependencies
- **DO NOT** add dependencies without security review

## Error Handling

- Use typed errors with error codes
- Log errors with context (operation, inputs, stack)
- Graceful degradation over hard failures
- User-facing errors must be actionable

## Performance Constraints

- API response time: <200ms p95
- Build time: <60 seconds
- Test suite: <5 minutes
- Memory: No unbounded growth

## Security Requirements

- Validate all external input
- Use parameterized queries (no string concatenation for SQL)
- Sanitize output for XSS prevention
- Implement rate limiting on public endpoints
- Use secure defaults (HTTPS, secure cookies, CORS restrictions)

## Deployment

- All changes via PR with passing CI
- Feature flags for gradual rollout
- Rollback plan required for production changes

## Model Routing Strategy

### Codex (Overnight)
| Task Type | Model | Notes |
|-----------|-------|-------|
| Feature implementation | GPT-5.4-Codex | Primary overnight work |
| Test generation | GPT-5.4-mini | Save rate limits |
| Linting, simple edits | GPT-5.4-mini | Save rate limits |
| Complex debugging | GPT-5.4-Codex | When mini fails |

### Claude (Morning)
| Task Type | Model | Notes |
|-----------|-------|-------|
| Architecture decisions | Claude Opus 4.6 | Reserve for complex reasoning |
| Code review subagents | Claude Sonnet 4.6 | Parallel review execution |
| Spec writing/updates | Claude Opus 4.6 | Requires judgment |
| Simple fixes | Qwen 3.5 27B | Route to local |

### Local (Both Agents)
| Task Type | Model | Notes |
|-----------|-------|-------|
| Routine implementation | Qwen 3.5 27B | 70-80% of token volume |
| Autocomplete | Qwen 2.5 Coder 32B | Fast completions |
| Fast agentic work | Qwen 3.5 35B-A3B | 112 tok/s |

## Quality Gates

### Mechanical Gates (Codex Enforces Overnight)
- Tests pass
- Linter clean
- Type checking passes
- Coverage thresholds met
- No secrets in code

### Judgment Gates (Claude Enforces Morning)
- Architectural coherence
- No spec drift
- No accumulated technical debt
- Solves the RIGHT problem, not just stated problem
- Security review passed
- Simplification opportunities addressed

## Overnight Codex Configuration

- **Script**: `./scripts/overnight-codex.sh`
- **Max tasks per night**: 10
- **Timeout per task**: 60 minutes
- **Commit on**: Each passing task
- **Update**: STATUS.md after each task
- **Circuit breaker**: Stop after 3 consecutive failures

## Claude RALPH Configuration (Interactive Sessions)

- **Default max iterations**: 20
- **Completion signal**: `DONE`
- **Use for**: Complex debugging, architectural exploration
