#!/usr/bin/env node

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const defaultProjectRoot = path.resolve(__dirname, '..');

function usage() {
  console.error('Usage: node scripts/build-spec-generation-context.mjs --slug <game-slug> [--game-name <name>] [--complexity-tier <tier>]');
}

function parseArgs(argv) {
  const options = {
    slug: '',
    gameName: '',
    complexityTier: 'unknown',
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];

    if (value === '--slug') {
      options.slug = argv[index + 1] ?? '';
      index += 1;
      continue;
    }

    if (value === '--game-name') {
      options.gameName = argv[index + 1] ?? '';
      index += 1;
      continue;
    }

    if (value === '--complexity-tier') {
      options.complexityTier = argv[index + 1] ?? 'unknown';
      index += 1;
      continue;
    }

    console.error(`Unknown argument: ${value}`);
    usage();
    process.exit(1);
  }

  if (!options.slug) {
    usage();
    process.exit(1);
  }

  return options;
}

function toPosix(value) {
  return value.split(path.sep).join('/');
}

function relFromRoot(rootPath, targetPath) {
  return toPosix(path.relative(rootPath, targetPath));
}

function readText(filePath) {
  if (!existsSync(filePath)) {
    return '';
  }

  return readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n').trim();
}

function titleizeSlug(slug) {
  return slug
    .split('-')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function extractTemplateHeadings(markdown) {
  return markdown
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => /^(##|###)\s+/.test(line));
}

function shouldSkipWorkspaceEntry(entry) {
  return entry === 'release' || entry === 'node_modules';
}

function listFiles(rootPath, maxDepth = 2, maxItems = 40) {
  if (!existsSync(rootPath)) {
    return [];
  }

  const items = [];

  function walk(currentPath, depth) {
    if (items.length >= maxItems || depth > maxDepth) {
      return;
    }

    const entries = readdirSync(currentPath).sort((left, right) => left.localeCompare(right));
    for (const entry of entries) {
      if (items.length >= maxItems) {
        return;
      }

      if (shouldSkipWorkspaceEntry(entry)) {
        continue;
      }

      const fullPath = path.join(currentPath, entry);
      const stats = statSync(fullPath);
      const relative = relFromRoot(rootPath, fullPath);

      if (stats.isDirectory()) {
        items.push(`${relative}/`);
        walk(fullPath, depth + 1);
        continue;
      }

      items.push(relative);
    }
  }

  walk(rootPath, 0);
  return items;
}

function listTestFiles(projectRoot, testsPath) {
  if (!existsSync(testsPath)) {
    return [];
  }

  return listFiles(projectRoot, 3, 60).filter((entry) => entry.endsWith('.mjs') || entry.endsWith('.js'));
}

function findExistingArtifacts(projectRoot, gameDir) {
  const candidates = [
    path.join(gameDir, 'index.html'),
    path.join(gameDir, 'game', 'index.html'),
    path.join(gameDir, 'public', 'index.html'),
    path.join(gameDir, 'dist', 'index.html'),
  ];

  return candidates.filter((candidate) => existsSync(candidate)).map((candidate) => relFromRoot(projectRoot, candidate));
}

function getGitSummary(projectRoot, paths) {
  const result = spawnSync(
    'git',
    ['status', '--short', '--branch', '--', ...paths],
    {
      cwd: projectRoot,
      encoding: 'utf8',
    },
  );

  if (result.error || result.status !== 0) {
    return [];
  }

  return result.stdout
    .replace(/\r\n/g, '\n')
    .trim()
    .split('\n')
    .map((line) => line.trimEnd())
    .filter(Boolean);
}

function buildIndentedList(items, emptyLine) {
  if (items.length === 0) {
    return [`- ${emptyLine}`];
  }

  return items.map((item) => `- ${item}`);
}

function buildTextBlock(title, body) {
  const normalized = body.trim();
  const lines = [`### ${title}`];

  if (!normalized) {
    lines.push('_Missing_');
    return lines.join('\n');
  }

  lines.push('```text');
  lines.push(normalized);
  lines.push('```');
  return lines.join('\n');
}

export function buildSpecGenerationContext(options) {
  const slug = options.slug;
  const gameName = options.gameName || titleizeSlug(slug) || 'Game Spec';
  const complexityTier = options.complexityTier ?? 'unknown';
  const projectRoot = options.projectRootOverride
    ? path.resolve(options.projectRootOverride)
    : defaultProjectRoot;

  const specPath = path.join(projectRoot, 'specs', `${slug}.md`);
  const gameDir = path.join(projectRoot, 'sandbox', slug);
  const testsDir = path.join(gameDir, 'tests');
  const ideaPath = path.join(gameDir, 'idea.txt');
  const clarificationsPath = path.join(gameDir, 'clarifications.txt');
  const intakePath = path.join(gameDir, 'intake.md');
  const baselineRefPath = path.join(gameDir, 'baseline-ref.txt');
  const templatePath = path.join(projectRoot, 'specs', '_template.md');
  const statusPath = path.join(projectRoot, 'STATUS.md');

  const templateHeadings = extractTemplateHeadings(readText(templatePath));
  const workspaceFiles = listFiles(gameDir, 2, 50);
  const testFiles = listTestFiles(projectRoot, testsDir);
  const artifactCandidates = findExistingArtifacts(projectRoot, gameDir);
  const gitSummary = getGitSummary(projectRoot, [
    `sandbox/${slug}`,
    `specs/${slug}.md`,
    'PROJECT.md',
    'AGENTS.md',
    'STATUS.md',
  ]);

  const statusSnapshot = (() => {
    const statusText = readText(statusPath);
    if (!statusText) {
      return 'STATUS.md missing.';
    }

    const lines = statusText
      .split('\n')
      .map((line) => line.trim())
      .filter((line) =>
        line.startsWith('- **Timestamp**:') ||
        line.startsWith('- **Session ID**:') ||
        line.startsWith('- **Entry file**:') ||
        line.startsWith('- **Launch command**:') ||
        line.startsWith('- **Last known result**:') ||
        line.startsWith('- **Notes**:')
      );

    if (lines.length === 0) {
      return 'No status snapshot lines found.';
    }

    return lines.join('\n');
  })();

  const output = [
    '# Spec Generation Context',
    '',
    'Use this context bundle as authoritative for spec generation and clarification intake.',
    'Do not begin by re-analyzing repo-wide files when this bundle already contains the needed state.',
    '',
    '## Active Game',
    `- Game name: ${gameName}`,
    `- Game slug: ${slug}`,
    `- Complexity tier: ${complexityTier}/5`,
    `- Spec path: ${relFromRoot(projectRoot, specPath)}`,
    `- Game workspace: ${relFromRoot(projectRoot, gameDir)}/`,
    `- Default artifact path: sandbox/${slug}/index.html`,
    `- Default test harness: sandbox/${slug}/tests/`,
    '',
    '## Workflow Contract',
    '- This repo is a Codex-only workflow for generating and repairing browser games.',
    '- Each game stays inside sandbox/<game-slug>/ unless a shared workflow file must be edited.',
    '- Acceptable artifact layouts are sandbox/<game-slug>/index.html, game/index.html, public/index.html, or dist/index.html.',
    '- Prefer the smallest playable v0 over speculative architecture or feature sprawl.',
    '- Movement, cooldowns, animation, and AI timing must use delta time.',
    '- Collision should stop the player before wall penetration and AI should respect world geometry.',
    '- Keep the world layout, collision, and minimap data aligned from a shared source of truth when relevant.',
    '- Reuse and extend sandbox/<game-slug>/tests/ when logic can be tested; otherwise add the smallest useful smoke check.',
    '- Record the artifact path and launch method in STATUS.md once implementation begins.',
    '- For non-trivial implementation work, self-review with code_reviewer and spec_validator before declaring completion.',
    '- Completion signals are TASK_COMPLETE, BLOCKED, ALL_TASKS_DONE, and RATE_LIMITED.',
    '',
    '## Existing Shared State',
    buildTextBlock('STATUS Snapshot', statusSnapshot),
    '',
    '## Spec Template Outline',
    ...buildIndentedList(templateHeadings, 'Template headings unavailable.'),
    '',
    '## Game Workspace Snapshot',
    `- Workspace exists: ${existsSync(gameDir) ? 'yes' : 'no'}`,
    `- Existing spec file: ${existsSync(specPath) ? 'yes' : 'no'}`,
    ...buildIndentedList(artifactCandidates, 'No artifact candidates found yet.'),
    '',
    '### Workspace Files (depth <= 2)',
    ...buildIndentedList(workspaceFiles, 'No workspace files found yet.'),
    '',
    '### Test Files',
    ...buildIndentedList(testFiles, 'No test files found.'),
    '',
    buildTextBlock('Baseline Reference', readText(baselineRefPath)),
    '',
    '## Relevant Git Status',
    ...buildIndentedList(gitSummary, 'No git status output for the active game paths.'),
    '',
    '## Intake Snapshot',
    buildTextBlock('idea.txt', readText(ideaPath)),
    '',
    buildTextBlock('clarifications.txt', readText(clarificationsPath)),
    '',
    buildTextBlock('intake.md', readText(intakePath)),
    '',
  ].join('\n');

  return `${output}\n`;
}

function main() {
  process.stdout.write(buildSpecGenerationContext(parseArgs(process.argv.slice(2))));
}

const isMainModule =
  typeof process.argv[1] === 'string' &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMainModule) {
  main();
}
