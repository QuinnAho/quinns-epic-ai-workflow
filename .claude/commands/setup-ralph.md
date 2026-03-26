---
description: Install and configure RALPH for interactive Claude sessions
---

# RALPH Setup

RALPH (named after Ralph Wiggum) enables autonomous looping for interactive Claude Code sessions. It's used for **daytime work** when you want Claude to iterate on a problem without constant prompting.

> Note: Overnight automation uses Codex, not RALPH. RALPH is for interactive Claude sessions.

## Installation

Run this command in Claude Code:

```
/plugin marketplace add anthropics/ralph-wiggum
```

## Alternative: Community Version

Frank Bria's implementation has additional safety rails:
- Dual exit gates (completion + explicit EXIT_SIGNAL)
- Rate limiting (100 calls/hour)
- Circuit breaker pattern
- Comprehensive logging in `.ralph/`

```bash
git clone https://github.com/frankbria/ralph-claude-code ~/.ralph
```

## Configuration

After installing, RALPH is available via:

```
/ralph-loop "Your task description" --max-iterations 20 --completion-promise "DONE"
```

## Recommended Settings for This Workflow

Since Codex handles overnight grunt work, keep RALPH iterations low to control costs:

| Use Case | Max Iterations | Notes |
|----------|----------------|-------|
| Complex debugging | 10-15 | Claude's strength |
| Architectural exploration | 15-20 | Needs reasoning |
| Quick fixes | 5-10 | Should be fast |

## When to Use RALPH vs Codex

| RALPH (Claude) | Codex Overnight |
|----------------|-----------------|
| Complex debugging | Routine implementation |
| Architectural decisions | Spec-following tasks |
| Ambiguous requirements | Clear acceptance criteria |
| Interactive refinement | Fire-and-forget |
| Daytime work | Overnight automation |

## Verify Installation

After installing, test with:

```
/ralph-loop "Say hello and then say DONE" --max-iterations 3 --completion-promise "DONE"
```

Should complete in 1-2 iterations.
