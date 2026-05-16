#!/usr/bin/env node
/**
 * Fail when many_faces_portal still has flat component TSX files (colocation rollout guard).
 * Usage: node scripts/verify-portal-component-colocation.mjs [--imports]
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const portal = path.join(root, 'many_faces_portal');
const checkImports = process.argv.includes('--imports');

function flatTsx(dir, maxDepth = 1) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!ent.isFile() || !ent.name.endsWith('.tsx')) continue;
    out.push(path.join(dir, ent.name));
  }
  return out;
}

const errors = [];

const componentsRoot = path.join(portal, 'src/components');
for (const f of flatTsx(componentsRoot)) {
  const base = path.basename(f);
  if (base === 'index.tsx') continue;
  errors.push(`flat component at components root: ${path.relative(root, f)}`);
}

const gridRoot = path.join(componentsRoot, 'grid');
for (const f of flatTsx(gridRoot)) {
  errors.push(`flat grid block at grid root: ${path.relative(root, f)}`);
}

if (checkImports) {
  const r = spawnSync(
    'rg',
    [
      "from ['\"][^'\"]*components/(grid/)?[A-Za-z0-9]+\\.(tsx|scss)['\"]",
      'many_faces_portal/src',
    ],
    { cwd: root, encoding: 'utf8' },
  );
  if (r.stdout?.trim()) {
    errors.push(`imports still reference flat .tsx/.scss paths:\n${r.stdout.trim()}`);
  }
}

if (errors.length) {
  console.error('verify-portal-component-colocation: FAILED\n');
  for (const e of errors) {
    console.error(`  - ${e}`);
  }
  console.error(
    '\nSee docs/prompts/fe-portal-component-folder-colocation-agent-prompt.md',
  );
  process.exit(1);
}

console.log('verify-portal-component-colocation: OK (no flat component TSX at components/ or grid/ roots)');
