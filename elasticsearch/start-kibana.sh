#!/bin/bash
set -e

echo "──────────────────────────────────────"
echo "  Kibana Vault Secret Loader"
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

KIBANA_ENCRYPTION_KEY=$(echo "$RESPONSE" | \
  grep -o '"KIBANA_ENCRYPTION_KEY":"[^"]*"' | \
  sed 's/"KIBANA_ENCRYPTION_KEY":"//;s/"//')

ELASTIC_PASSWORD=$(echo "$RESPONSE" | \
  grep -o '"ELASTIC_PASSWORD":"[^"]*"' | \
  sed 's/"ELASTIC_PASSWORD":"//;s/"//')

# ELASTIC_PASSWORD reused for kibana_system as confirmed
export ELASTICSEARCH_USERNAME=kibana_system
export ELASTICSEARCH_PASSWORD="$ELASTIC_PASSWORD"
export XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY="$KIBANA_ENCRYPTION_KEY"

[ -z "$ELASTIC_PASSWORD" ] && echo "❌ ELASTIC_PASSWORD is empty" && exit 1
[ -z "$KIBANA_ENCRYPTION_KEY" ]  && echo "❌ KIBANA_ENCRYPTION_KEY is empty"  && exit 1

echo "✅ Kibana secrets loaded successfully"
echo "✅ KIBANA_ENCRYPTION_KEY loaded successfully"

# ── Start Kibana ───────────────────────────────────────
echo "Starting Kibana..."
exec /usr/local/bin/kibana-docker