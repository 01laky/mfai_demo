#!/usr/bin/env bash
# Generate localhost TLS material for API (Kestrel .pfx) + Vite (PEM).
# Prefer mkcert (trusted in browsers after `mkcert -install`); else OpenSSL self-signed.
#
# Physical device (Expo) on the same LAN / iPhone hotspot: the phone calls https://<Mac-IP>:8001.
# Include that IPv4 in the cert SAN, then restart be-demo-dev so Kestrel loads the new PFX:
#   HTTPS_DEV_INCLUDE_LAN_IP=1 ./dev/generate-https-certs.sh
# or set an explicit address:
#   HTTPS_DEV_LAN_IP=172.20.10.2 ./dev/generate-https-certs.sh
# More names (comma-separated, bare hostnames or dotted IPv4s):
#   HTTPS_DEV_EXTRA_SANS=172.20.10.2,myhost.local ./dev/generate-https-certs.sh
#
# Force re-create when certs already exist: HTTPS_DEV_REGENERATE=1
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$ROOT/dev/certs"
mkdir -p "$CERT_DIR"
KEY="$CERT_DIR/localhost-key.pem"
CRT="$CERT_DIR/localhost.pem"
PFX="$CERT_DIR/localhost.pfx"

# --- Optional SANs for LAN / hotspot (so TLS works when hostname is an IP, not localhost) ---
detect_lan_ipv4() {
  if [[ -n "${HTTPS_DEV_LAN_IP:-}" ]] && [[ "${HTTPS_DEV_LAN_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${HTTPS_DEV_LAN_IP}"
    return 0
  fi
  if [[ "${HTTPS_DEV_INCLUDE_LAN_IP:-}" == "1" ]]; then
    local ip=""
    for _if in en0 en1 en2; do
      ip=$(ipconfig getifaddr "$_if" 2>/dev/null || true)
      if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
      fi
    done
  fi
  return 1
}

EXTRA_MKCERT_NAMES=()
EXTRA_SAN_ENTRIES=("DNS:localhost" "IP:127.0.0.1")

_lan="$(detect_lan_ipv4 || true)"
if [[ -n "$_lan" ]]; then
  EXTRA_MKCERT_NAMES+=("$_lan")
  EXTRA_SAN_ENTRIES+=("IP:$_lan")
  echo "📡 Including LAN IPv4 in SAN: $_lan"
fi

if [[ -n "${HTTPS_DEV_EXTRA_SANS:-}" ]]; then
  IFS=',' read -ra _parts <<<"${HTTPS_DEV_EXTRA_SANS}"
  for _p in "${_parts[@]}"; do
    _p="${_p#"${_p%%[![:space:]]*}"}"
    _p="${_p%"${_p##*[![:space:]]}"}"
    [[ -z "$_p" ]] && continue
    if [[ "$_p" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      EXTRA_MKCERT_NAMES+=("$_p")
      EXTRA_SAN_ENTRIES+=("IP:$_p")
      echo "📡 Including extra SAN IP: $_p"
    else
      EXTRA_MKCERT_NAMES+=("$_p")
      EXTRA_SAN_ENTRIES+=("DNS:$_p")
      echo "📡 Including extra SAN DNS: $_p"
    fi
  done
fi

SAN_CSV=$(IFS=,; echo "${EXTRA_SAN_ENTRIES[*]}")

if [[ "${HTTPS_DEV_REGENERATE:-}" == "1" ]]; then
  rm -f "$KEY" "$CRT" "$PFX"
  echo "♻️  HTTPS_DEV_REGENERATE=1 — removed existing cert material in $CERT_DIR"
fi

if command -v mkcert >/dev/null 2>&1; then
  echo "🔐 Using mkcert (trusted locally after: mkcert -install)"
  MKCERT_HOSTS=(localhost 127.0.0.1 ::1)
  if ((${#EXTRA_MKCERT_NAMES[@]} > 0)); then
    MKCERT_HOSTS+=("${EXTRA_MKCERT_NAMES[@]}")
  fi
  mkcert -key-file "$KEY" -cert-file "$CRT" "${MKCERT_HOSTS[@]}"
  openssl pkcs12 -export -out "$PFX" -inkey "$KEY" -in "$CRT" -passout pass: -name localhost
  echo "✅ Wrote $KEY, $CRT, $PFX (SAN: $SAN_CSV)"
  echo "💡 Docker (monorepo root): docker compose -f docker-compose.dev.yml restart be-demo-dev fe-demo-dev fe-demo-proxy admin-demo-dev"
  exit 0
fi

echo "⚠️  mkcert not found; using OpenSSL self-signed (browser will warn until you trust the cert)."
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -keyout "$KEY" -out "$CRT" -days 825 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=$SAN_CSV"
openssl pkcs12 -export -out "$PFX" -inkey "$KEY" -in "$CRT" -passout pass: -name localhost
echo "✅ Wrote $KEY, $CRT, $PFX (SAN: $SAN_CSV)"
echo "💡 Docker (monorepo root): docker compose -f docker-compose.dev.yml restart be-demo-dev fe-demo-dev fe-demo-proxy admin-demo-dev"
echo "💡 Install mkcert for warning-free HTTPS: brew install mkcert && mkcert -install"
