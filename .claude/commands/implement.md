---
description: Implement a feature from a spec file
---

Implement a feature using the full spec-driven workflow.

## Arguments
- $ARGUMENTS: Path to the spec file (e.g., `.claude/specs/auth.md`)

## Workflow

Execute the full spec-driven implementation pipeline:

### Phase 1: Analysis
1. Launch spec-analyst subagent to validate the spec
2. If spec has issues, report them and stop
3. If spec is valid, proceed to architecture

### Phase 2: Architecture
1. Launch spec-architect subagent to design the solution
2. Create implementation plan with ordered tasks
3. Identify files to create/modify

### Phase 3: Test-First Development
1. Launch spec-tester subagent to create failing tests
2. Verify tests fail (red phase)

### Phase 4: Implementation
1. Launch spec-developer subagent for each task
2. Implement until tests pass (green phase)
3. Refactor while keeping tests green

### Phase 5: Review
1. Launch code-reviewer subagent
2. Address any critical/high issues
3. Re-run review until APPROVED

### Phase 6: Validation
1. Launch spec-validator subagent
2. Verify all acceptance criteria met
3. Confirm documentation updated

### Completion
Report:
- All files created/modified
- Test results and coverage
- Review status
- Validation result

If any phase fails, stop and report the blocking issue.
