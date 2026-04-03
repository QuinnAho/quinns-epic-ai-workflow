# Game Specification: Snake Game

## Overview

**Spec ID**: GAME-SNAKE-001
**Status**: Refined
**Game Workspace**: `sandbox/snake-game/`
**Target Artifact**: `sandbox/snake-game/index.html`
**Default Test Harness**: `sandbox/snake-game/tests/`
**Run Method**: From the repo root, run `bash ./scripts/run-game.sh sandbox/snake-game/index.html`

### Game Concept
Snake Game is a browser-playable top-down 3D version of classic Snake. The player steers a growing snake around a single bounded arena rendered with simple 3D geometry, collects food to increase score and length, and survives by avoiding perimeter walls and its own body. The 3D presentation should make the board more readable and tactile, not change the core rules.

### Success Condition
The v0 is successful when the artifact loads from `sandbox/snake-game/index.html`, the player can start a run with keyboard input, the snake advances on a deterministic grid-based simulation tick, food spawns and can be eaten to grow the snake and score, wall and self-collision end the run cleanly, and the player can restart without reloading the page.

---

## Design Goals

- Ship a stable classic Snake loop with deterministic movement and responsive queued turns.
- Present the board as a clean top-down 3D scene without sacrificing readability or testability.
- Keep one canonical board-state model so simulation, rendering, collision, and tests all derive from the same data.

## Non-Goals

- No enemies, combat, AI opponents, multiplayer, or level progression in v0.
- No wraparound mode, random obstacles, power-ups, or procedural board generation.
- No mobile controls, online leaderboard, or heavyweight engine abstraction.

## Forward Plan

### Likely Follow-On Systems
- Optional speed scaling or difficulty presets once the core loop is stable.
- Optional obstacle layouts or alternate arenas that still use the same board-state model.
- Optional local best-score persistence or lightweight presentation polish.

### Prepare Now
- Keep the snake rules in pure logic modules that Node tests can import directly.
- Centralize board dimensions, tick duration, camera settings, and color values in a small config module.
- Represent the world as integer grid cells so rendering positions, collision, and future obstacle cells all use the same source of truth.
- Make food spawning accept an injected RNG or candidate index in tests so logic coverage stays deterministic.

### Avoid For Now
- Do not build a generalized entity-component system or framework for a single-loop v0.
- Do not add interpolation-heavy animation, camera transitions, or shader work that complicates deterministic gameplay.
- Do not introduce future-only systems such as AI, level progression, or minimap overlays beyond a clean board model and config object.

---

## Player Experience

### Camera And Controls
- **Perspective**: Fixed top-down 3D board view with a shallow perspective camera angled down at the arena center. The entire playable board must remain visible without camera motion during normal play.
- **Input Scheme**: Keyboard only for v0. Support `WASD` and arrow keys for cardinal turns. Support `Space`, `Enter`, or `R` to restart after a finished run.
- **Expected Feel**: Crisp, deterministic, arcade-like. Input should be forgiving through a one-turn queue, but must not allow illegal double-turn exploits.
- **Pointer Lock / Mouse Capture**: Not required.

### Core Loop
1. Start from a ready screen showing the board, controls, and score at zero.
2. Press a direction key to begin the run and steer the snake one cell per simulation tick.
3. Collect food to increase score and length by one segment.
4. Navigate the tighter board state until the snake clears the board or dies on a wall or body collision.
5. Restart immediately from the end-state overlay without refreshing the page.

### Win / Lose Conditions
- **Win**: Occupy every playable cell so no valid food spawn remains. Show a `Board Cleared` end state and allow restart.
- **Lose**: Move the head outside the playable board or into a non-vacating snake body cell.
- **Retry Flow**: After win or loss, freeze simulation, show the end overlay with final score and length, and reset the run when the player presses `Space`, `Enter`, or `R`.

---

## World And Environment

### World Structure
- **Layout Model**: Single square arena board using discrete grid cells. Default config should target a `20 x 20` playable cell area.
- **Generation Model**: Hand-authored via config constants, not procedural. The starting snake position, initial direction, board size, and camera framing should be deterministic.
- **Traversal Constraints**: No wraparound. The perimeter is bounded by solid board edges and visible low walls. The snake can only move in the four cardinal directions and advances exactly one cell per simulation tick.

### Environment Systems
- Use a simple floor plane or tiled board with clearly readable grid boundaries.
- Use perimeter wall meshes or border markers so the loss boundary is obvious in 3D, even though collision is resolved from board coordinates rather than mesh intersections.
- Render food as a visually distinct pickup that sits on a single cell and remains readable against the board.
- Use bright, low-risk lighting: one ambient light plus one directional or hemisphere light is enough. The scene should not rely on darkness or shadows to create depth.

### Source Of Truth
- **World layout**: A board-state object containing width, height, snake segment cell list, occupied-cell lookup, current direction, queued direction, food cell, score, move count, and run state.
- **Collision**: Resolve collision from integer cell occupancy in the same board-state object, not from rendered mesh overlap checks.
- **Navigation overlays**: No separate minimap is required in v0 because the entire board is already visible. Any future overlay must derive from the same board-state data.

