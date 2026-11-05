#!/usr/bin/env bash
# docker_services/news-cimd-host/make-certs.sh
# create a local CA and a TLS certificate for the `news-cimd-host` container,
# using OpenSSL inside a throwaway Alpine container (nothing installed on the host).
#
# Result:
#   certs/ca.crt         public CA certificate   -> stays on disk; Keycloak will trust it (step 3c)
#   certs/news-cimd-host.crt  public server cert      -> stays on disk; nginx serves it (step 3b)
#   CA private key and server private key        -> written to Vault (secret/CREDENTIALS), then deleted from disk
#
# Requires: docker, the vault CLI, VAULT_ADDR and VAULT_TOKEN set, KV v2 at secret/ (uses `kv patch`).
# Refuses to run if certs/ already holds a CA, so an existing CA is never overwritten by accident.

set -euo pipefail

: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"
VAULT_PATH="${VAULT_PATH:-secret/CREDENTIALS}"

cd "$(dirname "$0")"
mkdir -p certs
if [ -e certs/ca.crt ]; then
  echo "certs/ca.crt already exists; remove certs/ first if you really want a new CA" >&2
  exit 1
fi

# 1) Generate inside a throwaway container. It runs as root (apk needs it), so the files are handed back
#    to the calling host user at the end.
docker run --rm \
  -v "$PWD/certs:/certs" -w /certs \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  alpine:3.24.2 sh -euc '
    apk add --no-cache openssl >/dev/null
    # CA: self-signed, marked as a CA, may sign certificates only.
    openssl req -x509 -newkey rsa:3072 -sha256 -days 825 -nodes \
      -keyout ca.key -out ca.crt -subj "/CN=docker_services local CA" \
      -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
    # Server certificate for the network name news-cimd-host (the SAN is what TLS clients check, not the CN).
    openssl req -newkey rsa:2048 -nodes -keyout news-cimd-host.key -out news-cimd-host.csr -subj "/CN=news-cimd-host" 2>/dev/null
    printf "subjectAltName=DNS:news-cimd-host\nextendedKeyUsage=serverAuth\nbasicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\n" > news-cimd-host.ext
    openssl x509 -req -in news-cimd-host.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
      -out news-cimd-host.crt -days 397 -sha256 -extfile news-cimd-host.ext 2>/dev/null
    openssl verify -CAfile ca.crt news-cimd-host.crt
    chown "$HOST_UID:$HOST_GID" /certs/*
  '

# 2) Move both private keys into the shared Vault entry. `@file` makes the CLI read the value from the file,
#    so the key never appears on the command line; `patch` keeps every other key in the entry.
vault kv patch "$VAULT_PATH" LOCAL_NEWS_MCP_CIMD_CA_KEY=@certs/ca.key NEWS_MCP_CIMD_HOST_TLS_KEY=@certs/news-cimd-host.key >/dev/null

# 3) Delete the private keys and the working files; only the two public certificates stay on disk.
rm -f certs/ca.key certs/news-cimd-host.key certs/news-cimd-host.csr certs/news-cimd-host.ext certs/ca.srl

echo "Done. On disk:"
ls -l certs