#!/usr/bin/env node

/**
 * Game Complexity Classifier
 *
 * Analyzes a game idea/brief and returns a complexity tier (1-5) along with
 * recommended configuration for token-efficient processing.
 *
 * Usage:
 *   node scripts/classify-game-complexity.mjs "A simple snake game"
 *   node scripts/classify-game-complexity.mjs --file sandbox/my-game/idea.txt
 *   node scripts/classify-game-complexity.mjs --json "A complex RPG"
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';

// Complexity indicators - patterns that suggest higher complexity
const COMPLEXITY_INDICATORS = {
  // Tier 1: Simple arcade (Snake, Pong, Breakout, Flappy Bird)
  simple: {
    patterns: [
      /\b(snake|pong|breakout|brick.?breaker|flappy|tetris|asteroids)\b/i,
      /\bsimple\s+(arcade|game|clone)\b/i,
      /\bclassic\s+arcade\b/i,
      /\bminimalist\b/i,
      /\bone.?button\b/i,
    ],
    keywords: ['snake', 'pong', 'breakout', 'tetris', 'flappy', 'asteroids', 'space invaders', 'dino run', 'endless runner simple'],
    weight: -2,
  },

  // Tier 2: Single-mechanic games
  singleMechanic: {
    patterns: [
      /\bplatformer\b(?!.*rpg|.*inventory|.*skill)/i,
      /\bpuzzle\s+game\b/i,
      /\bmatching\s+game\b/i,
      /\bcard\s+game\s+simple\b/i,
      /\bclicker\b/i,
      /\bidle\b/i,
    ],
    keywords: ['platformer', 'puzzle', 'match-3', 'memory game', 'whack-a-mole', 'typing game', 'reaction game'],
    weight: -1,
  },

  // Tier 3: Multi-system games (default baseline)
  multiSystem: {
    patterns: [
      /\bshooting\b.*\benemies\b/i,
      /\btop.?down\b.*\bshooter\b/i,
      /\bside.?scroll/i,
      /\bwave.?based\b/i,
      /\bsurvival\b(?!.*crafting|.*building)/i,
    ],
    keywords: ['shooter', 'tower defense', 'racing', 'fighting', 'bullet hell', 'roguelite'],
    weight: 0,
  },

  // Tier 4: Complex multi-system
  complex: {
    patterns: [
      /\binventory\b/i,
      /\bcrafting\b/i,
      /\bskill\s+tree\b/i,
      /\blevel\s+progression\b/i,
      /\bdialogue\s+system\b/i,
      /\bquest\b/i,
      /\bnpc\b/i,
      /\bopen\s+world\b/i,
      /\bprocedural\b/i,
      /\bmultiplayer\b/i,
    ],
    keywords: ['inventory', 'crafting', 'rpg', 'quest', 'dialogue', 'npc', 'skill tree', 'leveling', 'procedural', 'multiplayer', 'co-op'],
    weight: 1,
  },

  // Tier 5: Highly complex / ambitious
  veryComplex: {
    patterns: [
      /\bmmorpg\b/i,
      /\bopen\s+world\b.*\brpg\b/i,
      /\bsimulation\b.*\bcomplex\b/i,
      /\bstrategy\b.*\brts\b/i,
      /\b4x\b/i,
      /\bcity\s+builder\b/i,
      /\bfaction\b.*\bsystem\b/i,
    ],
    keywords: ['mmorpg', 'mmo', 'open world rpg', 'city builder', 'grand strategy', '4x', 'simulation complex', 'economy system'],
    weight: 2,
  },
};

// System complexity markers
const SYSTEM_MARKERS = {
  physics: { patterns: [/\bphysics\b/i, /\bgravity\b/i, /\bragdoll\b/i, /\bcollision\s+detection\b/i], weight: 0.5 },
  ai: { patterns: [/\bai\b/i, /\bpathfinding\b/i, /\benemy\s+behavior\b/i, /\bstate\s+machine\b/i], weight: 0.5 },
  networking: { patterns: [/\bmultiplayer\b/i, /\bonline\b/i, /\bco.?op\b/i, /\bnetwork\b/i], weight: 1.5 },
  persistence: { patterns: [/\bsave\b/i, /\bload\b/i, /\bprogress\b/i, /\bpersist/i], weight: 0.3 },
  audio: { patterns: [/\bmusic\b/i, /\bsound\s+effects\b/i, /\baudio\b/i], weight: 0.2 },
  animation: { patterns: [/\bsprite\s+animation\b/i, /\bskeletal\b/i, /\banimation\s+system\b/i], weight: 0.4 },
  ui: { patterns: [/\bcomplex\s+ui\b/i, /\bmenu\s+system\b/i, /\bhud\b/i, /\binventory\s+ui\b/i], weight: 0.3 },
  rendering3d: { patterns: [/\b3d\b/i, /\bthree\.?js\b/i, /\bwebgl\b/i, /\bshaders\b/i], weight: 0.5 },
};

// Feature count indicators
const FEATURE_INDICATORS = [
  /\band\b/gi,
  /\bwith\b/gi,
  /\balso\b/gi,
  /\bplus\b/gi,
  /\bincluding\b/gi,
  /,/g,
];

function analyzeComplexity(text) {
  const normalizedText = text.toLowerCase().trim();
  let score = 3; // Base tier
  const reasons = [];
  const systemsDetected = [];

  // Check complexity tier patterns
  for (const [tierName, tier] of Object.entries(COMPLEXITY_INDICATORS)) {
    for (const pattern of tier.patterns) {
      if (pattern.test(normalizedText)) {
        score += tier.weight;
        reasons.push(`${tierName}: pattern match (${tier.weight > 0 ? '+' : ''}${tier.weight})`);
        break; // Only count each tier once
      }
    }
    for (const keyword of tier.keywords) {
      if (normalizedText.includes(keyword.toLowerCase())) {
        score += tier.weight * 0.5; // Keywords are weaker signals
        reasons.push(`${tierName}: keyword "${keyword}" (${tier.weight > 0 ? '+' : ''}${tier.weight * 0.5})`);
        break;
      }
    }
  }

  // Check for system markers
  for (const [systemName, system] of Object.entries(SYSTEM_MARKERS)) {
    for (const pattern of system.patterns) {
      if (pattern.test(normalizedText)) {
        score += system.weight;
        systemsDetected.push(systemName);
        reasons.push(`system: ${systemName} (+${system.weight})`);
        break;
      }
    }
  }

  // Feature density check (more "and", "with", commas = more complex)
  let featureCount = 0;
  for (const indicator of FEATURE_INDICATORS) {
    const matches = normalizedText.match(indicator);
    featureCount += matches ? matches.length : 0;
  }
  if (featureCount > 5) {
    const featureBonus = Math.min((featureCount - 5) * 0.1, 1);
    score += featureBonus;
    reasons.push(`feature density: ${featureCount} connectors (+${featureBonus.toFixed(1)})`);
  }

  // Text length as complexity proxy (longer descriptions often = more features)
  const wordCount = normalizedText.split(/\s+/).length;
  if (wordCount > 100) {
    const lengthBonus = Math.min((wordCount - 100) / 200, 0.5);
    score += lengthBonus;
    reasons.push(`description length: ${wordCount} words (+${lengthBonus.toFixed(1)})`);
  }

  // Clamp to 1-5
  const tier = Math.max(1, Math.min(5, Math.round(score)));

  return {
    tier,
    rawScore: score,
    systems: systemsDetected,
    reasons,
  };
}

function getRecommendedConfig(tier, systems) {
  const configs = {
    1: {
      tier: 1,
      tierName: 'simple',
      model: 'gpt-5.4-mini',
      specModel: 'gpt-5.4-mini',
      maxTasks: 5,
      taskTimeout: 1800,
      specTimeout: 600,
      useSubagents: false,
      maxThreads: 2,
      skipSelfReview: true,
      libraries: [],
      description: 'Simple arcade game - minimal resources needed',
    },
    2: {
      tier: 2,
      tierName: 'basic',
      model: 'gpt-5.4-mini',
      specModel: 'gpt-5.4',
      maxTasks: 6,
      taskTimeout: 2400,
      specTimeout: 900,
      useSubagents: false,
      maxThreads: 3,
      skipSelfReview: true,
      libraries: [],
      description: 'Single-mechanic game - light resources',
    },
    3: {
      tier: 3,
      tierName: 'moderate',
      model: 'gpt-5.4',
      specModel: 'gpt-5.4',
      maxTasks: 8,
      taskTimeout: 3600,
      specTimeout: 1200,
      useSubagents: true,
      maxThreads: 4,
      skipSelfReview: false,
      libraries: [],
      description: 'Multi-system game - standard resources',
    },
    4: {
      tier: 4,
      tierName: 'complex',
      model: 'gpt-5.4',
      specModel: 'gpt-5.4',
      maxTasks: 10,
      taskTimeout: 3600,
      specTimeout: 1500,
      useSubagents: true,
      maxThreads: 6,
      skipSelfReview: false,
      libraries: [],
      description: 'Complex game - full resources with subagents',
    },
    5: {
      tier: 5,
      tierName: 'ambitious',
      model: 'gpt-5.4',
      specModel: 'gpt-5.4',
      maxTasks: 15,
      taskTimeout: 3600,
      specTimeout: 1800,
      useSubagents: true,
      maxThreads: 6,
      skipSelfReview: false,
      libraries: [],
      description: 'Ambitious game - maximum resources, consider scope reduction',
      warning: 'This complexity level may exceed what can be achieved in a single autonomous session. Consider breaking into phases.',
    },
  };

  const config = { ...configs[tier] };

  // Add recommended libraries based on detected systems
  if (systems.includes('rendering3d')) {
    config.libraries.push({
      name: 'three.js',
      cdn: 'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.min.js',
      type: 'esm',
    });
  }

  if (systems.includes('physics')) {
    config.libraries.push({
      name: 'matter.js',
      cdn: 'https://cdn.jsdelivr.net/npm/matter-js@0.19.0/build/matter.min.js',
      type: 'umd',
    });
  }

  if (tier >= 3 && !systems.includes('rendering3d')) {
    // For 2D games with moderate+ complexity, suggest a game framework
    config.libraries.push({
      name: 'phaser',
      cdn: 'https://cdn.jsdelivr.net/npm/phaser@3.70.0/dist/phaser.min.js',
      type: 'umd',
      note: 'Optional - vanilla JS is fine for simpler implementations',
    });
  }

  return config;
}

function main() {
  const args = process.argv.slice(2);
  let text = '';
  let jsonOutput = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--file' && args[i + 1]) {
      const filePath = resolve(process.cwd(), args[i + 1]);
      text = readFileSync(filePath, 'utf-8');
      i++;
    } else if (args[i] === '--json') {
      jsonOutput = true;
    } else if (!args[i].startsWith('--')) {
      text = args[i];
    }
  }

  if (!text) {
    console.error('Usage: classify-game-complexity.mjs [--json] [--file <path>] "<game description>"');
    process.exit(1);
  }

  const analysis = analyzeComplexity(text);
  const config = getRecommendedConfig(analysis.tier, analysis.systems);

  if (jsonOutput) {
    console.log(JSON.stringify({ analysis, config }, null, 2));
  } else {
    console.log(`\n=== Game Complexity Analysis ===`);
    console.log(`Tier: ${analysis.tier}/5 (${config.tierName})`);
    console.log(`Description: ${config.description}`);
    if (config.warning) {
      console.log(`⚠️  Warning: ${config.warning}`);
    }
    console.log(`\n--- Detected Systems ---`);
    console.log(analysis.systems.length ? analysis.systems.join(', ') : '(none specific)');
    console.log(`\n--- Analysis Reasons ---`);
    analysis.reasons.forEach((r) => console.log(`  • ${r}`));
    console.log(`\n--- Recommended Configuration ---`);
    console.log(`  Model (tasks): ${config.model}`);
    console.log(`  Model (spec): ${config.specModel}`);
    console.log(`  Max tasks: ${config.maxTasks}`);
    console.log(`  Task timeout: ${config.taskTimeout}s`);
    console.log(`  Spec timeout: ${config.specTimeout}s`);
    console.log(`  Use subagents: ${config.useSubagents}`);
    console.log(`  Max threads: ${config.maxThreads}`);
    console.log(`  Skip self-review: ${config.skipSelfReview}`);
    if (config.libraries.length) {
      console.log(`\n--- Recommended Libraries ---`);
      config.libraries.forEach((lib) => {
        console.log(`  • ${lib.name}: ${lib.cdn}`);
        if (lib.note) console.log(`    (${lib.note})`);
      });
    }
    console.log('');
  }

  // Output env vars for shell consumption
  if (!jsonOutput) {
    console.log('--- Environment Variables (copy to shell) ---');
    console.log(`export GAME_COMPLEXITY_TIER=${analysis.tier}`);
    console.log(`export CODEX_RUN_MODEL="${config.model}"`);
    console.log(`export CODEX_SPEC_MODEL="${config.specModel}"`);
    console.log(`export MAX_TASKS=${config.maxTasks}`);
    console.log(`export TASK_TIMEOUT=${config.taskTimeout}`);
    console.log(`export CODEX_SPEC_TIMEOUT=${config.specTimeout}`);
    console.log(`export USE_SUBAGENTS=${config.useSubagents}`);
    console.log(`export SKIP_SELF_REVIEW=${config.skipSelfReview}`);
  }
}

main();
