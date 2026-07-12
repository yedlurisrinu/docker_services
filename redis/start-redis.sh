#!/bin/bash
# start-redis.sh
set -e

echo "──────────────────────────────────────"
echo "  Redis Vault Secret Loader"
echo "──────────────────────────────────────"

# ── Debug ──────────────────────────────────────────────
echo "ENV CHECK:"
echo "  VAULT_ADDR         = ${VAULT_ADDR}"
echo "  VAULT_TOKEN set    = $([ -n "$VAULT_TOKEN" ] && echo YES || echo NO)"
echo "  VAULT_SECRET_PATH  = ${VAULT_SECRET_PATH}"

# ── Validate ───────────────────────────────────────────
[ -z "$VAULT_ADDR" ]        && echo "❌ VAULT_ADDR not set"        && exit 1
[ -z "$VAULT_TOKEN" ]       && echo "❌ VAULT_TOKEN not set"       && exit 1
[ -z "$VAULT_SECRET_PATH" ] && echo "❌ VAULT_SECRET_PATH not set" && exit 1

# ── Wait for Vault ─────────────────────────────────────
echo "Connecting to Vault at: $VAULT_ADDR"

MAX_RETRIES=30
RETRY_COUNT=0

until curl -sf \
  --max-time 5 \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; do

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Vault not reachable after $MAX_RETRIES attempts"
    curl -v "$VAULT_ADDR/v1/sys/health" 2>&1 || true
    exit 1
  fi
  echo "Vault not ready ($RETRY_COUNT/$MAX_RETRIES) — retrying in 3s..."
  sleep 3
done

echo "✅ Vault is ready"

# ── Fetch secrets ──────────────────────────────────────
echo "Fetching secrets from: $VAULT_SECRET_PATH"

RESPONSE=$(curl -sf \
  --max-time 10 \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$VAULT_SECRET_PATH")

if [ -z "$RESPONSE" ]; then
  echo "❌ Failed to fetch secrets from Vault"
  exit 1
fi

echo "✅ Secrets fetched from Vault"

# ── Parse secret using perl ────────────────────────────
REDIS_PASSWORD=$(echo "$RESPONSE" | \
  perl -MJSON -e '
    local $/;
    my $json = <STDIN>;
    my $data = JSON::decode_json($json);
    my $secrets = exists $data->{data}{data}
      ? $data->{data}{data}   # KV v2
      : $data->{data};        # KV v1
    print $secrets->{REDIS_PASSWORD};
  ')

export REDIS_PASSWORD

# ── Validate ───────────────────────────────────────────
if [ -z "$REDIS_PASSWORD" ]; then
  echo "❌ REDIS_PASSWORD is empty"
  echo "   Raw response: $RESPONSE"
  exit 1
fi

echo "✅ REDIS_PASSWORD loaded successfully"

# ── Start Redis ────────────────────────────────────────
echo "Starting Redis..."
exec redis-server --requirepass "$REDIS_PASSWORD"