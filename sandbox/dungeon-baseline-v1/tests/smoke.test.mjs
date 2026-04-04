import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const gameDir = path.resolve(testDir, '..');
const briefPath = path.join(gameDir, 'idea.txt');
const entryCandidates = [
  path.join(gameDir, 'index.html'),
  path.join(gameDir, 'game', 'index.html'),
  path.join(gameDir, 'public', 'index.html'),
  path.join(gameDir, 'dist', 'index.html'),
];
const entryPath = entryCandidates.find((candidate) => existsSync(candidate)) ?? null;

function isLocalReference(reference) {
  return (
    reference &&
    !reference.startsWith('#') &&
    !reference.startsWith('data:') &&
    !reference.startsWith('javascript:') &&
    !reference.startsWith('mailto:') &&
    !reference.startsWith('http://') &&
    !reference.startsWith('https://') &&
    !reference.startsWith('//')
  );
}

function collectLocalReferences(html) {
  const pattern = /(?:src|href)=["']([^"'<>]+)["']/g;
  const references = [];
  let match;

  while ((match = pattern.exec(html)) !== null) {
    const reference = match[1].trim();
    if (isLocalReference(reference)) {
      references.push(reference);
    }
  }

  return references;
}

test('original brief file exists', () => {
  assert.equal(existsSync(briefPath), true, 'Expected sandbox/<game-slug>/idea.txt to exist');
});

test('original brief file is not empty', () => {
  const brief = readFileSync(briefPath, 'utf8').trim();
  assert.notEqual(brief, '', 'Expected sandbox/<game-slug>/idea.txt to contain the game brief');
});

test(
  'browser entry file exists after implementation',
  { skip: !entryPath },
  () => {
    assert.ok(entryPath, 'Expected an index.html entry file inside the sandbox workspace');
  },
);

test(
  'entry file includes at least one script tag',
  { skip: !entryPath },
  () => {
    const html = readFileSync(entryPath, 'utf8');
    assert.match(html, /<script\b/i, 'Expected the entry file to include a script tag');
  },
);

test(
  'entry file contains the dungeon blueprint and gameplay HUD shells',
  { skip: !entryPath },
  () => {
    const html = readFileSync(entryPath, 'utf8');
    assert.match(html, /id="dungeon-blueprint"/, 'Expected the single-file artifact to embed its dungeon blueprint.');
    assert.match(html, /id="hud"/, 'Expected the HUD shell to exist.');
    assert.match(html, /id="minimap"/, 'Expected a minimap canvas to exist.');
    assert.match(html, /id="overlay"/, 'Expected a start\/pause\/end overlay to exist.');
  },
);

test(
  'entry file imports Three.js from a pinned CDN module',
  { skip: !entryPath },
  () => {
    const html = readFileSync(entryPath, 'utf8');
    assert.match(
      html,
      /https:\/\/cdn\.jsdelivr\.net\/npm\/three@0\.160\.0\/build\/three\.module\.min\.js/,
      'Expected the artifact to use the pinned Three.js CDN import.',
    );
  },
);

test(
  'local asset references resolve from the entry file',
  { skip: !entryPath },
  () => {
    const html = readFileSync(entryPath, 'utf8');
    const entryDir = path.dirname(entryPath);
    const references = collectLocalReferences(html);

    for (const reference of references) {
      const assetPath = path.resolve(entryDir, reference);
      assert.equal(existsSync(assetPath), true, `Missing local asset reference: ${reference}`);
    }
  },
);