---

## Entities

### Player
- **Abilities**: Start a run, steer the snake up/down/left/right, and restart after the run ends.
- **State**:
  - Run state: `ready`, `running`, `won`, `lost`
  - Snake segments: ordered head-to-tail list of grid cells
  - Direction: current move direction plus one queued next direction
  - Score, food eaten, and current length
  - Simulation accumulator and tick metadata
- **Starting Configuration**:
  - Initial snake length: `3`
  - Default board start: centered on the board
  - Default facing direction: east
  - Recommended initial cells on a `20 x 20` board: head at `(10, 10)`, then `(9, 10)` and `(8, 10)`
- **Movement Rules**:
  - Use a fixed simulation tick of approximately `140 ms` per move as the default v0 target.
  - The first valid direction input from `ready` should start the run.
  - At most one next direction may be queued between ticks.
  - Reject immediate 180-degree reversals while the snake length is greater than one.
  - Movement must remain frame-rate independent by using delta time to feed a fixed-step simulation.
- **Growth Rules**:
  - If the next head cell contains food, the snake grows by preserving the tail on that step, score increases by `1`, and a new food cell is chosen from unoccupied cells.
  - If no unoccupied cell remains after growth, the run transitions to `won`.
- **Failure Modes To Avoid**:
  - frame-rate dependent movement
  - multiple turns applied within one tick
  - illegal reverse turns causing instant self-collision
  - render position desync from simulation cells
  - restart leaving stale snake or timer state behind

### Enemies / NPCs
- **Types**: None in v0.
- **Behaviors**: Not applicable.
- **Navigation Rules**: Not applicable.
- **Failure Modes To Avoid**:
  - Do not invent enemy or AI systems for this version.
  - Do not treat food spawning as an AI system; it is a board utility function.

---

## Gameplay Systems

### Required Systems
- Deterministic fixed-tick snake movement on a 2D grid presented in a 3D scene.
- One-input turn queue with reversal prevention.
- Food spawning on valid empty cells only.
- Score and length tracking.
- Win/loss detection and restart flow.
- Ready-state overlay before movement begins.

### Interaction Rules
- On each simulation step:
  1. Resolve the queued direction if it is legal.
  2. Compute the next head cell from the current direction.
  3. If the cell is outside the board, transition to `lost`.
  4. Determine whether the move is a growth step by checking the food cell.
  5. For self-collision, treat the current tail cell as vacating only when the move is not a growth step. Moving into a cell still occupied after resolution is a loss.
  6. On a normal move, prepend the new head and remove the tail.
  7. On a growth move, prepend the new head and keep the tail.
  8. Spawn the next food from the remaining empty cells or transition to `won` if none remain.
- Food spawning must never place food on the snake or outside the board.
- The simulation should pause completely when the run is `ready`, `won`, or `lost`.
- Restart must create a clean new initial state rather than mutating fragments of the old run in place.

---

## UI And Feedback

### Required UI
- Score display that updates immediately after eating food.
- Length display or equivalent readable confirmation of snake growth.
- A start overlay or inline prompt explaining `WASD / Arrow Keys` and restart controls.
- End-state overlay for `Game Over` and `Board Cleared`.
- No minimap is required because the full board is visible.

### Feedback
- The head segment should be visually distinct from the body.
- Food should pulse, glow, bob slightly, or otherwise remain clearly identifiable without needing audio.
- On food pickup, update the HUD immediately and refresh the scene state on the next render.
- On loss, freeze movement instantly and make the failure state obvious through text and color change.
- Audio is optional polish and not required for v0.

---

## Technical Architecture

### Suggested File Layout
- `sandbox/snake-game/index.html`: static entry file, canvas mount, HUD and overlay shell, and pinned module entry.
- `sandbox/snake-game/main.js`: bootstraps renderer, scene, input listeners, UI wiring, and the main loop.
- `sandbox/snake-game/src/config.js`: board, timing, camera, and color constants.
- `sandbox/snake-game/src/simulation.js`: pure board-state creation, input queue resolution, simulation stepping, restart creation, and food spawning.
- `sandbox/snake-game/src/rendering.js`: 3D scene setup plus board-state-to-mesh reconciliation.
- `sandbox/snake-game/src/input.js`: keyboard-to-direction mapping and restart events.
- `sandbox/snake-game/src/ui.js`: score, length, ready-state, and end-state updates.
- `sandbox/snake-game/tests/logic.test.mjs`: deterministic pure logic tests for the simulation module.
- `sandbox/snake-game/tests/smoke.test.mjs`: existing artifact existence and local reference smoke checks.

### Rendering
- Use Three.js or an equivalent browser-friendly 3D library with no build step. A pinned CDN ES module import is acceptable for v0 if it keeps the artifact simple.
- Render the board with simple primitives: floor, perimeter markers/walls, cube-like snake segments, and a distinct food mesh.
- Avoid per-frame scene reconstruction. Reuse meshes or reconcile only the changed segment count and state when practical.

