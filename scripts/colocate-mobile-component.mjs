#!/usr/bin/env node
/**
 * Move a flat many_faces_mobile UI module into a colocated folder.
 * Usage (from monorepo root):
 *   node scripts/colocate-mobile-component.mjs AppShell [--dry-run]
 *   node scripts/colocate-mobile-component.mjs LoginScreen --screen [--dry-run]
 *   node scripts/colocate-mobile-component.mjs MobilePageLayout --grid [--dry-run]
 *   node scripts/colocate-mobile-component.mjs WallTicketsSection --wall-tickets [--dry-run]
 *   node scripts/colocate-mobile-component.mjs AnimatedShellGradient --theme [--dry-run]
 *   node scripts/colocate-mobile-component.mjs AlbumGridBlock --grid-block [--dry-run]
 *   node scripts/colocate-mobile-component.mjs SettingsPanel --feature settings [--dry-run]
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const mobile = path.join(root, 'many_faces_mobile');

const argv = process.argv.slice(2);
const dryRun = argv.includes('--dry-run');
const screen = argv.includes('--screen');
const grid = argv.includes('--grid');
const gridBlock = argv.includes('--grid-block');
const wallTickets = argv.includes('--wall-tickets');
const theme = argv.includes('--theme');
const featureIdx = argv.indexOf('--feature');
const featureArea = featureIdx >= 0 ? argv[featureIdx + 1] : null;
const args = argv.filter(
  (a, i) =>
    !a.startsWith('--') && (featureIdx < 0 || i !== featureIdx + 1 || a !== featureArea),
);

const name = args[0];
if (!name || !/^[A-Z][A-Za-z0-9]*$/.test(name)) {
  console.error(
    'Usage: node scripts/colocate-mobile-component.mjs <PascalCaseName> [--screen|--grid|--grid-block|--wall-tickets|--theme|--feature <area>] [--dry-run]',
  );
  process.exit(1);
}

let baseDir = path.join(mobile, 'src/components');
if (screen) baseDir = path.join(mobile, 'src/screens');
else if (grid) baseDir = path.join(mobile, 'src/grid');
else if (gridBlock) baseDir = path.join(mobile, 'src/grid/blocks');
else if (wallTickets) baseDir = path.join(mobile, 'src/components/wall-tickets');
else if (theme) baseDir = path.join(mobile, 'src/theme');
else if (featureArea) baseDir = path.join(mobile, 'src/features', featureArea);

const tsx = path.join(baseDir, `${name}.tsx`);
const destDir = path.join(baseDir, name);
const destTsx = path.join(destDir, `${name}.tsx`);
const destIndex = path.join(destDir, 'index.ts');

if (!fs.existsSync(tsx)) {
  console.error(`colocate-mobile-component: missing ${tsx}`);
  process.exit(1);
}
if (fs.existsSync(destDir)) {
  console.error(`colocate-mobile-component: already exists ${destDir}`);
  process.exit(1);
}

function run(cmd, cmdArgs, opts = {}) {
  if (dryRun) {
    console.log(`[dry-run] ${cmd} ${cmdArgs.join(' ')}`);
    return;
  }
  const r = spawnSync(cmd, cmdArgs, { stdio: 'inherit', cwd: opts.cwd ?? mobile, ...opts });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

console.log(`Target: ${destDir}`);
run('mkdir', ['-p', destDir]);
run('git', ['mv', tsx, destTsx]);

const indexBody = `export { ${name} } from './${name}';\n`;
if (dryRun) {
  console.log(`[dry-run] write ${destIndex}:\n${indexBody}`);
} else {
  fs.writeFileSync(destIndex, indexBody);
  run('git', ['add', destIndex]);
}

const rel = path.relative(path.join(mobile, 'src'), baseDir);
console.log(`\nColocated ${name} under src/${rel}/${name}/`);
console.log('Import via @/' + rel.replace(/\\/g, '/') + `/${name}`);
