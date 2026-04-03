# Project Constitution

This repository is a game-generation fork of **A Day in an AI Agent**. This branch turns that idea into a Codex-only pipeline focused on generating, repairing, and polishing browser games with a clean artifact trail.

The active game intake comes from the guided generator flow. Each game stores its original brief in `sandbox/<game-slug>/idea.txt`, any clarification answers in `sandbox/<game-slug>/clarifications.txt`, and a combined intake source in `sandbox/<game-slug>/intake.md`.

## Workflow Overview

```text
 sandbox/<game-slug>/idea.txt -> spec files -> AGENTS.md -> codex-coding-time.sh
                         -> sandbox/<game-slug>/ artifact -> playtest findings -> repair queue -> repeat
```

The active loop is:

1. Run `./scripts/generate-game.sh` to collect the game name and brief
2. Let the same script gather a few Codex-generated clarification answers when they materially improve the first playable spec
3. Generate or refine a spec with `./scripts/generate-game.sh`, which also scaffolds baseline tests in `sandbox/<game-slug>/tests/`
4. Start from the seeded starter queue in `AGENTS.md`
5. Run `./scripts/codex-coding-time.sh`
6. Serve or inspect the resulting browser artifact with `./scripts/run-game.sh`
7. Record failures in `STATUS.md`
8. Queue targeted repairs and run again
9. When the game is finished, run `node ./scripts/finalize-game-release.mjs <game-slug> --apply` to archive the trail and reset everything outside that game workspace to `HEAD`

## Mission Priorities

1. Produce a playable browser artifact, not just passing code
2. Keep the artifact easy to run locally
3. Record failures clearly enough that the next run can fix them
4. Prefer simple, durable game systems over flashy but unstable systems
5. Preserve a clean repo and a visible before/after story for the experiment

## Stack And Target

- Runtime: modern browser, with Node.js 18+ only for tooling when needed
- Rendering target: Three.js or equivalent browser-friendly rendering stack
- Primary agent model: GPT-5.4
- Budget model: GPT-5.4-mini for simple or repetitive tasks

## Directory Conventions

- `AGENTS.md`: current autonomous task queue
- `STATUS.md`: state log between Codex sessions and playtest passes
- `PROJECT.md`: this constitution file
- `.codex/config.toml`: project-scoped Codex configuration
- `.codex/agents/`: Codex custom agents that replace the old workflow roles
- `.agents/skills/`: repository skills for Codex-native workflow orchestration
- `specs/`: implementation specs for generated and repaired games
- `sandbox/`: generated game workspaces, one directory per game slug
- `sandbox/<game-slug>/idea.txt`: original per-game brief collected by the generator
- `sandbox/<game-slug>/clarifications.txt`: user answers to Codex-generated intake questions
- `sandbox/<game-slug>/intake.md`: combined intake source used during spec generation
- `sandbox/<game-slug>/tests/`: reusable built-in test harness for smoke checks and extracted game logic
- `scripts/codex-cli.mjs`: repo-local Codex CLI launcher for stable automation entry on Windows and Unix-like environments
- `scripts/generate-game.sh`: opens a guided terminal prompt, records the brief in the sandbox workspace, gathers Codex-generated clarification answers when needed, creates a detailed implementation spec, and seeds the starter queue
- `scripts/run-game.sh`: serves the current browser artifact locally
- `scripts/codex-coding-time.sh`: main autonomous runner
- `scripts/finalize-game-release.mjs`: writes a release bundle inside `sandbox/<game-slug>/release/` and restores everything outside that game workspace to git `HEAD`
- `scripts/scaffold-game-tests.mjs`: creates baseline built-in tests for each sandboxed game
- `scripts/run-game-tests.mjs`: runs sandbox game tests with Node's built-in test runner
- `scripts/quality-gate.sh`: mechanical checks
- `scripts/judgment-gate.sh`: manual follow-up gate for deciding the next repair loop

Each generated game should live under `sandbox/<game-slug>/`.

Acceptable game artifact layouts:

- `sandbox/<game-slug>/index.html`
- `sandbox/<game-slug>/game/index.html`
- `sandbox/<game-slug>/public/index.html`
- `sandbox/<game-slug>/dist/index.html`

New generated games should not be written at repo root. A single-file HTML game is acceptable when the spec requires it, but it should still live under `sandbox/<game-slug>/`.

## Architectural Principles

1. **Playability First**
   - A rough game that loads and can be controlled is more valuable than elegant code with no artifact.

