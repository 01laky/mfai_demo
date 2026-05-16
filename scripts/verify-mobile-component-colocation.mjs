#!/usr/bin/env node
/**
 * Fail when many_faces_mobile still has flat UI TSX files (colocation guard).
 * Usage: node scripts/verify-mobile-component-colocation.mjs [--imports]
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const mobile = path.join(root, 'many_faces_mobile');
const src = path.join(mobile, 'src');

const checkImports = process.argv.includes('--imports');

function flatTsx(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((ent) => ent.isFile() && ent.name.endsWith('.tsx'))
    .map((ent) => path.join(dir, ent.name));
}

function flatTsxInSubdirs(parentDir) {
  if (!fs.existsSync(parentDir)) return [];
  const out = [];
  for (const ent of fs.readdirSync(parentDir, { withFileTypes: true })) {
    if (!ent.isDirectory()) continue;
    for (const f of flatTsx(path.join(parentDir, ent.name))) {
      out.push(f);
    }
  }
  return out;
}

const errors = [];

for (const f of flatTsx(path.join(src, 'components'))) {
  errors.push(`flat component at components root: ${path.relative(root, f)}`);
}

for (const f of flatTsx(path.join(src, 'components', 'wall-tickets'))) {
  errors.push(`flat wall-tickets component: ${path.relative(root, f)}`);
}

for (const f of flatTsx(path.join(src, 'screens'))) {
  errors.push(`flat screen at screens root: ${path.relative(root, f)}`);
}

const flatLayout = path.join(src, 'grid', 'MobilePageLayout.tsx');
if (fs.existsSync(flatLayout)) {
  errors.push(`flat MobilePageLayout: ${path.relative(root, flatLayout)}`);
}

for (const f of flatTsx(path.join(src, 'grid', 'blocks'))) {
  errors.push(`flat grid block: ${path.relative(root, f)}`);
}

for (const f of flatTsxInSubdirs(path.join(src, 'features'))) {
  errors.push(`flat feature component: ${path.relative(root, f)}`);
}

const flatTheme = path.join(src, 'theme', 'AnimatedShellGradient.tsx');
if (fs.existsSync(flatTheme)) {
  errors.push(`flat theme component: ${path.relative(root, flatTheme)}`);
}

if (checkImports) {
  const patterns = [
    '@/components/[A-Za-z0-9]+\\.tsx',
    '@/components/wall-tickets/[A-Za-z0-9]+\\.tsx',
    '@/screens/[A-Za-z0-9]+\\.tsx',
    '@/grid/MobilePageLayout\\.tsx',
    '@/theme/AnimatedShellGradient\\.tsx',
    '@/grid/blocks/[A-Za-z0-9]+\\.tsx',
  ];
  for (const pat of patterns) {
    const r = spawnSync(
      'rg',
      ['-n', pat, src, '--glob', '*.ts', '--glob', '*.tsx'],
      { encoding: 'utf8', cwd: root },
    );
    if (r.stdout?.trim()) {
      errors.push(`imports reference flat path (${pat}):\n${r.stdout.trim()}`);
    }
  }
}

if (errors.length) {
  console.error('verify-mobile-component-colocation: FAILED\n');
  for (const e of errors) {
    console.error(`  - ${e}`);
  }
  console.error('\nSee docs/prompts/fe-mobile-component-folder-colocation-agent-prompt.md');
  process.exit(1);
}

console.log('verify-mobile-component-colocation: OK');
