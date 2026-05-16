#!/usr/bin/env node
/**
 * After colocation: add one ../ level to import/@import paths in moved files.
 * Usage: node scripts/fix-colocated-relative-paths.mjs [components|grid|settings|pages|all]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const portal = path.join(path.resolve(__dirname, '..'), 'many_faces_portal');
const src = path.join(portal, 'src');

const scope = process.argv[2] ?? 'all';

function walk(dir, acc = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, acc);
    else if (/\.(tsx?|scss)$/.test(ent.name)) acc.push(p);
  }
  return acc;
}

/** Only deepen bare `import '../` (not already `import '../../`). */
function fixBareImports(content) {
  return content.replace(/\bimport (['"])\.\.\/(?!\.)/g, 'import $1../../');
}

/** SCSS @import '../ → '../../ when file moved one level deeper. */
function fixScssImports(content) {
  return content.replace(/@import (['"])\.\.\/(?!\.)/g, '@import $1../../');
}

function isColocatedFile(file) {
  const rel = path.relative(src, file);
  const parts = path.dirname(rel).split(path.sep).filter(Boolean);
  if (parts.length < 2) return false;
  const folder = parts[parts.length - 1];
  const base = path.basename(file, path.extname(file));
  return base === folder || file.endsWith('.scss');
}

function inScope(file) {
  const rel = path.relative(src, file);
  switch (scope) {
    case 'components':
      return rel.startsWith(`components${path.sep}`) && !rel.startsWith(`components${path.sep}grid${path.sep}`);
    case 'grid':
      return rel.includes(`${path.sep}grid${path.sep}`) && rel.split(path.sep).filter((p) => p === 'grid').length === 1
        ? false
        : rel.includes(`${path.sep}grid${path.sep}`);
    case 'settings':
      return rel.startsWith(`features${path.sep}settings${path.sep}`);
    case 'pages':
      return rel.startsWith(`pages${path.sep}`);
    default:
      return isColocatedFile(file);
  }
}

let n = 0;
for (const file of walk(src)) {
  if (!inScope(file) || !isColocatedFile(file) || file.endsWith('index.ts')) continue;
  let content = fs.readFileSync(file, 'utf8');
  const next = file.endsWith('.scss')
    ? fixScssImports(content)
    : fixBareImports(content);
  if (next !== content) {
    fs.writeFileSync(file, next);
    n++;
  }
}

console.log(`fix-colocated-relative-paths: updated ${n} files (scope=${scope})`);
