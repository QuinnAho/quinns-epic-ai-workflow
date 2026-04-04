import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const gameDir = path.resolve(testDir, '..');
const entryPath = path.join(gameDir, 'index.html');
const html = readFileSync(entryPath, 'utf8');

function extractBlueprint(documentText) {
  const match = documentText.match(
    /<script id="dungeon-blueprint" type="application\/json">([\s\S]*?)<\/script>/i,
  );

  assert.ok(match, 'Expected an embedded dungeon blueprint JSON script tag.');
  return JSON.parse(match[1]);
}

const blueprint = extractBlueprint(html);
const mapRows = blueprint.map;
const mapHeight = mapRows.length;
const mapWidth = mapRows[0].length;

function isWithinMap(col, row) {
  return col >= 0 && row >= 0 && col < mapWidth && row < mapHeight;
}

function isWall(col, row) {
  return !isWithinMap(col, row) || mapRows[row][col] === '#';
}

function cellKey(col, row, keysMask, doorMask) {
  return `${col},${row},${keysMask},${doorMask}`;
}

function buildDoorLookup() {
  const lookup = new Map();
  blueprint.doors.forEach((door, index) => {
    for (const [col, row] of door.cells) {
      lookup.set(`${col},${row}`, index);
    }
  });
  return lookup;
}

const doorLookup = buildDoorLookup();

function countBits(mask, length) {
  let count = 0;
  for (let index = 0; index < length; index += 1) {
    if (mask & (1 << index)) {
      count += 1;
    }
  }
  return count;
}

function progressionExitReachable() {
  const start = blueprint.player.spawn;
  const goal = blueprint.exit.cell;
  const keyLookup = new Map(blueprint.keys.map((key, index) => [`${key.cell[0]},${key.cell[1]}`, index]));
  const queue = [{ col: start[0], row: start[1], keysMask: 0, doorMask: 0 }];
  const seen = new Set([cellKey(start[0], start[1], 0, 0)]);
  const directions = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  while (queue.length > 0) {
    const current = queue.shift();
    if (current.col === goal[0] && current.row === goal[1]) {
      return true;
    }

    for (const [dx, dy] of directions) {
      const nextCol = current.col + dx;
      const nextRow = current.row + dy;
      if (isWall(nextCol, nextRow)) {
        continue;
      }

      let nextKeysMask = current.keysMask;
      let nextDoorMask = current.doorMask;
      const doorIndex = doorLookup.get(`${nextCol},${nextRow}`);

      if (doorIndex !== undefined && (nextDoorMask & (1 << doorIndex)) === 0) {
        const keysOwned =
          countBits(nextKeysMask, blueprint.keys.length) - countBits(nextDoorMask, blueprint.doors.length);
        if (keysOwned <= 0) {
          continue;
        }
        nextDoorMask |= 1 << doorIndex;
      }

      const keyIndex = keyLookup.get(`${nextCol},${nextRow}`);
      if (keyIndex !== undefined) {
        nextKeysMask |= 1 << keyIndex;
      }

      const signature = cellKey(nextCol, nextRow, nextKeysMask, nextDoorMask);
      if (!seen.has(signature)) {
        seen.add(signature);
        queue.push({ col: nextCol, row: nextRow, keysMask: nextKeysMask, doorMask: nextDoorMask });
      }
    }
  }

  return false;
}

test('blueprint includes the expected progression shape', () => {
  assert.equal(blueprint.keys.length, 2, 'Expected exactly two keys in the first playable dungeon.');
  assert.equal(blueprint.doors.length, 2, 'Expected exactly two locked gates in the first playable dungeon.');
  assert.ok(blueprint.enemies.length >= 3, 'Expected at least three enemies for the combat loop.');
});

test('player spawn, keys, doors, and exit are on traversable floor cells', () => {
  const cellsToCheck = [
    blueprint.player.spawn,
    blueprint.exit.cell,
    ...blueprint.keys.map((key) => key.cell),
    ...blueprint.doors.flatMap((door) => door.cells),
  ];

  for (const [col, row] of cellsToCheck) {
    assert.equal(isWall(col, row), false, `Cell ${col},${row} should be traversable.`);
  }
});

test('enemy patrol routes stay on dungeon floor cells', () => {
  for (const enemy of blueprint.enemies) {
    assert.equal(isWall(enemy.spawn[0], enemy.spawn[1]), false, `Enemy ${enemy.id} spawns inside a wall.`);
    for (const [col, row] of enemy.patrol) {
      assert.equal(isWall(col, row), false, `Enemy ${enemy.id} has a patrol point inside a wall at ${col},${row}.`);
    }
  }
});

test('the dungeon progression graph can reach the exit while spending keys on doors', () => {
  assert.equal(
    progressionExitReachable(),
    true,
    'Expected the embedded blueprint to permit a full key-door path from spawn to exit.',
  );
});
