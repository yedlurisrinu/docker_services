#!/bin/bash
# start-mongodb.sh
set -e

echo "──────────────────────────────────────"
echo "  MongoDB Vault Secret Loader      "
echo "──────────────────────────────────────"

# ── Debug ──────────────────────────────────────────────
echo "ENV CHECK:"
echo "  VAULT_ADDR         = ${VAULT_ADDR}"
echo "  VAULT_TOKEN set    = $([ -n "$VAULT_TOKEN" ] && echo YES || echo NO)"
echo "  VAULT_SECRET_PATH  = ${VAULT_SECRET_PATH}"

# ── Validate ───────────────────────────────────────────
if [ -z "$VAULT_ADDR" ]; then
  echo "❌ VAULT_ADDR not set"; exit 1
fi
if [ -z "$VAULT_TOKEN" ]; then
  echo "❌ VAULT_TOKEN not set"; exit 1
fi
if [ -z "$VAULT_SECRET_PATH" ]; then
  echo "❌ VAULT_SECRET_PATH not set"; exit 1
fi

# ── Wait for Vault using curl ──────────────────────────
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
    echo "   VAULT_ADDR: $VAULT_ADDR"

    # Diagnose
    echo ""
    echo "Network diagnostic:"
    curl -v "$VAULT_ADDR/v1/sys/health" 2>&1 || true
    exit 1
  fi

  echo "Vault not ready ($RETRY_COUNT/$MAX_RETRIES) — retrying in 3s..."
  sleep 3
done

echo "✅ Vault is ready"

# ── Fetch secrets using curl ───────────────────────────
echo "Fetching secrets from: $VAULT_SECRET_PATH"

RESPONSE=$(curl -sf \
  --max-time 10 \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/$VAULT_SECRET_PATH")

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  echo "❌ Failed to fetch secrets from Vault"
  exit 1
fi

echo "✅ Secrets fetched from Vault"

# ── Parse using perl (already installed) ──────────────
MONGO_USER=$(echo "$RESPONSE" | \
  perl -MJSON -e '
    local $/;
    my $data = JSON::decode_json(<STDIN>);
    my $secrets = exists $data->{data}{data}
      ? $data->{data}{data}     # KV v2
      : $data->{data};          # KV v1
    print $secrets->{MONGO_USER};
  ')

MONGO_PASSWORD=$(echo "$RESPONSE" | \
  perl -MJSON -e '
    local $/;
    my $data = JSON::decode_json(<STDIN>);
    my $secrets = exists $data->{data}{data}
      ? $data->{data}{data}
      : $data->{data};
    print $secrets->{MONGO_PASSWORD};
  ')

# ── Export with correct MongoDB env var names ──────────
export MONGO_INITDB_ROOT_USERNAME="$MONGO_USER"
export MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASSWORD"

[ -z "$MONGO_INITDB_ROOT_USERNAME" ] && echo "❌ MONGO_USER is empty"     && exit 1
[ -z "$MONGO_INITDB_ROOT_PASSWORD" ] && echo "❌ MONGO_PASSWORD is empty" && exit 1

echo "✅ MongoDB credentials loaded successfully"
echo "   User : $MONGO_USER"

# ── Start Mondbdb ───────────────────────────────────
echo "Starting Mondbdb..."
exec docker-entrypoint.sh mongod