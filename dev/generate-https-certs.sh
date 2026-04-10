#!/usr/bin/env bash
# Generate localhost TLS material for API (Kestrel .pfx) + Vite (PEM).
# Prefer mkcert (trusted in browsers after `mkcert -install`); else OpenSSL self-signed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$ROOT/dev/certs"
mkdir -p "$CERT_DIR"
KEY="$CERT_DIR/localhost-key.pem"
CRT="$CERT_DIR/localhost.pem"
PFX="$CERT_DIR/localhost.pfx"

if command -v mkcert >/dev/null 2>&1; then
  echo "🔐 Using mkcert (trusted locally after: mkcert -install)"
  mkcert -key-file "$KEY" -cert-file "$CRT" localhost 127.0.0.1 ::1
  openssl pkcs12 -export -out "$PFX" -inkey "$KEY" -in "$CRT" -passout pass: -name localhost
  echo "✅ Wrote $KEY, $CRT, $PFX"
  exit 0
fi

echo "⚠️  mkcert not found; using OpenSSL self-signed (browser will warn until you trust the cert)."
if [ ! -f "$KEY" ] || [ ! -f "$CRT" ]; then
  openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
    -keyout "$KEY" -out "$CRT" -days 825 \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi
openssl pkcs12 -export -out "$PFX" -inkey "$KEY" -in "$CRT" -passout pass: -name localhost
echo "✅ Wrote $KEY, $CRT, $PFX"
echo "💡 Install mkcert for warning-free HTTPS: brew install mkcert && mkcert -install"
