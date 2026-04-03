---
name: game-ux-polish
description: Use when implementing or reviewing game feel, juice, and player experience polish.
---

# Game UX Polish

Use this skill to ensure the game feels good to play, not just functions correctly. Focus on subtle details that make players want to keep playing.

## Core Principle

**The player should never feel like they're using software.** No debug info, no developer artifacts, no jarring experiences.

## Remove All Developer Artifacts

Before any release check, ensure NONE of these exist:

- Console.log statements (unless error handling)
- FPS counters or debug overlays
- Grid lines or collision box visualizations
- "Debug mode" toggles or developer menus
- Placeholder text ("Lorem ipsum", "TODO", "Test")
- Default browser styling on game elements
- Visible cursor when it should be hidden
- Right-click context menus on canvas
- Text selection highlighting on UI elements

```javascript
// REMOVE before release
console.log('player position:', x, y);
debugCtx.strokeRect(hitbox.x, hitbox.y, hitbox.w, hitbox.h);

// KEEP (actual error handling)
console.error('Failed to load asset:', assetPath);
```

## Screen Shake

Add subtle screen shake for:
- Player damage
- Explosions
- Heavy impacts
- Powerful attacks

```javascript
// Subtle shake - not nauseating
function screenShake(intensity = 3, duration = 100) {
  const canvas = document.getElementById('game');
  const startTime = performance.now();

  function shake() {
    const elapsed = performance.now() - startTime;
    if (elapsed > duration) {
      canvas.style.transform = '';
      return;
    }

    const decay = 1 - (elapsed / duration);
    const x = (Math.random() - 0.5) * intensity * decay;
    const y = (Math.random() - 0.5) * intensity * decay;
    canvas.style.transform = `translate(${x}px, ${y}px)`;
    requestAnimationFrame(shake);
  }
  shake();
}
```

**Shake guidelines:**
- Small hits: intensity 2-3, duration 50-100ms
- Big impacts: intensity 5-8, duration 150-200ms
- Never exceed intensity 10 or duration 300ms (causes nausea)

## Hit Feedback

Every player action should have feedback:

| Action | Visual | Audio (if available) | Feel |
|--------|--------|---------------------|------|
| Attack lands | Flash white, particles | Impact sound | Brief pause (2-3 frames) |
| Take damage | Screen flash red, shake | Pain sound | Invincibility frames |
| Collect item | Item scales up then disappears | Pickup chime | Score number floats up |
| Jump | Squash on takeoff, stretch in air | Jump sound | - |
| Land | Squash briefly | Land thump | Dust particles |

## Hitstop / Freeze Frames

Pause the game for 2-4 frames on significant impacts:

```javascript
let hitStopFrames = 0;

function update(dt) {
  if (hitStopFrames > 0) {
    hitStopFrames--;
    return; // Skip game logic, keep rendering
  }
  // Normal update...
}

function onSignificantHit() {
  hitStopFrames = 3; // ~50ms at 60fps
  screenShake(5, 100);
}
```

## Camera Feel

- **Smooth follow**: Never snap to player, use lerp
- **Look-ahead**: Shift camera slightly in movement direction
- **Bounds**: Don't show void/empty space beyond level edges
- **Landing impact**: Subtle camera drop on hard landings

```javascript
// Smooth camera with look-ahead
function updateCamera(player, dt) {
  const lookAhead = player.velocityX * 0.3;
  const targetX = player.x + lookAhead;
  const targetY = player.y;

  camera.x += (targetX - camera.x) * 5 * dt;
  camera.y += (targetY - camera.y) * 5 * dt;
}
```

## Particle Polish

Use particles sparingly but effectively:

| Event | Particle Type | Count | Lifetime |
|-------|--------------|-------|----------|
| Footsteps | Dust puffs | 2-3 | 200ms |
| Jump | Dust burst | 5-8 | 300ms |
| Death | Explosion | 10-20 | 500ms |
| Collect | Sparkles | 5-10 | 400ms |
| Trail | Fading dots | 1/frame | 150ms |

**Never:**
- Spawn 100+ particles (performance)
- Use pure white particles (too harsh)
- Let particles block gameplay visibility

## UI/HUD Feel

- **Numbers should animate**: Score ticks up, health slides down
- **Critical states pulse**: Low health throbs red
- **Clean typography**: No default fonts, consistent sizing
- **Minimal chrome**: Hide UI elements that aren't immediately needed

```javascript
// Animated score counter
function updateScoreDisplay(current, target, dt) {
  if (current < target) {
    return Math.min(current + 100 * dt, target);
  }
  return current;
}
```

## Game State Transitions

Never abrupt cuts:

| Transition | Effect |
|------------|--------|
| Start game | Fade in from black (300ms) |
| Death | Slow-mo (0.3x for 500ms), then fade |
| Level complete | Freeze, celebration particles, fade |
| Pause | Dim background, slide in menu |
| Game over | Dramatic pause, fade to results |

## Audio Cues (if implemented)

- **Layer sounds**: Don't play same sound twice simultaneously
- **Pitch variation**: Randomize pitch ±10% to avoid repetition fatigue
- **Spatial audio**: Pan sounds based on source position
- **Music ducking**: Lower music during important sound effects

## Polish Checklist

Before marking a game complete, verify:

```
[ ] No console.log or debug visualizations visible
[ ] Cursor is appropriate (hidden in gameplay, pointer on buttons)
[ ] No text is selectable
[ ] No right-click context menu on game
[ ] Player actions have visual feedback
[ ] Damage has screen shake and/or flash
[ ] Numbers animate (don't just snap to new values)
[ ] Death/game-over has a dramatic pause
[ ] Camera follows smoothly (no jitter)
[ ] UI is readable and doesn't obstruct gameplay
[ ] No placeholder art or text
[ ] Game feels responsive (input → feedback < 100ms perceived)
```

## Anti-Patterns

❌ **Don't:**
- Show "Loading..." without a progress indicator
- Play the same sound 10 times per second
- Shake screen for every tiny event
- Flash bright white on every hit (accessibility)
- Require reading instructions to understand controls
- Use Comic Sans or default serif fonts
- Show raw numbers ("HP: 47.3829472")

✅ **Do:**
- Use loading spinners or progress bars
- Throttle sounds and vary pitch
- Reserve shake for impactful moments
- Use colored tints instead of pure white flashes
- Make controls discoverable through play
- Use clean, readable fonts
- Round numbers for display ("HP: 47")

## Output Format

When reviewing for UX polish, report:

```
UX_POLISH_ISSUES:
- [severity: low|medium|high] description

UX_POLISH_PASS: true/false
```
