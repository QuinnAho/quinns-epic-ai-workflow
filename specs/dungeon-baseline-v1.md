# Game Specification: Dungeon Baseline V1

## Overview

**Spec ID**: GAME-001  
**Status**: Draft  
**Game Workspace**: `sandbox/dungeon-baseline-v1/`  
**Target Artifact**: `sandbox/dungeon-baseline-v1/index.html`  
**Default Test Harness**: `sandbox/dungeon-baseline-v1/tests/`  
**Run Method**: Run `./scripts/run-game.sh sandbox/dungeon-baseline-v1/index.html` and open the served page in a desktop browser. Pointer lock begins on click.

### Game Concept

`dungeon-baseline-v1` is a first-person dungeon crawler built as a single HTML artifact with inline game code and a Three.js CDN import. The player explores a compact stone keep made of connected rooms and corridors, collects keys, unlocks doors, avoids or fights dungeon sentries, and pushes to the exit while managing health in a readable torch-lit space with fog and a corner minimap.

### Success Condition

The first playable version succeeds when the browser artifact loads without an immediate crash, pointer lock works, the player can traverse multiple connected rooms with collision, collect at least two keys, unlock at least two doors, survive or kill patrolling enemies, and reach the exit while the HUD and minimap stay synchronized with world state.

## Design Goals

- Deliver a complete v0 dungeon loop with movement, combat, key-door progression, and a clear win/lose state.
- Keep the game-specific implementation inside one runnable HTML file under `sandbox/dungeon-baseline-v1/`.
- Use one shared dungeon blueprint as the source of truth for level layout, wall collision, door placement, pickups, enemy spawns, and minimap rendering.
- Favor readability and stability over ambitious content systems or procedural complexity.

## Non-Goals

- No procedural generation for v0.
- No inventory beyond health and a generic key count.
- No jumping, ranged weapons, advanced animation rigs, or external asset pipeline.
- No physics engine, navmesh library, framework UI layer, or build step.

## Forward Plan

### Likely Follow-On Systems

- Additional enemy archetypes with different chase or attack behaviors.
- Health pickups, more rooms, and stronger progression gating.
- Better enemy pathing polish, hit reactions, and environmental props.

### Prepare Now

- Keep the dungeon blueprint data-oriented so future rooms, torches, enemies, and doors can be appended without rewriting the renderer or minimap.
- Keep player state, door state, key state, and enemy state normalized so later repairs can target systems independently.
- Keep the collision and minimap derived from the same blueprint used to build world geometry.

### Avoid For Now

- Full ECS or generalized engine architecture.
- Procedural dungeon generation.
- Audio loading, shadow-heavy lighting, or content pipelines that threaten first-playable stability.

## Player Experience

### Camera And Controls

- **Perspective**: First-person
- **Input Scheme**: `WASD` movement, mouse look, left click attack, `E` unlock door, `R` restart, `Esc` releases pointer lock
- **Expected Feel**: Responsive and grounded, with readable speed and no ice-skating
- **Pointer Lock / Mouse Capture**: Required during active play

### Core Loop

1. Click into the scene to lock the mouse and start moving.
2. Explore connected rooms and corridors while avoiding or engaging enemies.
3. Collect keys and spend them to open blocked routes.
4. Reach the exit before health reaches zero.

### Win / Lose Conditions

- **Win**: Reach the exit tile after opening the required progression doors.
- **Lose**: Health reaches zero.
- **Retry Flow**: Show an overlay with a restart affordance that resets the dungeon state in-place.

## World And Environment

### World Structure

- **Layout Model**: Hand-authored grid dungeon that reads as connected rooms plus narrow corridors.
- **Generation Model**: Static blueprint embedded in the HTML file as JSON.
- **Traversal Constraints**: Walls, locked doors, enemy pressure, and fog-limited visibility.

### Environment Systems

- Low-poly stone walls, floors, and ceiling pieces generated from the blueprint.
- Warm torch point lights with restrained flicker.
- Blue-gray fog for distance falloff.
- Exit marker that is visible and readable without overwhelming the room.

### Source Of Truth

The embedded dungeon blueprint must be the canonical source for:

- map walkability and wall placement
- door locations and door widths
- key locations
- enemy spawn points and patrol routes
- minimap floor and door rendering

## Entities

### Player

- **Abilities**: Move, look, melee attack, unlock doors, collect keys
- **State**: Position, yaw, pitch, health, max health, key count, attack timer, attack cooldown, alive/dead state
- **Failure Modes To Avoid**:
  - frame-rate dependent movement
  - walking through walls or locked doors
  - pointer-lock loss causing ghost movement

