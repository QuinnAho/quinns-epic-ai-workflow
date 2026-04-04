# AI Game Gen Workflow

**Generate playable browser games from a single prompt using an autonomous AI workflow.**

This project demonstrates a structured AI workflow that takes a game idea and autonomously generates, tests, and fixes a working browser game — no manual coding required.

## See It In Action

**[View the Demo](https://quinnaho.github.io/a-day-in-an-ai-agent/)**

The demo shows two dungeon games generated from the exact same prompt:
- One built with baseline AI (no workflow)
- One built with this structured workflow

Same input. Different results. See what a good workflow can do.

## The Idea

Most AI-generated games break. Camera gets stuck. Enemies walk through walls. The game loop stutters. UI doesn't sync with game state.

This workflow treats those failures as expected. It:

1. **Generates** a rough prototype from your prompt
2. **Playtests** and logs what's broken
3. **Queues targeted fixes** for each failure
4. **Iterates** until the game actually works
5. **Ships** a polished, deployable result

The AI does the implementation. The workflow keeps it on track.

## Why This Matters

AI can write code. But writing code that *works together* as a coherent game is harder. This project shows one way to bridge that gap — by giving the AI a structured process instead of just a blank canvas.

## Origin

This is a game-generation fork of [A Day in an AI Agent](https://github.com/anthropics/a-day-in-an-ai-agent). It adapts that autonomous coding workflow specifically for browser game development.

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
