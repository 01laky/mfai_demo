#!/usr/bin/env node
/**
 * Normalize relative imports to src/* after admin colocation (idempotent).
 * Usage: node scripts/fix-admin-colocated-relative-paths.mjs [--dry-run]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const admin = path.join(root, 'many_faces_admin');
const src = path.join(admin, 'src');
const dryRun = process.argv.includes('--dry-run');

const SRC_TOP = [
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

function walk(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      if (ent.name === 'node_modules') continue;
      walk(p, out);
    } else if (/\.(tsx?|scss)$/.test(ent.name)) {
      out.push(p);
    }
  }
  return out;
}

function upToSrc(filePath) {
  const relDir = path.relative(src, path.dirname(filePath));
  const depth = relDir === '' ? 0 : relDir.split(path.sep).length;
  return depth === 0 ? './' : '../'.repeat(depth);
}

function fixFile(filePath) {
  if (path.basename(filePath) === 'index.ts') return false;

  const prefix = upToSrc(filePath);
  let content = fs.readFileSync(filePath, 'utf8');
  let next = content;

  for (const top of SRC_TOP) {
    const re = new RegExp(`from (['"])(?:\\.\\./)+${top}/`, 'g');
    next = next.replace(re, `from $1${prefix}${top}/`);
    const scssRe = new RegExp(`@import '(?:\\.\\./)+${top}/`, 'g');
    next = next.replace(scssRe, `@import '${prefix}${top}/`);
  }

  const rel = path.relative(src, filePath);
  const parts = rel.split(path.sep);

  if (parts[0] === 'components' && parts.length === 3 && parts[1] !== 'radix') {
    next = next
      .replace(/from '\.\/radix\//g, "from '../radix/")
      .replace(/from "\.\/radix\//g, 'from "../radix/')
      .replace(/from '\.\/LanguageSwitcher'/g, "from '../LanguageSwitcher'");
  }

  if (parts[0] === 'components' && parts[1] === 'tables' && parts.length === 4) {
    next = next
      .replace(/from '\.\.\/radix\//g, "from '@/components/radix/")
      .replace(/from '\.\/radix\//g, "from '@/components/radix/")
      .replace(/from "\.\.\/radix\//g, 'from "@/components/radix/')
      .replace(/from "\.\/radix\//g, 'from "@/components/radix/');
  }

  if (parts[0] === 'components' && parts[1] === 'page-editor' && parts.length === 4) {
    next = next
      .replace(/from '\.\/ComponentPickerModal'/g, "from '../ComponentPickerModal'")
      .replace(/from '\.\/GridLayoutEditor'/g, "from '../GridLayoutEditor'")
      .replace(/from '\.\/GradientPicker'/g, "from '../GradientPicker'")
      .replace(/from '\.\/radix\//g, `from '${prefix}components/radix/`)
      .replace(/from "\.\/radix\//g, `from "${prefix}components/radix/`);
  }

  if (parts[0] === 'pages' && parts.length >= 3) {
    next = next
      .replace(
        /import '\.\/UserFormPage\.scss'/g,
        `import '${prefix}styles/forms/UserFormPage.scss'`,
      )
      .replace(
        /import '\.\/FaceFormPage\.scss'/g,
        `import '${prefix}styles/forms/FaceFormPage.scss'`,
      )
      .replace(
        /import '\.\/PageFormPage\.scss'/g,
        `import '${prefix}styles/forms/PageFormPage.scss'`,
      )
      .replace(
        /import '\.\.\/\.\.\/styles\/forms\//g,
        `import '${prefix}styles/forms/`,
      );
  }

  if (next !== content) {
    if (dryRun) console.log(`fix ${rel}`);
    else fs.writeFileSync(filePath, next);
    return true;
  }
  return false;
}

function fixPageEditorImporters() {
  const replacements = [
    [
      "from '../components/GridLayoutEditor'",
      "from '../components/page-editor/GridLayoutEditor'",
    ],
    [
      "from '../components/GradientPicker'",
      "from '../components/page-editor/GradientPicker'",
    ],
  ];
  for (const file of walk(src)) {
    if (!/\.tsx?$/.test(file)) continue;
    let content = fs.readFileSync(file, 'utf8');
    let changed = false;
    for (const [from, to] of replacements) {
      if (content.includes(from)) {
        content = content.split(from).join(to);
        changed = true;
      }
    }
    if (changed) {
      if (dryRun) console.log(`page-editor import: ${path.relative(src, file)}`);
      else fs.writeFileSync(file, content);
    }
  }
}

let count = 0;
for (const file of walk(src)) {
  if (file.includes(`${path.sep}api${path.sep}`)) continue;
  if (fixFile(file)) count += 1;
}
fixPageEditorImporters();
console.log(`fix-admin-colocated-relative-paths: updated ${count} file(s)${dryRun ? ' (dry-run)' : ''}`);