2. **Separate Input, Simulation, And Rendering**
   - Keep player input, world updates, AI logic, and rendering distinct enough to debug and fix independently.

3. **Use Delta Time Everywhere**
   - Movement, cooldowns, animation steps, and AI timing must not depend on monitor refresh rate.

4. **Single Source Of Truth For Layout**
   - The level layout, collision representation, and minimap should derive from the same underlying data where possible.

5. **Collision Must Prevent Wall Penetration**
   - The camera or player controller should stop before crossing solid geometry.

6. **AI Must Respect World Geometry**
   - Enemies should not move through walls just because the chase logic is naive.

7. **Avoid Per-Frame Garbage**
   - Do not create avoidable objects in hot update loops when reuse is practical.

8. **Prefer Boring Geometry Over Ambitious Content**
   - Simple boxes, planes, and data-driven rooms are acceptable if they produce a stable game loop.

9. **Future-Ready, Not Overbuilt**
   - When the spec already identifies likely next systems, prepare small extension seams now.
   - Prefer shared data models, stable file boundaries, and explicit TODO notes over speculative framework-building.

10. **Leave A Repair Trail**
   - Every run should leave enough notes, artifact paths, and failure descriptions for the next run to continue cleanly.

## Implementation Standards

- File names: kebab-case
- Classes: PascalCase
- Functions: camelCase
- Constants: SCREAMING_SNAKE_CASE
- Keep comments short and high-signal
- Prefer small modules unless the spec explicitly requires a single-file artifact
- Document entry files and run commands whenever a runnable artifact changes
- Keep game-specific files inside the assigned `sandbox/<game-slug>/` workspace unless a shared workflow file must be updated
- When future phases are already known, add only the minimum structural prep needed to avoid a rewrite later

## Testing And Verification

- Write automated tests when the logic can be isolated meaningfully
- Every generated game should keep its test files in `sandbox/<game-slug>/tests/`
- Use Node's built-in test runner as the default workflow test harness unless a stronger project-specific harness exists
- For browser-visible tasks, smoke checks are acceptable when unit tests would add little signal
- If no formal test harness exists, use a deterministic check that still proves progress when possible
- `./scripts/quality-gate.sh` should run before a commit
- Use `code_reviewer` and `spec_validator` as the default self-review pass before considering a non-trivial task complete
- A task is not complete until the artifact path and current launch method are recorded in `STATUS.md`

## Game-Specific Quality Signals

Treat these as first-class concerns when generating or repairing the game:

- pointer lock enters and exits cleanly
- WASD and mouse look feel responsive
- collisions stop the player before wall penetration
- enemy motion respects walls or waypoints
- level layout is readable and coherent
- minimap matches the actual world
- lighting is readable, not flat or unusably dark
- no obvious console spam or runaway allocations

## Forbidden Patterns

- Frame-rate dependent movement
- Game state updates hidden inside the render function
- Camera movement with no collision margin in a walled environment
- Separate hand-authored minimap data that can drift from the world
- Creating new vectors, geometries, or materials every frame without justification
- Writing a new game artifact at repo root instead of inside `sandbox/<game-slug>/`
- Shipping a "complete" task with no way to run or inspect the artifact
- Solving blockers with placeholder text instead of a real note in `STATUS.md`

## Mechanical Gates

- Linting passes when linting exists
- Tests pass when tests exist
- Type checks pass when TypeScript exists
- No obvious secrets in code
- The current artifact can still be opened or located

## Human Checkpoint

Human review is not part of the active implementation loop, but the workflow must leave enough information for a quick manual checkpoint:

- current artifact path or URL
- current launch command
- known gameplay failures
- blocked tasks that need intervention
- next repair tasks

## Model Routing Strategy

| Task Type | Model | Notes |
|-----------|-------|-------|
| Core implementation | GPT-5.4 | Primary autonomous work |
| Small edits and cleanup | GPT-5.4-mini | Save rate limits |

## Autonomous Session Configuration

- Main runner: `./scripts/codex-coding-time.sh`
- Max tasks per run: 10
- Timeout per task: 60 minutes
- Commit on: passing task with a runnable or improved artifact
- Stop condition: 3 consecutive failures

## Default Decision Rules

- If a task is ambiguous, choose the smallest option that preserves progress
- If a spec is missing, create it only when the task explicitly calls for that
- If the artifact is broken, fix the load path before polishing secondary systems
- If a gameplay issue is visible but hard to automate, document it clearly and queue the repair

