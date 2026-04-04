# Spec Generation Context

Use this context bundle as authoritative for spec generation and clarification intake.
Do not begin by re-analyzing repo-wide files when this bundle already contains the needed state.

## Active Game
- Game name: dungeon baseline-v1
- Game slug: dungeon-baseline-v1
- Complexity tier: 5/5
- Spec path: specs/dungeon-baseline-v1.md
- Game workspace: sandbox/dungeon-baseline-v1/
- Default artifact path: sandbox/dungeon-baseline-v1/index.html
- Default test harness: sandbox/dungeon-baseline-v1/tests/

## Workflow Contract
- This repo is a Codex-only workflow for generating and repairing browser games.
- Each game stays inside sandbox/<game-slug>/ unless a shared workflow file must be edited.
- Acceptable artifact layouts are sandbox/<game-slug>/index.html, game/index.html, public/index.html, or dist/index.html.
- Prefer the smallest playable v0 over speculative architecture or feature sprawl.
- Movement, cooldowns, animation, and AI timing must use delta time.
- Collision should stop the player before wall penetration and AI should respect world geometry.
- Keep the world layout, collision, and minimap data aligned from a shared source of truth when relevant.
- Reuse and extend sandbox/<game-slug>/tests/ when logic can be tested; otherwise add the smallest useful smoke check.
- Record the artifact path and launch method in STATUS.md once implementation begins.
- For non-trivial implementation work, self-review with code_reviewer and spec_validator before declaring completion.
- Completion signals are TASK_COMPLETE, BLOCKED, ALL_TASKS_DONE, and RATE_LIMITED.

## Existing Shared State
### STATUS Snapshot
```text
- **Timestamp**: not started
- **Session ID**: none
- **Entry file**: not recorded
- **Launch command**: not recorded
- **Last known result**: No active game checkpoint recorded
- **Notes**: Update this section after the next meaningful task or playtest pass.
```

## Spec Template Outline
- ## Overview
- ### Game Concept
- ### Success Condition
- ## Design Goals
- ## Non-Goals
- ## Forward Plan
- ### Likely Follow-On Systems
- ### Prepare Now
- ### Avoid For Now
- ## Player Experience
- ### Camera And Controls
- ### Core Loop
- ### Win / Lose Conditions
- ## World And Environment
- ### World Structure
- ### Environment Systems
- ### Source Of Truth
- ## Entities
- ### Player
- ### Enemies / NPCs
- ## Gameplay Systems
- ### Required Systems
- ### Interaction Rules
- ## UI And Feedback
- ### Required UI
- ### Feedback
- ## Technical Architecture
- ### Rendering
- ### Update Model
- ### Performance Constraints
- ### Browser Constraints
- ## Validation And Failure Inventory
- ### Acceptance Criteria
- ### Expected Failure Modes To Watch For
- ### Verification Method
- ## Task Breakdown

## Game Workspace Snapshot
- Workspace exists: yes
- Existing spec file: no
- No artifact candidates found yet.

### Workspace Files (depth <= 2)
- baseline-ref.txt
- clarification-questions.txt
- clarifications.txt
- config.env
- idea.txt
- intake.md
- spec-generation-context.md
- spec-question-run.log
- tests/
- tests/logic.test.mjs
- tests/smoke.test.mjs

### Test Files
- No test files found.

### Baseline Reference
```text
game_slug=dungeon-baseline-v1
captured_at=2026-04-03T20:40:20Z
baseline_commit=9e14c01fef22facb04b18e86df41a86b3a7dbb40
baseline_branch=ai-game-gen-experiment
```

## Relevant Git Status
- ## ai-game-gen-experiment...origin/ai-game-gen-experiment
-  M PROJECT.md
-  M STATUS.md
- ?? sandbox/dungeon-baseline-v1/

## Intake Snapshot
### idea.txt
```text
Build a 3D first-person dungeon game in a single HTML file using Three.js. The player explores interconnected rooms using WASD + mouse look with pointer lock. Rooms are connected by corridors. The dungeon has torch lighting with flickering point lights and fog. The player has health and a simple attack (click to swing). Enemies patrol rooms and chase the player when in range. Collision detection prevents the player and enemies from walking through walls. There's a 2D minimap overlay in the corner showing rooms, the player position, and enemy positions. The player collects keys to unlock doors. Include a HUD showing health and key count.
```

### clarifications.txt
```text
No clarification questions were collected.
```

### intake.md
```text
# Game Intake

## Game Name
dungeon baseline-v1

## Original Brief
Build a 3D first-person dungeon game in a single HTML file using Three.js. The player explores interconnected rooms using WASD + mouse look with pointer lock. Rooms are connected by corridors. The dungeon has torch lighting with flickering point lights and fog. The player has health and a simple attack (click to swing). Enemies patrol rooms and chase the player when in range. Collision detection prevents the player and enemies from walking through walls. There's a 2D minimap overlay in the corner showing rooms, the player position, and enemy positions. The player collects keys to unlock doors. Include a HUD showing health and key count.

## Clarifications
No clarification questions were collected.
```

