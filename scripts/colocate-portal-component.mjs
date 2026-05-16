#!/usr/bin/env node
/**
 * Move a flat many_faces_portal component (TSX + optional SCSS) into a colocated folder.
 * Usage (from monorepo root):
 *   node scripts/colocate-portal-component.mjs Header [--dry-run]
 *   node scripts/colocate-portal-component.mjs Blog --grid [--dry-run]
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const portal = path.join(root, 'many_faces_portal');

const args = process.argv.slice(2).filter((a) => a !== '--dry-run' && a !== '--grid');
const dryRun = process.argv.includes('--dry-run');
const grid = process.argv.includes('--grid');

const name = args[0];
if (!name || !/^[A-Z][A-Za-z0-9]*$/.test(name)) {
  console.error('Usage: node scripts/colocate-portal-component.mjs <PascalCaseName> [--grid] [--dry-run]');
  process.exit(1);
}

const baseDir = grid
  ? path.join(portal, 'src/components/grid')
  : path.join(portal, 'src/components');

const tsx = path.join(baseDir, `${name}.tsx`);
const scss = path.join(baseDir, `${name}.scss`);
const destDir = path.join(baseDir, name);
const destTsx = path.join(destDir, `${name}.tsx`);
const destScss = path.join(destDir, `${name}.scss`);
const destIndex = path.join(destDir, 'index.ts');

if (!fs.existsSync(tsx)) {
  console.error(`colocate-portal-component: missing ${tsx}`);
  process.exit(1);
}
if (fs.existsSync(destDir)) {
  console.error(`colocate-portal-component: already exists ${destDir}`);
  process.exit(1);
}

function run(cmd, cmdArgs) {
  if (dryRun) {
    console.log(`[dry-run] ${cmd} ${cmdArgs.join(' ')}`);
    return;
  }
  const r = spawnSync(cmd, cmdArgs, { stdio: 'inherit', cwd: root });
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

const relBase = grid ? 'components/grid' : 'components';
const patterns = [
  `${relBase}/${name}.tsx`,
  `${relBase}/${name}.scss`,
  `${relBase}/${name}'`,
  `${relBase}/${name}"`,
];

console.log('\nUpdate importers (manual or IDE refactor):');
for (const p of patterns) {
  const r = spawnSync('rg', ['-l', p, 'many_faces_portal/src'], { cwd: root, encoding: 'utf8' });
  if (r.stdout?.trim()) {
    console.log(r.stdout.trim());
  }
}

console.log(`\nSuggested import: from '.../${relBase}/${name}'`);
console.log('Then: cd many_faces_portal && yarn validate && yarn test && yarn build');
