#!/usr/bin/env node
/**
 * Bulk colocate many_faces_mobile by phase (structure-only git mv + index.ts).
 * Usage (from monorepo root):
 *   node scripts/migrate-mobile-colocate-phase.mjs theme|shell|wall-tickets|grid|screens|all
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const mobile = path.join(root, 'many_faces_mobile');

const phaseArg = process.argv[2];
const dryRun = process.argv.includes('--dry-run');

const PHASES = {
  theme: {
    base: 'src/theme',
    names: ['AnimatedShellGradient'],
  },
  shell: {
    base: 'src/components',
    names: [
      'AppShell',
      'ShellDrawer',
      'MainLogo',
      'ErrorFallback',
      'MeCapabilitiesBootstrap',
      'PushTokenRegistrationEffect',
      'PushNotificationResponseEffect',
    ],
  },
  'wall-tickets': {
    base: 'src/components/wall-tickets',
    mkdir: true,
    names: ['WallTicketsSection', 'WallTicketsAdGridBlock'],
  },
  grid: {
    base: 'src/grid',
    names: ['MobilePageLayout'],
  },
  screens: {
    base: 'src/screens',
    names: [
      'SplashOrLoadingScreen',
      'ConfigErrorScreen',
      'HomePlaceholderScreen',
      'LoginScreen',
      'RegisterScreen',
      'RegisterCompleteScreen',
      'PlaceholderScreen',
      'FacePageScreen',
      'MySubmissionsScreen',
      'ProfileMeScreen',
      'ChatAiPlaceholderScreen',
      'ChatRoomPlaceholderScreen',
    ],
    tests: [
      ['src/screens/__tests__/LoginScreen.test.tsx', 'src/screens/LoginScreen/LoginScreen.test.tsx'],
      [
        'src/screens/__tests__/RegisterScreen.test.tsx',
        'src/screens/RegisterScreen/RegisterScreen.test.tsx',
      ],
    ],
  },
};

function run(cmd, args, opts = {}) {
  if (dryRun) {
    console.log(`[dry-run] ${cmd} ${args.join(' ')}`);
    return;
  }
  const r = spawnSync(cmd, args, { stdio: 'inherit', cwd: opts.cwd ?? mobile, ...opts });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

function colocate(baseRel, name) {
  const baseDir = path.join(mobile, baseRel);
  const tsx = path.join(baseDir, `${name}.tsx`);
  const destDir = path.join(baseDir, name);
  const destTsx = path.join(destDir, `${name}.tsx`);
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

  console.log(`colocate ${path.relative(mobile, destDir)}`);
  run('mkdir', ['-p', destDir]);
  run('git', ['mv', tsx, destTsx]);
  const indexBody = `export { ${name} } from './${name}';\n`;
  if (dryRun) {
    console.log(indexBody);
  } else {
    fs.writeFileSync(destIndex, indexBody);
    run('git', ['add', destIndex]);
  }
}

function runPhase(phase) {
  const cfg = PHASES[phase];
  if (!cfg) {
    console.error(`Unknown phase: ${phase}`);
    process.exit(1);
  }
  if (cfg.mkdir) {
    const dir = path.join(mobile, cfg.base);
    if (!fs.existsSync(dir)) {
      run('mkdir', ['-p', dir]);
      if (!dryRun) run('git', ['add', dir]);
    }
  }
  for (const name of cfg.names) {
    if (phase === 'wall-tickets') {
      const flat = path.join(mobile, 'src/components', `${name}.tsx`);
      const inNs = path.join(mobile, cfg.base, `${name}.tsx`);
      if (fs.existsSync(flat) && !fs.existsSync(inNs)) {
        run('mkdir', ['-p', path.join(mobile, cfg.base)]);
        run('git', ['mv', flat, inNs]);
      }
    }
    colocate(cfg.base, name);
  }
  if (cfg.tests) {
    for (const [fromRel, toRel] of cfg.tests) {
      const from = path.join(mobile, fromRel);
      const to = path.join(mobile, toRel);
      if (!fs.existsSync(from)) {
        if (fs.existsSync(to)) {
          console.log(`skip test move ${fromRel} (already at destination)`);
          continue;
        }
        console.error(`missing test ${from}`);
        process.exit(1);
      }
      run('mkdir', ['-p', path.dirname(to)]);
      run('git', ['mv', from, to]);
    }
    const testsDir = path.join(mobile, 'src/screens/__tests__');
    if (!dryRun && fs.existsSync(testsDir)) {
      const left = fs.readdirSync(testsDir);
      if (left.length === 0) {
        run('git', ['rm', '-r', testsDir]);
      }
    }
  }
}

const phases =
  phaseArg === 'all' ? ['theme', 'shell', 'wall-tickets', 'grid', 'screens'] : [phaseArg];

if (!phaseArg || phases.some((p) => !PHASES[p])) {
  console.error(
    'Usage: node scripts/migrate-mobile-colocate-phase.mjs <theme|shell|wall-tickets|grid|screens|all> [--dry-run]',
  );
  process.exit(1);
}

for (const p of phases) {
  console.log(`\n=== phase: ${p} ===`);
  runPhase(p);
}

console.log('\nDone. Run: node scripts/verify-mobile-component-colocation.mjs');
