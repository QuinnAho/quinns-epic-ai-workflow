# AI Game Gen Workflow

*A Codex-first autonomous workflow for generating and fixing web games.*

This repository is a game-generation fork of **A Day in an AI Agent**. It adapts the original autonomous coding idea into a **Codex-only workflow** tuned for **browser game development**, not generic product work.

The active game intake now comes from the guided generator flow in [generate-game.sh](./scripts/generate-game.sh). Each generated game stores its original brief in `sandbox/<game-slug>/idea.txt`, any clarification answers in `sandbox/<game-slug>/clarifications.txt`, and a combined intake source in `sandbox/<game-slug>/intake.md`.

## Demo Comparison

This repo includes a side-by-side comparison of two dungeon-game outputs generated from the exact same prompt:

```text
Build a 3D first-person dungeon game in a single HTML file using Three.js. The player explores interconnected rooms using WASD + mouse look with pointer lock. Rooms are connected by corridors. The dungeon has torch lighting with flickering point lights and fog. The player has health and a simple attack (click to swing). Enemies patrol rooms and chase the player when in range. Collision detection prevents the player and enemies from walking through walls. There's a 2D minimap overlay in the corner showing rooms, the player position, and enemy positions. The player collects keys to unlock doors. Include a HUD showing health and key count.
```

