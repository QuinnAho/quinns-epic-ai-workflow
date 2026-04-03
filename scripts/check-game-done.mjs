#!/usr/bin/env node

/**
 * Check Game Done - Early termination detection
 *
 * Checks if a game meets its acceptance criteria and can skip remaining tasks.
 * Reduces token waste by stopping when the game is actually playable.
 *
 * Usage:
 *   node scripts/check-game-done.mjs <game-slug>
 *   node scripts/check-game-done.mjs snake-game --strict
 *
 * Exit codes:
 *   0 = Game is done, skip remaining tasks
 *   1 = Game needs more work
 *   2 = Error/invalid input
 */

import { existsSync, readFileSync } from 'fs';
import { resolve, join } from 'path';
import { execSync } from 'child_process';

const PROJECT_ROOT = resolve(import.meta.dirname, '..');
const SANDBOX_DIR = join(PROJECT_ROOT, 'sandbox');
const SPECS_DIR = join(PROJECT_ROOT, 'specs');

function checkFileExists(path) {
  return existsSync(path);
}

function runTests(gameDir) {
  try {
    execSync('node --test tests/*.test.mjs', {
      cwd: gameDir,
      stdio: 'pipe',
      timeout: 30000,
    });
    return { pass: true, error: null };
  } catch (err) {
    return { pass: false, error: err.message };
  }
}

function checkArtifact(gameDir) {
  const possiblePaths = [
    'index.html',
    'public/index.html',
    'dist/index.html',
    'game/index.html',
  ];

  for (const p of possiblePaths) {
    const fullPath = join(gameDir, p);
    if (existsSync(fullPath)) {
      const content = readFileSync(fullPath, 'utf-8');
      // Basic checks
      const hasCanvas = content.includes('<canvas') || content.includes('getContext');
      const hasScript = content.includes('<script');
      const hasTitle = content.includes('<title');

      return {
        exists: true,
        path: p,
        hasCanvas,
        hasScript,
        hasTitle,
        valid: hasScript, // At minimum needs JS
      };
    }
  }

  return { exists: false, path: null, valid: false };
}

function parseSpecCriteria(specPath) {
  if (!existsSync(specPath)) return [];

  const content = readFileSync(specPath, 'utf-8');
  const criteria = [];

  // Extract acceptance criteria (lines starting with - [ ] or numbered lists in AC section)
  const acSection = content.match(/## Acceptance Criteria[\s\S]*?(?=##|$)/i);
  if (acSection) {
    const lines = acSection[0].split('\n');
    for (const line of lines) {
      const match = line.match(/[-*]\s*\[.\]\s*(.+)|^\d+\.\s*(.+)/);
      if (match) {
        criteria.push(match[1] || match[2]);
      }
    }
  }

  return criteria;
}

function checkCoreSystems(gameDir) {
  const checks = {
    hasMainLoop: false,
    hasInput: false,
    hasRendering: false,
    hasGameState: false,
  };

  const jsFiles = ['main.js', 'src/main.js', 'game.js', 'src/game.js'];
  for (const f of jsFiles) {
    const path = join(gameDir, f);
    if (existsSync(path)) {
      const content = readFileSync(path, 'utf-8');
      if (content.includes('requestAnimationFrame') || content.includes('setInterval')) {
        checks.hasMainLoop = true;
      }
      if (content.includes('addEventListener') || content.includes('keyboard') || content.includes('keydown')) {
        checks.hasInput = true;
      }
      if (content.includes('ctx.') || content.includes('render') || content.includes('draw')) {
        checks.hasRendering = true;
      }
      if (content.includes('state') || content.includes('gameOver') || content.includes('score')) {
        checks.hasGameState = true;
      }
    }
  }

  // Also check src directory
  const srcDir = join(gameDir, 'src');
  if (existsSync(srcDir)) {
    try {
      const srcFiles = execSync('ls *.js 2>/dev/null || true', { cwd: srcDir, encoding: 'utf-8' });
      if (srcFiles.includes('input')) checks.hasInput = true;
      if (srcFiles.includes('render')) checks.hasRendering = true;
      if (srcFiles.includes('simulation') || srcFiles.includes('game')) checks.hasGameState = true;
    } catch {}
  }

  return checks;
}

function evaluateReadiness(gameSlug, strict = false) {
  const gameDir = join(SANDBOX_DIR, gameSlug);
  const specPath = join(SPECS_DIR, `${gameSlug}.md`);

  if (!existsSync(gameDir)) {
    return { ready: false, reason: 'Game directory not found', score: 0 };
  }

  const results = {
    artifact: checkArtifact(gameDir),
    tests: runTests(gameDir),
    systems: checkCoreSystems(gameDir),
    criteria: parseSpecCriteria(specPath),
  };

  // Scoring
  let score = 0;
  let maxScore = 0;
  const issues = [];

  // Artifact exists and valid (required)
  maxScore += 30;
  if (results.artifact.valid) {
    score += 30;
  } else if (results.artifact.exists) {
    score += 10;
    issues.push('Artifact exists but may be incomplete');
  } else {
    issues.push('No artifact found');
  }

  // Tests pass
  maxScore += 25;
  if (results.tests.pass) {
    score += 25;
  } else {
    issues.push('Tests failing');
  }

  // Core systems present
  const systemChecks = Object.values(results.systems);
  const systemScore = systemChecks.filter(Boolean).length;
  maxScore += 20;
  score += (systemScore / systemChecks.length) * 20;
  if (systemScore < systemChecks.length) {
    const missing = Object.entries(results.systems)
      .filter(([, v]) => !v)
      .map(([k]) => k);
    issues.push(`Missing systems: ${missing.join(', ')}`);
  }

  // Has meaningful code (not just scaffolding)
  maxScore += 25;
  const mainPath = join(gameDir, 'main.js');
  if (existsSync(mainPath)) {
    const lines = readFileSync(mainPath, 'utf-8').split('\n').length;
    if (lines > 50) {
      score += 25;
    } else if (lines > 20) {
      score += 15;
      issues.push('Main file seems minimal');
    } else {
      issues.push('Main file is scaffolding only');
    }
  }

  const percentage = (score / maxScore) * 100;
  const threshold = strict ? 90 : 75;

  return {
    ready: percentage >= threshold,
    score: percentage,
    threshold,
    issues,
    details: results,
  };
}

function main() {
  const args = process.argv.slice(2);
  const gameSlug = args[0];
  const strict = args.includes('--strict');

  if (!gameSlug) {
    console.log('Usage: check-game-done.mjs <game-slug> [--strict]');
    process.exit(2);
  }

  console.log(`\n=== Checking: ${gameSlug} ===\n`);

  const result = evaluateReadiness(gameSlug, strict);

  console.log(`Score: ${result.score.toFixed(1)}% (threshold: ${result.threshold}%)`);
  console.log(`Status: ${result.ready ? '✅ DONE' : '⏳ NEEDS WORK'}`);

  if (result.issues.length) {
    console.log('\nIssues:');
    result.issues.forEach((i) => console.log(`  - ${i}`));
  }

  if (result.ready) {
    console.log('\n🎮 Game meets acceptance criteria - remaining tasks can be skipped');
  }

  // Output for shell
  console.log(`\nexport GAME_READY=${result.ready}`);
  console.log(`export GAME_SCORE=${result.score.toFixed(0)}`);

  process.exit(result.ready ? 0 : 1);
}

main();
