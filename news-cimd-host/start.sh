#!/usr/bin/env bash
# docker_services/news-cimd-host/start.sh
# run a docker compose command for news-cimd-host with its TLS private key
# read from Vault for that one command.
#
# Usage:  news-cimd-host/start.sh            # same as: up -d
#         news-cimd-host/start.sh up -d --force-recreate
#         news-cimd-host/start.sh ps | down | logs -f
#
# Requires: the vault CLI, VAULT_ADDR and VAULT_TOKEN set, and NEWS_MCP_CIMD_HOST_TLS_KEY in ${VAULT_PATH:-secret/CREDENTIALS}.

set -euo pipefail

: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"
VAULT_PATH="${VAULT_PATH:-secret/CREDENTIALS}"

NEWS_MCP_CIMD_HOST_TLS_KEY="$(vault kv get -field=NEWS_MCP_CIMD_HOST_TLS_KEY "$VAULT_PATH")"
export NEWS_MCP_CIMD_HOST_TLS_KEY

if [ "$#" -eq 0 ]; then
  set -- up -d
fi

cd "$(dirname "$0")"
docker compose -f docker-compose.yml "$@"