- [Play the baseline boilerplate Codex version](https://quinnaho.github.io/quinns-epic-ai-workflow/without-workflow/)
- [Play the workflow-generated version](https://quinnaho.github.io/quinns-epic-ai-workflow/with-workflow/)
- [Open the comparison page](https://quinnaho.github.io/quinns-epic-ai-workflow/)
- One version was generated with baseline boilerplate Codex alone.
- One version was generated with this AI workflow using the same prompt.
- In the workflow-driven run, unit tests were also generated automatically as part of the output.
- No manual additions or post-prompt changes were applied to either version; both were generated fully autonomously.
- These links are served through GitHub Pages once the repo's Pages deployment runs from `main`.

## What This Repo Is For

- Generating playable web games from specs and prompts
- Running autonomous Codex implementation loops against those specs
- Turning broken AI output into a structured fix list
- Applying engine-level fixes until the game is stable and fun
- Preserving a clean artifact trail for demos, writeups, and videos

## Current Target

The first target is a **single-file Three.js dungeon crawler**:

- First-person camera
- Procedurally placed rooms
- Keys, doors, enemies, health, and pickups
- Pointer lock controls
- Minimap and HUD
- Lighting, collision, and basic combat/avoidance

This is deliberate. It exercises the parts of AI game generation that usually break:

- camera and movement architecture
- collision and wall penetration
- enemy navigation
- level layout consistency
- UI-to-world synchronization
- delta time and game loop structure
- per-frame performance and memory discipline

## How This Version Differs From Upstream

- Codex owns spec generation, implementation, validation, and workflow iteration.
- The workflow is focused on **web game generation**, especially Three.js/browser experiments.
- Success is not just "tests passed." Success means the game runs in a browser and the core systems behave correctly.
- The iteration model is: **generate -> playtest -> log failures -> queue fixes -> polish -> ship**.
- The per-game intake lives with the game under `sandbox/<game-slug>/`, not in a repo-wide planning file.

## Core Workflow

1. Run `./scripts/generate-game.sh` and enter the game name and brief in the guided prompt.
2. The script saves that brief to `sandbox/<game-slug>/idea.txt`, records a baseline commit in `sandbox/<game-slug>/baseline-ref.txt`, lets Codex propose a few high-value clarification questions, stores the answers, scaffolds `sandbox/<game-slug>/tests/`, and generates the detailed implementation spec.
3. The same script seeds [AGENTS.md](./AGENTS.md) with the first starter queue for that game unless you opt out.
4. Run `./scripts/codex-coding-time.sh`.
5. Serve the current artifact with `./scripts/run-game.sh` and record what is broken.
6. Convert those failures into focused follow-up tasks.
7. Repeat until the prototype becomes a playable, deployable game.
8. When the game is done, run `node ./scripts/finalize-game-release.mjs <game-slug> --apply` to write a release bundle inside the game's sandbox and restore everything outside that game workspace back to the recorded baseline commit.

## What "Good" Looks Like

A successful run should produce:

- a rough AI-generated prototype
- a clear list of failures in the generated output
- targeted fixes for camera, collisions, loop structure, AI, UI, and performance
- a polished final game that can be hosted on GitHub Pages
- a clean enough repo and story arc to support a devlog or YouTube video

## Important Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Codex task queue and execution rules |
| `STATUS.md` | Run log and handoff state between autonomous sessions |
| `PROJECT.md` | Project constitution for the autonomous Codex workflow |
| `.codex/config.toml` | Project-scoped Codex configuration, including subagent settings |
| `.codex/agents/` | Codex custom agents that replace the old workflow roles |
| `.agents/skills/` | Repository-scoped Codex skills for workflow orchestration |
| `specs/` | Game implementation specs used by the generator and run loop |
| `sandbox/` | Dedicated workspace where generated games live, one folder per game slug |
| `sandbox/<game-slug>/idea.txt` | Original game brief collected by the generator and reused by Codex during implementation |
| `sandbox/<game-slug>/baseline-ref.txt` | Baseline commit captured when the game started so finished-game cleanup can restore the rest of the repo deterministically |
| `sandbox/<game-slug>/clarifications.txt` | User answers to Codex-generated intake questions |
| `sandbox/<game-slug>/intake.md` | Combined intake source used during spec generation |
| `sandbox/<game-slug>/spec-question-run.log` | Clarification-generation CLI log for debugging repeated failures |
| `sandbox/<game-slug>/spec-generation-run.log` | Spec-generation CLI log for debugging repeated failures |
| `sandbox/<game-slug>/tests/` | Built-in smoke and logic test files for that specific game workspace |
| `sandbox/<game-slug>/release/` | Archived release bundle, including the spec, status trail, and commit history for that finished game |
| `scripts/codex-cli.mjs` | Repo-local Codex CLI launcher that resolves a working entrypoint, especially on Windows |
| `scripts/codex-coding-time.sh` | Main autonomous Codex runner |
| `scripts/generate-game.sh` | Opens a guided intake flow, gathers Codex-generated clarification answers, saves the intake in the sandbox, writes the spec, and seeds the first AGENTS queue |
| `scripts/run-game.sh` | Serves the current browser artifact locally |
| `scripts/finalize-game-release.mjs` | Creates a release bundle for one game and restores everything outside that game's sandbox back to the stored baseline commit |
| `scripts/scaffold-game-tests.mjs` | Scaffolds baseline Node-based tests into each sandboxed game workspace |
| `scripts/run-game-tests.mjs` | Runs sandbox game tests with Node's built-in test runner |
| `scripts/quality-gate.sh` | Mechanical quality checks |

## Starting Point

If you are working on this branch, start here:

1. Run `./scripts/generate-game.sh`.
   The generator walks through a guided prompt, reserves `sandbox/<game-slug>/` for that game's files, stores the original brief there, captures the baseline repo commit in `sandbox/<game-slug>/baseline-ref.txt`, asks a few Codex-generated clarification questions when useful, and scaffolds baseline tests.
   It also keeps the intake cheap: clarification questions are capped, simple games should spec in one pass, and repeated tool/path failures cause the spec run to stop.
2. Review the generated spec and seeded [AGENTS.md](./AGENTS.md) queue.
3. Run `./scripts/codex-coding-time.sh`.
4. Serve and inspect the artifact with `./scripts/run-game.sh`.
5. Review [STATUS.md](./STATUS.md).
6. Repeat until the game is actually playable, not just technically generated.

## Direction Of The Repo

This repo should be understood as a **game-generation fork** of the original workflow, not a generic two-agent coding template.

The near-term objective is to make the automation reliable enough that Codex can:

- generate browser game prototypes
- iterate on the failures without human micromanagement
- converge on playable output
- leave behind a clean record of what the model got wrong and how it was corrected

## Codex CLI Note

The workflow still uses the Codex CLI directly. Repository scripts call it through `scripts/codex-cli.mjs`, which is a thin launcher that resolves a working Codex entrypoint when a Windows global shim such as `codex.bat` is broken.

Current script defaults:

- `CODEX_SPEC_MODEL=gpt-5.4`
- `CODEX_RUN_MODEL=gpt-5.4`

You can override either environment variable if your Codex account exposes a different supported model name.