### Update Model
- Use `requestAnimationFrame` for rendering.
- Feed a fixed-step simulation with accumulated delta time.
- Keep input handling, simulation, and rendering as separate modules or clearly separated sections.
- The render layer must be a projection of board state, not the owner of gameplay logic.

### Performance Constraints
- Target a stable feel on a modern desktop browser at the default `20 x 20` board size.
- Do not allocate new geometries, materials, or large temporary objects every frame.
- Keep the board and segment counts small enough that simple mesh reconciliation is sufficient for v0.

### Browser Constraints
- The default artifact must be `sandbox/snake-game/index.html`.
- All game-specific code, styles, and generated assets must stay inside `sandbox/snake-game/`.
- Prefer static files and ES modules; do not require a bundler or backend service for v0.
- The game must be runnable through the repo helper: `bash ./scripts/run-game.sh sandbox/snake-game/index.html`.

---

## Validation And Failure Inventory

### Acceptance Criteria

#### AC1: Artifact Loads
**Given** the repo root and the command `bash ./scripts/run-game.sh sandbox/snake-game/index.html`  
**When** the browser opens the served artifact  
**Then** the page loads without an immediate crash, shows the 3D board and HUD shell, and the existing smoke test expectations remain satisfied

#### AC2: Ready State And Controls Work
**Given** a fresh page load  
**When** the player presses `WASD` or an arrow key  
**Then** the run starts from `ready`, the snake begins moving in the chosen legal direction, and only one next turn can be buffered before the next simulation step

#### AC3: Food, Growth, And Score Work
**Given** an active run  
**When** the snake head enters the food cell  
**Then** the score increments by one, the snake length increases by one, and a new food cell appears on an unoccupied board cell

#### AC4: Collision And End States Behave
**Given** an active run  
**When** the snake hits the board boundary or a non-vacating body segment  
**Then** the run ends immediately, movement stops, and the end overlay shows loss information without requiring a page reload

#### AC5: Restart Works Cleanly
**Given** a won or lost run  
**When** the player presses `Space`, `Enter`, or `R`  
**Then** a clean initial state is created, score returns to zero, the snake resets to its starting length, and the next run behaves identically to a fresh load

### Expected Failure Modes To Watch For
- Simulation speed changing with monitor refresh rate or tab timing.
- Buffered turns being dropped, duplicated, or applied illegally within a single tick.
- Food spawning inside the snake or failing when the board is nearly full.
- Self-collision logic falsely treating the vacating tail as solid on non-growth moves.
- Camera framing or lighting making the board unreadable despite correct game logic.
- Restart leaving behind stale meshes, score text, or event listeners.
- Scene updates rebuilding too much geometry each frame and causing avoidable garbage or hitches.

### Verification Method
- **Automated tests in `sandbox/snake-game/tests/`**:
  - Keep `smoke.test.mjs` as the entry-file and asset-reference baseline.
  - Replace the placeholder in `logic.test.mjs` with deterministic tests for:
    - initial state creation
    - opposite-direction rejection
    - one-tick step resolution
    - food pickup and growth
    - wall collision
    - self-collision including the vacating-tail rule
    - food spawn exclusion from occupied cells
    - full-board victory
    - clean restart state
- **Repo test command**: `node ./scripts/run-game-tests.mjs`
- **Mechanical gate**: `bash ./scripts/quality-gate.sh`
- **Manual playtest**:
  1. Launch the artifact with `bash ./scripts/run-game.sh sandbox/snake-game/index.html`.
  2. Start a run with keyboard input.
  3. Collect at least three food pickups and confirm score and length updates.
  4. Intentionally hit a wall and confirm the end overlay and restart flow.
  5. Start another run and verify the initial state is clean.

---

## Task Breakdown

1. [ ] Create the static artifact shell at `sandbox/snake-game/index.html` with a canvas container, HUD, and start/end overlays.
2. [ ] Implement a pure simulation module for board config, initial state creation, direction queueing, fixed-tick stepping, growth, win/loss resolution, and food spawning.
3. [ ] Expand `sandbox/snake-game/tests/logic.test.mjs` to cover the extracted pure rules before or alongside render work.
4. [ ] Add the 3D scene setup, fixed top-down camera, readable lighting, board meshes, snake segment meshes, and food mesh.
5. [ ] Wire keyboard input into the simulation loop with one buffered turn and restart handling.
6. [ ] Connect HUD and overlay state so score, length, ready state, game over, and board-cleared states always reflect simulation state directly.
7. [ ] Run `node ./scripts/run-game-tests.mjs`, perform a browser smoke/playtest, and fix any load or rule regressions.
8. [ ] Run `bash ./scripts/quality-gate.sh` and record the artifact path, launch command, and first failure inventory in `STATUS.md`.
9. [ ] Queue only thin follow-on repairs in `AGENTS.md` after the first playable pass, grouped by movement/rules, UI/feedback, performance, or polish.
