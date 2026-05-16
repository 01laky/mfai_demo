#!/usr/bin/env node
/**
 * CI helper: run backend static-localization regression tests (parity, unflattener, golden, ambiguous keys).
 * Usage from monorepo root: node scripts/verify-localization-key-parity.mjs
 *
 * Covers:
 * - en/sk/cs key parity per app (LocalizationKeyParityTests)
 * - ResourceJsonUnflattener nesting edge cases
 * - Portal auth-flow golden subtree (LocalizationPortalGoldenTests)
 * - Forbidden .resx prefix conflicts e.g. pages.login vs pages.login.title (ResxLocalizationKeyAmbiguityTests)
 */
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const backend = path.join(root, 'many_faces_backend');
const filter =
  'FullyQualifiedName~LocalizationKeyParity|FullyQualifiedName~LocalizationResourceValue|FullyQualifiedName~ResourceJsonUnflattener|FullyQualifiedName~LocalizationPortalGolden|FullyQualifiedName~ResxLocalizationKeyAmbiguity';

const result = spawnSync(
  'dotnet',
  ['test', 'BeDemo.Api.Tests/BeDemo.Api.Tests.csproj', '--filter', filter, '--verbosity', 'minimal'],
  { cwd: backend, stdio: 'inherit' },
);

process.exit(result.status ?? 1);