### Enemies

- **Types**: One melee sentry archetype for v0
- **Behaviors**: Patrol, chase, attack, take damage, die
- **Navigation Rules**: Move over the dungeon grid and respect doors and walls
- **Failure Modes To Avoid**:
  - walking through walls
  - attacking every frame with no cooldown
  - drifting out of sync with the minimap

### Doors

- Locked until the player spends one key within interaction range.
- Wide enough to block the corridor until opened.
- Use the same blueprint cells for collision and minimap display.

### Keys

- Auto-collected on overlap.
- Increase the HUD key count immediately.
- Removed from the world once collected.

## Gameplay Systems

### Required Systems

- Delta-time first-person movement and mouse look
- Wall and door collision
- Melee attack with startup, active window, and cooldown
- Enemy patrol/chase/attack behavior
- Key collection and door unlocking
- Exit trigger, death state, pause state, and restart flow

### Interaction Rules

- Keys collect automatically on overlap.
- Doors require the player to face and interact from close range.
- Attacks can only damage each enemy once per swing.
- Enemies can damage the player only when within range and off cooldown.
- Doors become non-solid once unlocked and remain open for the rest of the run.

## UI And Feedback

### Required UI

- Health bar and numeric health value
- Key count
- Door prompt
- Crosshair
- Corner minimap showing dungeon floor, doors, keys, enemies, player position, and facing
- Start/pause/win/lose overlay

### Feedback

- Screen flash and small shake on player damage
- Clear slash feedback on attack
- HUD pulse on key pickup and door unlock
- Distinct overlay copy for pause, victory, and death
- Torch flicker should feel alive but not strobe

## Technical Architecture

### Rendering

- Three.js via pinned CDN ES module import
- Single `index.html` artifact with inline CSS and inline game module
- Shared geometries/materials where practical

### Update Model

- Use a delta-time update loop with capped frame deltas
- Keep input capture, simulation, AI, combat, UI sync, and rendering as distinct code sections inside the HTML module
- Derive minimap state from the same dynamic state objects used by gameplay

### Performance Constraints

- Target stable desktop play at roughly 60 FPS
- Avoid needless per-frame allocations in hot loops when a reusable structure is practical
- Keep scope to a compact dungeon with a small set of enemies, torches, doors, and keys

### Browser Constraints

- Must run from a local static server
- No build step
- No local runtime assets beyond the HTML file itself
- Pointer lock flow must degrade into a visible pause overlay when released

## Validation And Failure Inventory

### Acceptance Criteria

#### AC1: Artifact Loads

**Given** the page is served locally  
**When** `sandbox/dungeon-baseline-v1/index.html` is opened  
**Then** the scene loads without an immediate crash and renders a visible dungeon view

#### AC2: Core Loop Works

**Given** the player starts a run  
**When** they move, collect keys, unlock doors, and engage enemies  
**Then** the dungeon loop remains functional and readable

#### AC3: Movement And Collision Behave

**Given** the player or an enemy moves against walls or locked doors  
**When** the movement update runs  
**Then** solid geometry prevents penetration

#### AC4: UI Matches World State

**Given** health, keys, enemy state, or door state changes  
**When** the HUD and minimap update  
**Then** the UI remains synchronized with the world

#### AC5: Progression Completes

**Given** the player explores the dungeon in order  
**When** they collect the available keys and open the blocked gates  
**Then** the exit becomes reachable and victory can trigger

### Expected Failure Modes To Watch For

- pointer lock failing to resume cleanly after pause
- mouse look sensitivity or pitch clamp feeling wrong
- collision sample points allowing corner clipping
- enemy BFS pathing stalling at doors or tight corners
- melee reach feeling too short or too generous
- minimap drift from world coordinates
- torch lighting becoming too dark or too noisy

### Verification Method

- Node smoke checks for artifact shape and required UI/runtime hooks
- Pure-logic tests that validate dungeon progression and enemy patrol cells from the embedded blueprint
- Manual browser smoke pass for pointer lock, movement, combat, key-door flow, minimap sync, death, and restart

## Task Breakdown

1. [ ] Normalize the spec and queue to the active `dungeon-baseline-v1` slug
2. [ ] Build the first playable single-file dungeon artifact
3. [ ] Replace placeholder tests with blueprint-aware smoke and logic coverage
4. [ ] Run the sandbox tests and repo quality gate
5. [ ] Record the artifact path, launch command, and first failure inventory in `STATUS.md`
6. [ ] Queue targeted repair tasks based on the first browser playtest
