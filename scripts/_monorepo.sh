#!/usr/bin/env bash
# Shared paths for many_faces_main orchestration (lint-all, ci-local chmod, etc.).
# shellcheck shell=bash
# Sourced by other scripts; do not execute standalone.

# Order matches scripts/lint-all.sh (infra + workers, then apps).
MONOREPO_LINT_SPECS=$'many_faces_database|many_faces_database (compose + seeds)\nmany_faces_redis|many_faces_redis (compose + scripts)\nmany_faces_logger|many_faces_logger (compose + scripts)\nmany_faces_elastic|many_faces_elastic (go vet)\nmany_faces_push|many_faces_push (go vet)\nmany_faces_mailer|many_faces_mailer (gradle compile)\nmany_faces_portal|many_faces_portal (frontend)\nmany_faces_admin|many_faces_admin (admin)\nmany_faces_mobile|many_faces_mobile (Expo)\nmany_faces_backend|many_faces_backend (backend)\nmany_faces_ai|many_faces_ai (AI service)'

monorepo_chmod_submodule_scripts() {
  local d
  while IFS='|' read -r d _; do
    [[ -n "$d" ]] || continue
    if [[ -d "$d/scripts" ]]; then
      find "$d/scripts" -maxdepth 1 -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    fi
  done <<<"$MONOREPO_LINT_SPECS"
}
