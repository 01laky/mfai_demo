#!/usr/bin/env node
/**
 * CI helper: run backend LocalizationKeyParity + ResourceJsonUnflattener tests.
 * Usage from monorepo root: node scripts/verify-localization-key-parity.mjs
 */
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const backend = path.join(root, 'many_faces_backend');
const filter =
  'FullyQualifiedName~LocalizationKeyParity|FullyQualifiedName~ResourceJsonUnflattener';

const result = spawnSync(
  'dotnet',
  ['test', 'BeDemo.Api.Tests/BeDemo.Api.Tests.csproj', '--filter', filter, '--verbosity', 'minimal'],
  { cwd: backend, stdio: 'inherit' },
);

process.exit(result.status ?? 1);
