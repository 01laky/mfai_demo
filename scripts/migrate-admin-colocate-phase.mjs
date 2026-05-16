#!/usr/bin/env node
/**
 * Bulk colocate many_faces_admin by phase (structure-only git mv + index.ts).
 * Usage (from monorepo root):
 *   node scripts/migrate-admin-colocate-phase.mjs radix
 *   node scripts/migrate-admin-colocate-phase.mjs root
 *   node scripts/migrate-admin-colocate-phase.mjs page-editor
 *   node scripts/migrate-admin-colocate-phase.mjs dashboard
 *   node scripts/migrate-admin-colocate-phase.mjs routes
 *   node scripts/migrate-admin-colocate-phase.mjs pages
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const admin = path.join(root, 'many_faces_admin');

const phase = process.argv[2];
const dryRun = process.argv.includes('--dry-run');

const PHASES = {
  radix: {
    flag: [],
    names: ['Button', 'Input', 'FormField', 'Table'],
    base: 'src/components/radix',
  },
  root: {
    flag: [],
    names: [
      'AdminLayout',
      'GuestRoute',
      'Header',
      'LanguageRouter',
      'LanguageSwitcher',
      'ProtectedRoute',
      'Sidebar',
    ],
    base: 'src/components',
  },
  tables: {
    flag: ['--tables'],
    names: ['UsersTable', 'FacesTable', 'PagesTable'],
    base: 'src/components/tables',
    mkdir: true,
  },
  'page-editor': {
    flag: ['--page-editor'],
    names: ['GridLayoutEditor', 'ComponentPickerModal', 'GradientPicker'],
    base: 'src/components/page-editor',
    mkdir: true,
  },
  dashboard: {
    flag: ['--dashboard'],
    names: [
      'DashboardCharts',
      'DashboardAiStatsPanel',
      'DashboardMetricsTable',
      'DashboardModerationWidget',
    ],
    base: 'src/components/dashboard',
  },
  routes: {
    flag: [],
    names: ['RouteLoadingFallback'],
    base: 'src/routes',
  },
  pages: {
    flag: [],
    names: [
      'LoginPage',
      'HomePageProtected',
      'DashboardPage',
      'UsersPage',
      'UserDetailPage',
      'CreateUserPage',
      'EditUserPage',
      'FacesPage',
      'FaceDetailPage',
      'CreateFacePage',
      'EditFacePage',
      'FaceWallTicketsPage',
      'CreatePagePage',
      'EditPagePage',
      'PageDetailPage',
      'ContentModerationPage',
      'ChatPage',
      'SettingsPage',
      'RegistrationInvitesPage',
    ],
    base: 'src/pages',
  },
};

if (!phase || !PHASES[phase]) {
  console.error(
    'Usage: node scripts/migrate-admin-colocate-phase.mjs <radix|root|page-editor|tables|dashboard|routes|pages> [--dry-run]',
  );
  process.exit(1);
}

function run(cmd, args, opts = {}) {
  if (dryRun) {
    console.log(`[dry-run] ${cmd} ${args.join(' ')}`);
    return;
  }
  const r = spawnSync(cmd, args, { stdio: 'inherit', cwd: opts.cwd ?? admin, ...opts });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

function colocate(baseRel, name) {
  const baseDir = path.join(admin, baseRel);
  const tsx = path.join(baseDir, `${name}.tsx`);
  const scss = path.join(baseDir, `${name}.scss`);
  const destDir = path.join(baseDir, name);
  const destTsx = path.join(destDir, `${name}.tsx`);
  const destScss = path.join(destDir, `${name}.scss`);
  const destIndex = path.join(destDir, 'index.ts');

  if (!fs.existsSync(tsx)) {
    if (fs.existsSync(destDir)) {
      console.log(`skip ${name} (already colocated)`);
      return;
    }
    console.error(`missing ${tsx}`);
    process.exit(1);
  }
  if (fs.existsSync(destDir)) {
    console.error(`already exists ${destDir}`);
    process.exit(1);
  }

  console.log(`colocate ${path.relative(admin, destDir)}`);
  run('mkdir', ['-p', destDir]);
  run('git', ['mv', tsx, destTsx]);
  if (fs.existsSync(scss)) {
    run('git', ['mv', scss, destScss]);
  }
  const indexBody = `export { ${name} } from './${name}';\n`;
  if (dryRun) {
    console.log(indexBody);
  } else {
    fs.writeFileSync(destIndex, indexBody);
    run('git', ['add', destIndex]);
  }
}

const cfg = PHASES[phase];
if (cfg.mkdir) {
  const pe = path.join(admin, cfg.base);
  if (!fs.existsSync(pe)) {
    run('mkdir', ['-p', pe]);
    if (!dryRun) run('git', ['add', pe]);
  }
}

for (const name of cfg.names) {
  colocate(cfg.base, name);
}

console.log(`\nPhase "${phase}" done. Run: node scripts/fix-admin-colocated-relative-paths.mjs`);
