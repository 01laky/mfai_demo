#!/usr/bin/env node
/**
 * Colocate many_faces_portal components by phase. Run from monorepo root.
 * Usage: node scripts/migrate-portal-colocate-phase.mjs <radix|root|grid|settings|pages>
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const portal = path.join(root, 'many_faces_portal');
const src = path.join(portal, 'src');
const components = path.join(src, 'components');
const gridDir = path.join(components, 'grid');

const phase = process.argv[2];
if (!phase) {
  console.error('Usage: node scripts/migrate-portal-colocate-phase.mjs <radix|root|grid|settings|pages>');
  process.exit(1);
}

const ROOT_NAMES = [
  'BlockListTab', 'ComponentBlock', 'ComponentListView', 'EditProfileTab', 'FacePageView',
  'FaceRoleSelectPanel', 'FollowTab', 'Footer', 'FriendRequestsTab', 'GridTopPanelContent',
  'GuestRoute', 'Header', 'LanguageRouter', 'LanguageSwitcher', 'MainLogo', 'MessengerTab',
  'NotificationsTab', 'PageGridLayout', 'ProtectedRoute', 'StoriesCreateTopPanel', 'UserCard',
  'UserGrid', 'UserList', 'WallTicketCreateTopPanel', 'WallTicketDetailPanel', 'WallTicketsSection',
  'gridTopPanelCreateMeta',
];

function runGitMv(fromRelPortal, toRelPortal) {
  const from = path.join(portal, fromRelPortal);
  const to = path.join(portal, toRelPortal);
  if (!fs.existsSync(from)) return false;
  fs.mkdirSync(path.dirname(to), { recursive: true });
  const r = spawnSync('git', ['mv', fromRelPortal, toRelPortal], { cwd: portal, stdio: 'inherit' });
  if (r.status !== 0) {
    fs.renameSync(from, to);
  }
  return true;
}

function listFlatTsx(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.endsWith('.tsx'))
    .map((e) => e.name.replace(/\.tsx$/, ''));
}

function listFlatTs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.endsWith('.ts') && e.name !== 'index.ts')
    .map((e) => e.name.replace(/\.ts$/, ''));
}

function detectExports(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const hasDefault = /export\s+default\s+/.test(text);
  const names = [...text.matchAll(/export\s+(?:const|function|class)\s+(\w+)/g)].map((m) => m[1]);
  return { hasDefault, names: [...new Set(names)] };
}

function writeIndex(dir, name, mainFile) {
  const { hasDefault, names } = detectExports(mainFile);
  const lines = [];
  if (hasDefault) lines.push(`export { default } from './${name}';`);
  for (const n of names) lines.push(`export { ${n} } from './${name}';`);
  if (lines.length === 0) lines.push(`export * from './${name}';`);
  fs.writeFileSync(path.join(dir, 'index.ts'), `${lines.join('\n')}\n`);
  const relIndex = path.relative(portal, path.join(dir, 'index.ts'));
  spawnSync('git', ['add', relIndex], { cwd: portal, stdio: 'inherit' });
}

function walkFiles(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walkFiles(p, acc);
    else if (/\.(tsx|ts)$/.test(ent.name)) acc.push(p);
  }
  return acc;
}

function deepenParentImports(content) {
  return content.replace(/from (['"])((?:\.\.\/)+)/g, (_m, q, parents) => `from ${q}../${parents}`);
}

function fixSiblingImports(content, names) {
  let c = content;
  for (const n of names) {
    const re = new RegExp(`from (['"])\\./${n}\\1`, 'g');
    c = c.replace(re, `from $1../${n}$1`);
  }
  return c;
}

function fixGridPathImports(content) {
  return content.replace(/from (['"])\.\/grid\/([^'"]+)\1/g, `from $1../grid/$2$1`);
}

function processTree(treeDir, siblingNames, options = {}) {
  const { fixGrid = false } = options;
  for (const file of walkFiles(treeDir)) {
    if (file.endsWith(`${path.sep}index.ts`)) continue;
    let content = fs.readFileSync(file, 'utf8');
    content = deepenParentImports(content);
    content = fixBareImports(content);
    if (file.endsWith('.scss')) content = fixScssImports(content);
    content = fixSiblingImports(content, siblingNames);
    if (fixGrid) content = fixGridPathImports(content);
    fs.writeFileSync(file, content);
  }
}

function fixBareImports(content) {
  return content.replace(/\bimport (['"])\.\.\/(?!\.)/g, 'import $1../../');
}

function fixScssImports(content) {
  return content.replace(/@import (['"])\.\.\/(?!\.)/g, '@import $1../../');
}

function colocateName(baseDir, name) {
  const relBase = path.relative(portal, baseDir);
  const tsx = path.join(baseDir, `${name}.tsx`);
  const ts = path.join(baseDir, `${name}.ts`);
  const mainPath = fs.existsSync(tsx) ? tsx : fs.existsSync(ts) ? ts : null;
  if (!mainPath) return;
  const ext = path.extname(mainPath);
  const destDir = path.join(baseDir, name);
  if (fs.existsSync(destDir)) return;
  const destMain = path.join(destDir, `${name}${ext}`);
  runGitMv(path.join(relBase, `${name}${ext}`), path.join(relBase, name, `${name}${ext}`));
  const scss = path.join(baseDir, `${name}.scss`);
  if (fs.existsSync(scss)) {
    runGitMv(path.join(relBase, `${name}.scss`), path.join(relBase, name, `${name}.scss`));
  }
  if (ext === '.tsx' || ext === '.ts') writeIndex(destDir, name, destMain);
  console.log(`  ${path.relative(portal, destDir)}`);
}

function colocateAll(baseDir, names) {
  for (const name of names) colocateName(baseDir, name);
}

const gridNames = () => {
  const tsx = listFlatTsx(gridDir);
  const ts = listFlatTs(gridDir);
  return [...new Set([...tsx, ...ts])];
};

console.log(`migrate-portal-colocate-phase: ${phase}`);

switch (phase) {
  case 'radix': {
    const names = ['Button', 'Input', 'FormField'];
    colocateAll(path.join(components, 'radix'), names);
    processTree(path.join(components, 'radix'), names);
    break;
  }
  case 'root': {
    colocateAll(components, ROOT_NAMES);
    for (const name of ROOT_NAMES) {
      const dir = path.join(components, name);
      if (fs.existsSync(dir)) processTree(dir, ROOT_NAMES, { fixGrid: true });
    }
    break;
  }
  case 'grid': {
    const names = gridNames();
    colocateAll(gridDir, names);
    for (const name of names) {
      const dir = path.join(gridDir, name);
      if (fs.existsSync(dir)) processTree(dir, names);
    }
  // Fix remaining imports from root components into grid/*
    for (const file of walkFiles(components)) {
      if (!file.includes(`${path.sep}grid${path.sep}`)) continue;
      let c = fs.readFileSync(file, 'utf8');
      c = fixSiblingImports(c, ROOT_NAMES);
      fs.writeFileSync(file, c);
    }
    break;
  }
  case 'settings': {
    const settings = path.join(src, 'features', 'settings');
    const names = listFlatTsx(settings);
    colocateAll(settings, names);
    for (const name of names) {
      const dir = path.join(settings, name);
      if (fs.existsSync(dir)) processTree(dir, names);
    }
    break;
  }
  case 'pages': {
    const pages = path.join(src, 'pages');
    const names = listFlatTsx(pages);
    colocateAll(pages, names);
    for (const name of names) {
      const dir = path.join(pages, name);
      if (fs.existsSync(dir)) processTree(dir, names);
    }
    break;
  }
  default:
    console.error(`unknown phase: ${phase}`);
    process.exit(1);
}

console.log('done');
