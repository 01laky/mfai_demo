#!/usr/bin/env node
/**
 * Migrate deep relative imports to @/ alias in many_faces_admin (pages, components, routes).
 * Usage: node scripts/migrate-admin-imports-to-alias.mjs [--dry-run]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const admin = path.join(path.resolve(__dirname, '..'), 'many_faces_admin');
const src = path.join(admin, 'src');
const dryRun = process.argv.includes('--dry-run');

const TOP = [
  'contexts',
  'hooks',
  'utils',
  'api',
  'providers',
  'config',
  'types',
  'styles',
  'pages',
  'components',
  'i18n',
  'routes',
];

const DIRS = ['pages', 'components', 'routes'].map((d) => path.join(src, d));

function walkFiles(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walkFiles(p, out);
    else if (/\.tsx?$/.test(ent.name)) out.push(p);
  }
  return out;
}

function migrate(content) {
  let next = content;
  for (const top of TOP) {
    const re = new RegExp(`from (['"])(?:\\.\\./)+${top}/`, 'g');
    next = next.replace(re, `from $1@/${top}/`);
    const scssRe = new RegExp(`@import '(?:\\.\\./)+${top}/`, 'g');
    next = next.replace(scssRe, `@import '@/${top}/`);
  }
  return next;
}

let count = 0;
for (const dir of DIRS) {
  if (!fs.existsSync(dir)) continue;
  for (const file of walkFiles(dir)) {
    const content = fs.readFileSync(file, 'utf8');
    const next = migrate(content);
    if (next !== content) {
      if (dryRun) console.log(path.relative(admin, file));
      else fs.writeFileSync(file, next);
      count += 1;
    }
  }
}

console.log(`migrate-admin-imports-to-alias: ${count} file(s)${dryRun ? ' (dry-run)' : ''}`);
