# AI Game Gen Workflow Experiment

**Generate playable browser games from a single prompt using an autonomous AI workflow.**

This project demonstrates a structured AI workflow that takes a game idea and autonomously generates, tests, and fixes a working browser game, no manual coding required.

## See It In Action

**[View the Demo](https://quinnaho.github.io/a-day-in-an-ai-agent/)**

The demo shows two dungeon games generated from the exact same prompt:
- One built with baseline AI (no workflow)
- One built with this structured workflow

Same input. Different results. See what a good workflow can do.

## The Experiment

I was curious whether my [A Day in an AI Agent](https://github.com/QuinnAho/a-day-in-an-ai-agent/tree/main?tab=readme-ov-file) workflow could be adapted for game generation. Games are harder than typical code, camera systems, collision detection, enemy AI, and game loops all need to work together coherently. Most AI-generated games break in predictable ways.

This experiment tests whether a structured workflow can help. The approach:

1. **Generate** a rough prototype from a prompt
2. **Playtest** and log what's broken
3. **Queue targeted fixes** for each failure
4. **Iterate** until the game actually works

It's not a polished product — just an exploration of what's possible when you give AI a process instead of a blank canvas.

---

## For Developers

<details>
<summary>Setup & Usage</summary>

### Quick Start

1. Run `./scripts/generate-game.sh` — guided prompt collects your game idea
2. Run `./scripts/codex-coding-time.sh` — autonomous implementation begins
3. Run `./scripts/run-game.sh` — serve and playtest locally
4. Review `STATUS.md` and iterate until playable

### Key Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Task queue and execution rules |
| `STATUS.md` | Run log and session state |
| `sandbox/` | Generated games live here |
| `specs/` | Implementation specs |

### Environment

- Uses Codex CLI (configured in `.codex/`)
- Default model: `gpt-5.4`
- Override with `CODEX_SPEC_MODEL` or `CODEX_RUN_MODEL` env vars

</details>
