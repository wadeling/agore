#!/usr/bin/env bash
# Self-signed cert for the local nginx terminator, same idea as CSPM's cspm-tls.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/server/nginx/certs"
crt="$dir/agore-tls.crt"
key="$dir/agore-tls.key"

mkdir -p "$dir"
if [[ -f "$crt" && -f "$key" ]]; then
    echo "TLS cert already exists: $crt"
    exit 0
fi

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$key" \
    -out "$crt" \
    -days 825 \
    -subj "/CN=agore.bytebar.dev" \
    -addext "subjectAltName=DNS:agore.bytebar.dev,DNS:localhost,IP:127.0.0.1"

chmod 600 "$key"
echo "wrote $crt"
