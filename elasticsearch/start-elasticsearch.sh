#!/bin/bash
set -e

echo "──────────────────────────────────────"
echo "  Elasticsearch Vault Secret Loader"
echo "──────────────────────────────────────"

[ -z "$VAULT_ADDR" ]        && echo "❌ VAULT_ADDR not set"        && exit 1
[ -z "$VAULT_TOKEN" ]       && echo "❌ VAULT_TOKEN not set"       && exit 1
[ -z "$VAULT_SECRET_PATH" ] && echo "❌ VAULT_SECRET_PATH not set" && exit 1

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

export ELASTIC_PASSWORD

[ -z "$ELASTIC_PASSWORD" ] && echo "❌ ELASTIC_PASSWORD is empty" && exit 1

echo "✅ ELASTIC_PASSWORD loaded successfully"

# ── Start Elasticsearch ────────────────────────────────
echo "Starting Elasticsearch..."
exec /usr/local/bin/docker-entrypoint.sh eswrapper