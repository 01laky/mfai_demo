#!/usr/bin/env bash
# Smoke test: static i18n bundles must be reachable without a face prefix.
# Usage: ./scripts/smoke-localization-api.sh [base_url]
# Default base_url: http://localhost:8000

set -euo pipefail

BASE="${1:-http://localhost:8000}"
BASE="${BASE%/}"

fail() {
  echo "smoke-localization-api: $*" >&2
  exit 1
}

for app in portal admin mobile; do
  url="${BASE}/api/localization/${app}"
  code=$(curl -s -o /tmp/mf-loc-"${app}".json -w "%{http_code}" "$url" || echo "000")
  if [ "$code" != "200" ]; then
    fail "${url} returned HTTP ${code} (expected 200; restart be-demo-dev if 400 face-prefix)"
  fi
  if ! grep -q '"version"' /tmp/mf-loc-"${app}".json 2>/dev/null; then
    fail "${url} body missing version field"
  fi
done

echo "smoke-localization-api: OK (${BASE}/api/localization/{portal,admin,mobile})"
