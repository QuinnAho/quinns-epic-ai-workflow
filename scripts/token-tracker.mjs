#!/usr/bin/env node

/**
 * Token Tracker (Simplified)
 *
 * Parses Codex output for reported token usage and aggregates across sessions.
 * Codex reports tokens at end of run - we just capture and sum those.
 *
 * Usage:
 *   node scripts/token-tracker.mjs parse <log-file>
 *   node scripts/token-tracker.mjs total
 *   node scripts/token-tracker.mjs budget <amount>
 */

import { readFileSync, writeFileSync, existsSync, readdirSync } from 'fs';
import { resolve, join } from 'path';

const PROJECT_ROOT = resolve(import.meta.dirname, '..');
const LOG_DIR = join(PROJECT_ROOT, '.codex-logs');
const TRACKER_FILE = join(LOG_DIR, 'token-usage.json');

// Parse Codex's reported token usage from log output
function parseTokensFromLog(logPath) {
  if (!existsSync(logPath)) return null;

  const content = readFileSync(logPath, 'utf-8');

  // Match Codex token output patterns (adjust regex based on actual Codex output format)
  const tokenMatch = content.match(/tokens?[:\s]+(\d[\d,]*)/gi);
  const costMatch = content.match(/\$[\d.]+/g);

  let tokens = 0;
  let cost = 0;

  if (tokenMatch) {
    tokens = tokenMatch.reduce((sum, m) => {
      const num = parseInt(m.replace(/[^\d]/g, ''), 10);
      return sum + (isNaN(num) ? 0 : num);
    }, 0);
  }

  if (costMatch) {
    cost = parseFloat(costMatch[costMatch.length - 1].replace('$', '')) || 0;
  }

  return { tokens, cost, file: logPath };
}

function loadData() {
  if (existsSync(TRACKER_FILE)) {
    return JSON.parse(readFileSync(TRACKER_FILE, 'utf-8'));
  }
  return { sessions: {}, totalTokens: 0, totalCost: 0 };
}

function saveData(data) {
  writeFileSync(TRACKER_FILE, JSON.stringify(data, null, 2));
}

function main() {
  const [cmd, arg] = process.argv.slice(2);

  if (cmd === 'parse' && arg) {
    const result = parseTokensFromLog(resolve(process.cwd(), arg));
    if (result) {
      console.log(`Tokens: ${result.tokens}, Cost: $${result.cost.toFixed(4)}`);
      const data = loadData();
      data.sessions[arg] = result;
      data.totalTokens += result.tokens;
      data.totalCost += result.cost;
      saveData(data);
    }
  } else if (cmd === 'total') {
    const data = loadData();
    console.log(`Total tokens: ${data.totalTokens.toLocaleString()}`);
    console.log(`Total cost: $${data.totalCost.toFixed(4)}`);
  } else if (cmd === 'budget' && arg) {
    const budget = parseFloat(arg);
    const data = loadData();
    const pct = (data.totalCost / budget) * 100;
    console.log(`Used: $${data.totalCost.toFixed(4)} / $${budget} (${pct.toFixed(1)}%)`);
    console.log(`Recommendation: ${pct > 70 ? 'SWITCH_TO_MINI' : 'CONTINUE'}`);
  } else {
    console.log('Usage: token-tracker.mjs [parse <log>|total|budget <amount>]');
  }
}

main();
