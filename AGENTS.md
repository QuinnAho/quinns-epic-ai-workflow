# AGENTS.md - Codex Instruction File

This file is read by OpenAI Codex at the start of each overnight session. It contains the project constitution, current task list, and completion signals.

## Project Constitution

See `CLAUDE.md` for full architectural principles. Key rules for Codex:

### DO
- Follow specs exactly as written
- Write tests BEFORE implementation (TDD)
- Commit after each passing task
- Update STATUS.md after each task
- Run quality gates before committing
- Use GPT-5.4-mini for simple tasks to save rate limits

### DO NOT
- Make architectural decisions (flag for Claude)
- Deviate from spec without explicit instruction
- Skip tests to move faster
- Commit failing code
- Ignore linter errors
- Add features not in the spec

## Completion Signals

- `TASK_COMPLETE` - Current task finished, move to next
- `BLOCKED` - Cannot proceed, needs human/Claude intervention
- `ALL_TASKS_DONE` - All tasks in current list completed
- `RATE_LIMITED` - Hit rate limits, pause and retry

## Current Task List

<!-- Update this section each evening before starting the overnight loop -->

### Priority 1 (Must Complete Tonight)

1. [ ] **Task name here**
   - Spec: `.claude/specs/feature-name.md`
   - Acceptance criteria:
     - [ ] Criterion 1
     - [ ] Criterion 2
   - Tests required: Yes
   - Estimated complexity: Low/Medium/High

2. [ ] **Next task**
   - Spec: `.claude/specs/other-feature.md`
   - Acceptance criteria:
     - [ ] Criterion 1
   - Tests required: Yes
   - Estimated complexity: Medium

### Priority 2 (If Time Permits)

3. [ ] **Optional task**
   - Spec: `.claude/specs/nice-to-have.md`
   - Acceptance criteria:
     - [ ] Criterion 1
   - Tests required: Yes
   - Estimated complexity: Low

## Task Execution Protocol

For each task:

1. **Read** the spec file completely
2. **Write** failing tests for acceptance criteria
3. **Run** tests to confirm they fail
4. **Implement** minimum code to pass tests
5. **Run** full test suite + linter
6. **Run** `./scripts/quality-gate.sh`
7. **If pass**: Commit with descriptive message, update STATUS.md
8. **If fail**: Fix issues, repeat from step 5
9. **If blocked**: Update STATUS.md with blocker details, move to next task

## Blocker Handling

If you encounter a blocker:

1. Do NOT spend more than 15 minutes on a single issue
2. Document the blocker in STATUS.md:
   - What you tried
   - Error messages
   - Your hypothesis about the cause
3. Mark task as BLOCKED
4. Move to next task
5. Claude will review blockers in the morning

## Rate Limit Management

- Track remaining requests via response headers
- When below 20% capacity:
  - Switch to GPT-5.4-mini for simple tasks
  - Increase delay between requests
  - If below 5%, pause for 30 minutes

## Context Management

Codex has automatic context compaction. To help it work effectively:

- Keep each task focused and independent
- Reference file paths explicitly
- Don't assume context from previous tasks
- Each task should be completable in isolation

---

## Notes for Human

Update the "Current Task List" section each evening before running `./scripts/overnight-codex.sh`. Be specific:

- Link to spec files
- List concrete acceptance criteria
- Estimate complexity honestly
- Order by dependency (independent tasks first)

The more precise the task list, the more Codex can accomplish overnight.
