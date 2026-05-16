#!/usr/bin/env node
/**
 * Fix relative import depth inside colocated mobile folders (does not rewrite @/ consumers).
 * Usage: node scripts/fix-mobile-colocated-imports.mjs [--dry-run]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const mobileSrc = path.join(root, 'many_faces_mobile', 'src');
const dryRun = process.argv.includes('--dry-run');

const DEPTH_FIX = [
  { from: /from '\.\.\/\.\.\/\.\.\//g, to: "from '@/" },
  { from: /from "\.\.\/\.\.\/\.\.\//g, to: 'from "@/' },
  { from: /from '\.\.\/\.\.\//g, to: "from '@/" },
  { from: /from "\.\.\/\.\.\//g, to: 'from "@/' },
];

function walk(dir, files = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      if (ent.name === 'node_modules' || ent.name === '__tests__') continue;
      walk(p, files);
    } else if (/\.(ts|tsx)$/.test(ent.name)) {
      files.push(p);
    }
  }
  return files;
}

let changed = 0;
for (const file of walk(mobileSrc)) {
  const parts = path.relative(mobileSrc, file).split(path.sep);
  if (parts.length < 3) continue;
  let text = fs.readFileSync(file, 'utf8');
  let next = text;
  for (const { from, to } of DEPTH_FIX) {
    next = next.replace(from, to);
  }
  if (next !== text) {
    changed += 1;
    if (dryRun) {
      console.log(`would fix ${path.relative(root, file)}`);
    } else {
      fs.writeFileSync(file, next);
      console.log(`fixed ${path.relative(root, file)}`);
    }
  }
}

console.log(dryRun ? `[dry-run] ${changed} file(s)` : `Updated ${changed} file(s).`);
