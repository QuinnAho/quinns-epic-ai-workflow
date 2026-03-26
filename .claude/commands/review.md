---
description: Morning review of overnight Codex work
---

# Morning Review Workflow

This command runs the full morning review workflow after an overnight Codex session.

## Step 1: Understand What Happened Overnight

First, read the handoff state:

```bash
cat STATUS.md
git log --oneline --since="12 hours ago"
```

Summarize:
- Tasks completed vs blocked
- Commits made overnight
- Any issues or blockers noted

## Step 2: Run Judgment Quality Gates

```bash
./scripts/judgment-gate.sh
```

This checks for:
- Blocked tasks requiring decisions
- Spec drift indicators
- Architectural concerns
- Technical debt accumulation

## Step 3: Run Code Review Subagents (Parallel)

Launch these subagents to analyze overnight changes:

1. **security-reviewer**: Injection risks, auth issues, secrets
2. **architecture-reviewer**: Patterns, coupling, design decisions
3. **quality-reviewer**: Complexity, duplication, code smells
4. **simplification-agent**: Over-engineering, unnecessary abstraction

Run in parallel for efficiency. Each returns findings ranked by severity.

## Step 4: Review Blocked Tasks

For each blocked task in STATUS.md:
- Read the blocker details
- Make architectural decision if needed
- Either resolve the blocker or update spec with clarification

## Step 5: Assess Spec Drift

Compare what was built to what was specified:
- Does the implementation match spec INTENT, not just literal words?
- Were edge cases handled appropriately?
- Would a user be satisfied with this?

## Step 6: Update AGENTS.md for Tonight

Based on the review:
1. Mark completed tasks as done
2. Add new tasks discovered during review
3. Clarify any ambiguous specs
4. Update acceptance criteria if needed

## Output Format

```
## Morning Review Summary

### Overnight Results
- Tasks completed: X
- Tasks blocked: X
- Commits: X

### Quality Gate Results
[Output from judgment-gate.sh]

### Code Review Findings
| Severity | Issue | Location | Recommendation |
|----------|-------|----------|----------------|
| ... | ... | ... | ... |

### Decisions Made
- [Architectural decision 1]
- [Clarification for blocked task]

### Updated for Tonight
- [New tasks added to AGENTS.md]
- [Specs clarified]

### Overall Verdict
GOOD TO CONTINUE / NEEDS FIXES FIRST / BLOCKED ON HUMAN
```
