#!/usr/bin/env bash
# Pin the same many_faces_proto commit in every consumer nested submodule.
#
# Usage (from many_faces_main root):
#   ./scripts/bump-nested-many-faces-proto.sh              # use backend/many_faces_proto HEAD
#   ./scripts/bump-nested-many-faces-proto.sh <commit-ish>  # checkout ref in anchor, then pin all
#
# Does not commit or push — run commits per consumer repo after reviewing git status.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANCHOR="${ROOT}/many_faces_backend/many_faces_proto"
REF="${1:-}"

CONSUMERS=(
  many_faces_backend
  many_faces_push
  many_faces_mailer
  many_faces_elastic
  many_faces_ai
)

if [[ ! -d "${ANCHOR}/.git" ]]; then
  echo "Anchor missing: ${ANCHOR} (init submodules: git submodule update --init --recursive)" >&2
  exit 1
fi

if [[ -n "${REF}" ]]; then
  git -C "${ANCHOR}" fetch origin
  git -C "${ANCHOR}" checkout "${REF}"
fi

SHA="$(git -C "${ANCHOR}" rev-parse HEAD)"
echo "Pinning nested many_faces_proto → ${SHA}"

for consumer in "${CONSUMERS[@]}"; do
  NESTED="${ROOT}/${consumer}/many_faces_proto"
  if [[ ! -d "${NESTED}/.git" ]]; then
    echo "  skip ${consumer} (no nested many_faces_proto)"
    continue
  fi
  git -C "${NESTED}" fetch origin
  git -C "${NESTED}" checkout "${SHA}"
  git -C "${ROOT}/${consumer}" add many_faces_proto
  echo "  staged ${consumer}/many_faces_proto"
done

echo ""
echo "Next: in each consumer with staged changes, commit, push, then bump pointers in many_faces_main."
