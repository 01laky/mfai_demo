#!/usr/bin/env node
/**
 * Fail when many_faces_admin still has flat component/page TSX files (colocation guard).
 * Usage: node scripts/verify-admin-component-colocation.mjs [--imports] [--phase=2b]
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const admin = path.join(root, 'many_faces_admin');
const src = path.join(admin, 'src');

const checkImports = process.argv.includes('--imports');
const phaseArg = process.argv.find((a) => a.startsWith('--phase='));
const phase = phaseArg ? phaseArg.split('=')[1] : null;

function flatTsx(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((ent) => ent.isFile() && ent.name.endsWith('.tsx'))
    .map((ent) => path.join(dir, ent.name));
}

const errors = [];

for (const f of flatTsx(path.join(src, 'components'))) {
  const base = path.basename(f);
  if (base === 'index.tsx') continue;
  errors.push(`flat component at components root: ${path.relative(root, f)}`);
}

if (!phase || ['3', '4', 'final'].includes(phase)) {
  for (const f of flatTsx(path.join(src, 'components', 'dashboard'))) {
    errors.push(`flat dashboard widget: ${path.relative(root, f)}`);
  }
}

if (!phase || ['2b', '3', '4', 'final'].includes(phase)) {
  for (const f of flatTsx(path.join(src, 'components', 'page-editor'))) {
    errors.push(`flat page-editor component: ${path.relative(root, f)}`);
  }
}

const tablesDir = path.join(src, 'components', 'tables');
if (fs.existsSync(tablesDir)) {
  for (const f of flatTsx(tablesDir)) {
    errors.push(`flat table at tables root: ${path.relative(root, f)}`);
  }
}

if (!phase || phase === '4' || phase === 'final') {
  for (const f of flatTsx(path.join(src, 'pages'))) {
    errors.push(`flat page at pages root: ${path.relative(root, f)}`);
  }
}

const flatFallback = path.join(src, 'routes', 'RouteLoadingFallback.tsx');
if (fs.existsSync(flatFallback)) {
  errors.push(`flat RouteLoadingFallback: ${path.relative(root, flatFallback)}`);
}

if (checkImports) {
  const patterns = [
    "components/[A-Za-z0-9]+\\.tsx",
    "components/dashboard/[A-Za-z0-9]+\\.tsx",
    "components/page-editor/[A-Za-z0-9]+\\.tsx",
    "pages/[A-Za-z0-9]+\\.tsx",
    "routes/RouteLoadingFallback\\.tsx",
  ];
  for (const pat of patterns) {
    const r = spawnSync(
      'grep',
      ['-rE', `from ['\"][^'\"]*${pat.replace(/\\/g, '')}`, src, '--include=*.ts', '--include=*.tsx'],
      { encoding: 'utf8' },
    );
    if (r.stdout?.trim()) {
      errors.push(`imports reference flat path (${pat}):\n${r.stdout.trim()}`);
    }
  }
}

if (errors.length) {
  console.error('verify-admin-component-colocation: FAILED\n');
  for (const e of errors) {
    console.error(`  - ${e}`);
  }
  console.error('\nSee docs/prompts/fe-admin-component-folder-colocation-agent-prompt.md');
  process.exit(1);
}

console.log('verify-admin-component-colocation: OK');
