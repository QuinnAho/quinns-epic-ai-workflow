import test from 'node:test';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { buildSpecGenerationContext } from '../build-spec-generation-context.mjs';

function createFixtureRoot() {
  const root = mkdtempSync(path.join(os.tmpdir(), 'context-builder-'));
  mkdirSync(path.join(root, 'sandbox'), { recursive: true });
  mkdirSync(path.join(root, 'specs'), { recursive: true });
  writeFileSync(path.join(root, 'specs', '_template.md'), ['## Overview', '### Game Concept', '## Task Breakdown', ''].join('\n'));
  writeFileSync(
    path.join(root, 'STATUS.md'),
    [
      '- **Timestamp**: fixture',
      '- **Session ID**: fixture',
      '- **Entry file**: not recorded',
      '- **Launch command**: not recorded',
      '- **Last known result**: fixture',
      '- **Notes**: fixture',
      '',
    ].join('\n'),
  );
  return root;
}

test('build-spec-generation-context emits the deterministic sections for a temporary sandbox game', () => {
  const fixtureRoot = createFixtureRoot();
  const slug = 'temporary-context-game';
  const gameDir = path.join(fixtureRoot, 'sandbox', slug);

  try {
    mkdirSync(path.join(gameDir, 'tests'), { recursive: true });
    writeFileSync(path.join(gameDir, 'idea.txt'), 'Arcade prototype brief');
    writeFileSync(path.join(gameDir, 'clarifications.txt'), 'No additional answer provided.');
    writeFileSync(path.join(gameDir, 'intake.md'), '# Intake\n\nTemporary context bundle test.');
    writeFileSync(path.join(gameDir, 'baseline-ref.txt'), 'baseline_commit=abc123');
    writeFileSync(path.join(gameDir, 'index.html'), '<!doctype html><title>Temp Game</title>');
    writeFileSync(path.join(gameDir, 'tests', 'smoke.test.mjs'), 'export {};');

    const output = buildSpecGenerationContext({
      slug,
      gameName: 'Temporary Context Game',
      complexityTier: '2',
      projectRootOverride: fixtureRoot,
    });

    assert.match(output, /^# Spec Generation Context/m);
    assert.match(output, /- Game slug: temporary-context-game/);
    assert.match(output, /## Workflow Contract/);
    assert.match(output, /## Spec Template Outline/);
    assert.match(output, /## Game Workspace Snapshot/);
    assert.match(output, /sandbox\/temporary-context-game\/tests\//);
  } finally {
    rmSync(fixtureRoot, { recursive: true, force: true });
  }
});

test('build-spec-generation-context handles a missing sandbox workspace without crashing', () => {
  const fixtureRoot = createFixtureRoot();

  try {
    const output = buildSpecGenerationContext({
      slug: 'missing-context-game',
      gameName: 'Missing Context Game',
      complexityTier: '1',
      projectRootOverride: fixtureRoot,
    });

    assert.match(output, /^# Spec Generation Context/m);
    assert.match(output, /- Game slug: missing-context-game/);
    assert.match(output, /## Workflow Contract/);
    assert.match(output, /- Workspace exists: no/);
    assert.match(output, /No workspace files found yet/);
  } finally {
    rmSync(fixtureRoot, { recursive: true, force: true });
  }
});
