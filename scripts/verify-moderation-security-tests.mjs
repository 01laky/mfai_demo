#!/usr/bin/env node
/**
 * CI helper (SHV2 PI-10): run required backend moderation security regression tests.
 *
 * Usage from monorepo root:
 *   node scripts/verify-moderation-security-tests.mjs
 *
 * Filter must stay aligned with:
 *   many_faces_backend/BeDemo.Api/Services/ContentModerationCiGate.cs
 *   (ContentModerationCiGate.XunitFilterExpression → Category=ModerationSecurity)
 *
 * Covered fixtures:
 * - ContentModerationSecurityEdgeTests (red-team corpus + policy)
 * - ContentModerationUnicodeSpoofingTests (PI-6 bidi/homoglyph)
 * - ContentModerationTrustBoundaryTests (PI-9 untrusted vs operator AI)
 * - ContentModerationPayloadLogRedactionTests (PI-7 invalid Redis payload logs)
 * - ContentModerationCiGateTests (trait/filter alignment)
 */
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const backend = path.join(root, 'many_faces_backend');

/** Keep in sync with ContentModerationCiGate.XunitFilterExpression */
const filter = 'Category=ModerationSecurity';

const inCi = process.env.CI === 'true' || process.env.GITHUB_ACTIONS === 'true';
const configArgs = inCi ? ['--no-build', '-c', 'Release'] : [];

const result = spawnSync(
  'dotnet',
  [
    'test',
    'BeDemo.Api.Tests/BeDemo.Api.Tests.csproj',
    '--filter',
    filter,
    '--verbosity',
    'minimal',
    ...configArgs,
  ],
  { cwd: backend, stdio: 'inherit' },
);

process.exit(result.status ?? 1);
