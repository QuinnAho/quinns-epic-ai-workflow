---
name: library-selector
description: Use when deciding which external libraries to include for a game based on its type and complexity.
---

# Library Selector

Use this skill when generating a game spec to determine which external libraries (if any) should be included via CDN imports.

## Philosophy

- **Default to vanilla JS** for simple games (tier 1-2)
- **Use libraries when they reduce complexity**, not add it
- **Prefer single-purpose libraries** over monolithic frameworks
- **Always use pinned CDN versions** for reproducibility

## Library Decision Matrix

### Tier 1-2: Simple Games (Snake, Pong, Breakout, Platformers)

**Recommendation: No external libraries**

Vanilla JavaScript with Canvas2D or simple DOM manipulation is sufficient. Libraries add overhead without benefit.

```javascript
// Preferred: Raw canvas
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
```

### Tier 3: Multi-System Games (Shooters, Tower Defense)

**Consider these based on features:**

| Feature Needed | Library | CDN |
|----------------|---------|-----|
| Sprite animation | None needed | Use CSS or canvas drawImage |
| Basic physics | None needed | Simple AABB is enough |
| Particle effects | None needed | Array of particles + canvas |
| Sound effects | Howler.js (optional) | `https://cdn.jsdelivr.net/npm/howler@2.2.4/dist/howler.min.js` |

### Tier 4: Complex Games (RPGs, Procedural, Crafting)

**Consider game frameworks for faster iteration:**

| Framework | When to Use | CDN |
|-----------|-------------|-----|
| Phaser 3 | 2D games needing scenes, tweens, sprites | `https://cdn.jsdelivr.net/npm/phaser@3.70.0/dist/phaser.min.js` |
| PixiJS | High-performance 2D rendering | `https://cdn.jsdelivr.net/npm/pixi.js@7.3.2/dist/pixi.min.js` |

### Tier 5: Ambitious Games (3D, MMO concepts)

**3D rendering requires libraries:**

| Feature | Library | CDN (ESM) |
|---------|---------|-----------|
| 3D rendering | Three.js | `https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.min.js` |
| 3D physics | Cannon-es | `https://cdn.jsdelivr.net/npm/cannon-es@0.20.0/dist/cannon-es.min.js` |
| 2D physics (complex) | Matter.js | `https://cdn.jsdelivr.net/npm/matter-js@0.19.0/build/matter.min.js` |

## Special Cases

### Procedural Generation
```javascript
// Noise: Use this CDN if terrain/procedural needed
// https://cdn.jsdelivr.net/npm/simplex-noise@4.0.1/dist/esm/simplex-noise.min.js
```

### Pathfinding
```javascript
// For grid-based AI pathfinding
// https://cdn.jsdelivr.net/npm/pathfinding@0.4.18/visual/lib/pathfinding-browser.min.js
```

### State Management (complex UIs)
```javascript
// For inventory/crafting systems with complex state
// https://cdn.jsdelivr.net/npm/immer@10.0.3/dist/immer.umd.production.min.js
```

## Integration Pattern

When including a library, add it to the spec's Technical Architecture section:

```markdown
### External Dependencies

| Library | Version | Purpose | CDN |
|---------|---------|---------|-----|
| Three.js | 0.160.0 | 3D rendering | [CDN URL] |

### Import Pattern

\`\`\`html
<!-- In index.html for UMD -->
<script src="[CDN URL]"></script>

<!-- OR for ESM in main.js -->
import * as THREE from '[CDN URL]';
\`\`\`
```

## Anti-Patterns

❌ **Don't use libraries for:**
- Simple collision detection (AABB is trivial)
- Basic animation (requestAnimationFrame + lerp)
- Simple state (plain objects work fine)
- DOM manipulation (querySelector is sufficient)

❌ **Don't mix:**
- Multiple game frameworks (Phaser + PixiJS)
- Multiple physics engines
- ESM and UMD in the same file without a clear boundary

## Output Format

When this skill is invoked, output a library recommendation block:

```
LIBRARIES_RECOMMENDED:
- name: [library name]
  version: [pinned version]
  cdn: [full CDN URL]
  purpose: [why this library]
  import_type: [esm|umd]

LIBRARIES_AVOIDED:
- name: [library name]
  reason: [why not needed for this game]
```
