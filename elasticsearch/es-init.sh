#!/bin/sh
# es-init.sh — one-shot: sets the kibana_system user's password in Elasticsearch.
# Runs in curlimages/curl (busybox sh + curl). Reads secrets from Vault at runtime, so nothing is
# interpolated by Compose from the host shell. Secret values are never printed.
set -e

echo "──────────────────────────────────────"
echo "  es-init: kibana_system password"
echo "──────────────────────────────────────"

# ── Vault token: Compose secret file, fallback to env ──
if [ -s /run/secrets/vault_token ]; then
  VAULT_TOKEN="$(cat /run/secrets/vault_token)"
fi

[ -z "$VAULT_ADDR" ]        && echo "❌ VAULT_ADDR not set"        && exit 1
[ -z "$VAULT_TOKEN" ]       && echo "❌ VAULT_TOKEN not set"       && exit 1
[ -z "$VAULT_SECRET_PATH" ] && echo "❌ VAULT_SECRET_PATH not set" && exit 1

ES_URL="${ES_URL:-http://elasticsearch:9200}"

# ── Wait for Vault ─────────────────────────────────────
MAX_RETRIES=30
RETRY_COUNT=0

until curl -sf \
  --max-time 5 \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  [ $RETRY_COUNT -ge $MAX_RETRIES ] && echo "❌ Vault not reachable" && exit 1
  echo "Vault not ready ($RETRY_COUNT/$MAX_RETRIES) — retrying in 3s..."
  sleep 3
done

echo "✅ Vault is ready"

# ── Fetch secrets ──────────────────────────────────────
RESPONSE=$(curl -sf \
  --max-time 10 \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$VAULT_SECRET_PATH")

[ -z "$RESPONSE" ] && echo "❌ Failed to fetch secrets from Vault" && exit 1

ELASTIC_PASSWORD=$(echo "$RESPONSE" | \
  grep -o '"ELASTIC_PASSWORD":"[^"]*"' | \
  sed 's/"ELASTIC_PASSWORD":"//;s/"//')

KIBANA_SYSTEM_PASSWORD=$(echo "$RESPONSE" | \
  grep -o '"KIBANA_SYSTEM_PASSWORD":"[^"]*"' | \
  sed 's/"KIBANA_SYSTEM_PASSWORD":"//;s/"//')

[ -z "$ELASTIC_PASSWORD" ]       && echo "❌ ELASTIC_PASSWORD is empty"       && exit 1
[ -z "$KIBANA_SYSTEM_PASSWORD" ] && echo "❌ KIBANA_SYSTEM_PASSWORD is empty (add it at $VAULT_SECRET_PATH)" && exit 1

echo "✅ Secrets loaded successfully"

# ── Set kibana_system password ─────────────────────────
# Credentials and body go to curl as a config on stdin (-K -), so they never appear in the process list.
# The ES healthcheck only proves HTTP is up, so retry while the security index is still initialising.
echo "Setting kibana_system password..."
RETRY_COUNT=0
until
  HTTP_CODE=$(printf 'user = "elastic:%s"\ndata-binary = "{\\"password\\":\\"%s\\"}"\n' \
      "$ELASTIC_PASSWORD" "$KIBANA_SYSTEM_PASSWORD" | \
    curl -s -K - \
      -o /dev/null -w "%{http_code}" \
      --max-time 10 \
      -X POST "$ES_URL/_security/user/kibana_system/_password" \
      -H "Content-Type: application/json")
  [ "$HTTP_CODE" = "200" ]
do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Failed to set kibana_system password (HTTP $HTTP_CODE)"
    exit 1
  fi
  echo "Elasticsearch not ready (HTTP $HTTP_CODE, $RETRY_COUNT/$MAX_RETRIES) — retrying in 3s..."
  sleep 3
done

echo "✅ kibana_system password set successfully"
