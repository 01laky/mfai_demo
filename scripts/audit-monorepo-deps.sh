#!/usr/bin/env bash
#
# audit-monorepo-deps.sh — aggregate **security / vulnerability signals** across first-party manifests.
#
# What it does:
#   - many_faces_backend: `dotnet list package --vulnerable` (NuGet advisory data; may print nothing when clean).
#   - many_faces_portal / many_faces_admin: `yarn npm audit` (Yarn Berry/npm audit format; includes transitive findings).
#   - many_faces_mobile: `yarn npm audit` (Yarn Berry; informational).
#
# Why `|| true` per sub-command: CI calls this script in informational mode first; individual tools can
# exit non-zero when advisories exist, but we still want the full matrix printed (security-hardening §11).
#
# Hardening note: this complements `docs/prompts/monorepo-dependency-audit-and-upgrade-agent-prompt.md`
# (version freshness) — keep both: one for semver drift, one for CVE-style signals.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== many_faces_backend: dotnet list package --vulnerable ==="
(cd many_faces_backend && dotnet list package --vulnerable) || true

echo ""
echo "=== many_faces_portal: yarn npm audit ==="
(cd many_faces_portal && yarn npm audit) || true

echo ""
echo "=== many_faces_admin: yarn npm audit ==="
(cd many_faces_admin && yarn npm audit) || true

echo ""
echo "=== many_faces_mobile: yarn npm audit ==="
(cd many_faces_mobile && yarn npm audit) || true

echo ""
echo "Done. Use exit codes from individual tools in CI if you want a hard gate."
