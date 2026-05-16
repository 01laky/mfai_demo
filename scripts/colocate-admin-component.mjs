#!/usr/bin/env node
/**
 * Move a flat many_faces_admin component (TSX + optional SCSS) into a colocated folder.
 * Usage (from monorepo root):
 *   node scripts/colocate-admin-component.mjs Header [--dry-run]
 *   node scripts/colocate-admin-component.mjs DashboardCharts --dashboard
 *   node scripts/colocate-admin-component.mjs GridLayoutEditor --page-editor
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const admin = path.join(root, 'many_faces_admin');

const argv = process.argv.slice(2);
const dryRun = argv.includes('--dry-run');
const dashboard = argv.includes('--dashboard');
const pageEditor = argv.includes('--page-editor');
const tables = argv.includes('--tables');
const args = argv.filter((a) => !a.startsWith('--'));

const name = args[0];
if (!name || !/^[A-Z][A-Za-z0-9]*$/.test(name)) {
  console.error(
    'Usage: node scripts/colocate-admin-component.mjs <PascalCaseName> [--dashboard|--page-editor|--tables] [--dry-run]',
  );
  process.exit(1);
}

let baseDir = path.join(admin, 'src/components');
if (dashboard) baseDir = path.join(baseDir, 'dashboard');
else if (pageEditor) baseDir = path.join(baseDir, 'page-editor');
else if (tables) baseDir = path.join(baseDir, 'tables');

const tsx = path.join(baseDir, `${name}.tsx`);
const scss = path.join(baseDir, `${name}.scss`);
const destDir = path.join(baseDir, name);
const destTsx = path.join(destDir, `${name}.tsx`);
const destScss = path.join(destDir, `${name}.scss`);
const destIndex = path.join(destDir, 'index.ts');

if (!fs.existsSync(tsx)) {
  console.error(`colocate-admin-component: missing ${tsx}`);
  process.exit(1);
}
if (fs.existsSync(destDir)) {
  console.error(`colocate-admin-component: already exists ${destDir}`);
  process.exit(1);
}

function run(cmd, cmdArgs, opts = {}) {
  if (dryRun) {
    console.log(`[dry-run] ${cmd} ${cmdArgs.join(' ')}`);
    return;
  }
  const r = spawnSync(cmd, cmdArgs, { stdio: 'inherit', cwd: opts.cwd ?? admin, ...opts });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

console.log(`Target: ${destDir}`);
run('mkdir', ['-p', destDir]);
run('git', ['mv', tsx, destTsx]);
if (fs.existsSync(scss)) {
  run('git', ['mv', scss, destScss]);
}

const indexBody = `export { ${name} } from './${name}';\n`;
if (dryRun) {
  console.log(`[dry-run] write ${destIndex}:\n${indexBody}`);
} else {
  fs.writeFileSync(destIndex, indexBody);
  run('git', ['add', destIndex]);
}

const rel = path.relative(path.join(admin, 'src'), baseDir);
console.log(`\nColocated ${name} under src/${rel}/${name}/`);
console.log('Run: node scripts/fix-admin-colocated-relative-paths.mjs');
console.log('Then: cd many_faces_admin && yarn validate && yarn test && yarn build');
