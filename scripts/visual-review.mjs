#!/usr/bin/env node

/**
 * Visual Review - Automated screenshot and UI validation
 *
 * Launches the game, captures screenshots at key states, and optionally
 * sends them to a vision model for review.
 *
 * Usage:
 *   node scripts/visual-review.mjs <game-slug>
 *   node scripts/visual-review.mjs snake-game --states load,play,gameover
 *   node scripts/visual-review.mjs snake-game --review  # Send to vision model
 *
 * Requires: npx playwright install chromium (one-time setup)
 */

import { chromium } from 'playwright';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { resolve, join } from 'path';
import { spawn } from 'child_process';

const PROJECT_ROOT = resolve(import.meta.dirname, '..');
const SANDBOX_DIR = join(PROJECT_ROOT, 'sandbox');

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function startServer(gameDir, port = 8080) {
  // Try python first, fall back to npx serve
  const server = spawn('python', ['-m', 'http.server', port.toString()], {
    cwd: gameDir,
    stdio: 'pipe',
  });

  server.on('error', () => {
    // Python failed, try npx serve
    return spawn('npx', ['serve', '-l', port.toString()], {
      cwd: gameDir,
      stdio: 'pipe',
    });
  });

  await sleep(1500); // Wait for server to start
  return server;
}

async function captureScreenshots(gameSlug, states = ['load', 'idle']) {
  const gameDir = join(SANDBOX_DIR, gameSlug);
  const screenshotDir = join(gameDir, 'screenshots');

  if (!existsSync(gameDir)) {
    console.error(`Game not found: ${gameDir}`);
    process.exit(1);
  }

  mkdirSync(screenshotDir, { recursive: true });

  const port = 8080 + Math.floor(Math.random() * 1000);
  const server = await startServer(gameDir, port);
  const url = `http://localhost:${port}`;

  const results = [];

  try {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
    });
    const page = await context.newPage();

    // Capture console errors
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    page.on('pageerror', (err) => {
      consoleErrors.push(err.message);
    });

    console.log(`Loading ${url}...`);
    await page.goto(url, { waitUntil: 'networkidle', timeout: 10000 });

    for (const state of states) {
      const screenshotPath = join(screenshotDir, `${state}.png`);

      switch (state) {
        case 'load':
          // Just capture initial load state
          await sleep(500);
          break;

        case 'idle':
          // Wait a bit for any animations
          await sleep(2000);
          break;

        case 'play':
          // Simulate some keypresses to start game
          await page.keyboard.press('Space');
          await sleep(500);
          await page.keyboard.press('ArrowRight');
          await sleep(1000);
          break;

        case 'gameover':
          // Try to trigger game over (game-specific, may not work)
          for (let i = 0; i < 10; i++) {
            await page.keyboard.press('ArrowUp');
            await sleep(100);
          }
          await sleep(1000);
          break;

        default:
          await sleep(1000);
      }

      await page.screenshot({ path: screenshotPath, fullPage: false });
      console.log(`Captured: ${screenshotPath}`);

      results.push({
        state,
        path: screenshotPath,
        errors: [...consoleErrors],
      });

      // Clear errors between states
      consoleErrors.length = 0;
    }

    await browser.close();

    // Write results summary
    const summaryPath = join(screenshotDir, 'review-summary.json');
    const summary = {
      gameSlug,
      timestamp: new Date().toISOString(),
      screenshots: results,
      hasErrors: results.some((r) => r.errors.length > 0),
    };
    writeFileSync(summaryPath, JSON.stringify(summary, null, 2));

    return summary;
  } finally {
    server.kill();
  }
}

function generateReviewPrompt(summary) {
  const prompt = `You are reviewing screenshots of a browser game called "${summary.gameSlug}".

Analyze these screenshots for:
1. **Visual bugs**: Missing elements, broken layouts, text overflow, z-index issues
2. **UI clarity**: Is the game state clear? Can user understand what to do?
3. **Console errors**: Any JavaScript errors that need fixing?
4. **Playability signals**: Does this look like a working game?

Screenshots captured:
${summary.screenshots.map((s) => `- ${s.state}: ${s.errors.length} console errors`).join('\n')}

${summary.hasErrors ? `\nConsole errors detected:\n${summary.screenshots.flatMap((s) => s.errors).join('\n')}` : ''}

Provide a brief assessment (2-3 sentences) and list any specific issues to fix.
If the game looks functional, say "VISUAL_CHECK_PASS".
If there are blocking issues, say "VISUAL_CHECK_FAIL: <reason>".
`;

  return prompt;
}

async function main() {
  const args = process.argv.slice(2);
  const gameSlug = args[0];

  if (!gameSlug) {
    console.log('Usage: visual-review.mjs <game-slug> [--states state1,state2] [--review]');
    console.log('\nStates: load, idle, play, gameover');
    console.log('--review: Generate prompt for vision model review');
    process.exit(1);
  }

  let states = ['load', 'idle'];
  let generateReview = false;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === '--states' && args[i + 1]) {
      states = args[i + 1].split(',');
      i++;
    } else if (args[i] === '--review') {
      generateReview = true;
    }
  }

  console.log(`\n=== Visual Review: ${gameSlug} ===\n`);

  try {
    const summary = await captureScreenshots(gameSlug, states);

    console.log('\n--- Summary ---');
    console.log(`Screenshots: ${summary.screenshots.length}`);
    console.log(`Console errors: ${summary.hasErrors ? 'YES' : 'None'}`);

    if (summary.hasErrors) {
      console.log('\nErrors found:');
      summary.screenshots.forEach((s) => {
        if (s.errors.length) {
          console.log(`  [${s.state}]: ${s.errors.join(', ')}`);
        }
      });
    }

    if (generateReview) {
      console.log('\n--- Vision Model Prompt ---');
      console.log(generateReviewPrompt(summary));
    }

    console.log(`\nScreenshots saved to: sandbox/${gameSlug}/screenshots/`);
  } catch (err) {
    if (err.message.includes('playwright')) {
      console.error('\nPlaywright not installed. Run: npx playwright install chromium');
    } else {
      console.error('Error:', err.message);
    }
    process.exit(1);
  }
}

main();
