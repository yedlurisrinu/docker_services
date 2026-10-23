#!/usr/bin/env bash
# docker_services/cimd-host/start.sh
# Thread 04-B · Topic 4A · C0 step 3b — run a docker compose command for cimd-host with its TLS private key
# read from Vault for that one command.
#
# Usage:  cimd-host/start.sh            # same as: up -d
#         cimd-host/start.sh up -d --force-recreate
#         cimd-host/start.sh ps | down | logs -f
#
# Requires: the vault CLI, VAULT_ADDR and VAULT_TOKEN set, and MCP_LAB_CIMD_HOST_TLS_KEY in ${VAULT_PATH:-secret/CREDENTIALS}.

set -euo pipefail

: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"
VAULT_PATH="${VAULT_PATH:-secret/CREDENTIALS}"

MCP_LAB_CIMD_HOST_TLS_KEY="$(vault kv get -field=MCP_LAB_CIMD_HOST_TLS_KEY "$VAULT_PATH")"
export MCP_LAB_CIMD_HOST_TLS_KEY

if [ "$#" -eq 0 ]; then
  set -- up -d
fi

cd "$(dirname "$0")"
docker compose -f docker-compose.yml "$@"