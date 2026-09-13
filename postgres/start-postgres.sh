#!/bin/bash
# start-postgres.sh
set -e

echo "──────────────────────────────────────"
echo "  PostgreSQL Vault Secret Loader      "
echo "──────────────────────────────────────"

#echo "Installing curl..."
#apt-get update -qq
#apt-get install -y --no-install-recommends curl -qq
#rm -rf /var/lib/apt/lists/*
#echo "✅ curl installed"

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
export POSTGRES_USER=$(echo "$RESPONSE" | \
  perl -MJSON -e '
    local $/;
    my $data = JSON::decode_json(<STDIN>);
    my $secrets = exists $data->{data}{data}
      ? $data->{data}{data}     # KV v2
      : $data->{data};          # KV v1
    print $secrets->{POSTGRES_USER};
  ')

export POSTGRES_PASSWORD=$(echo "$RESPONSE" | \
  perl -MJSON -e '
    local $/;
    my $data = JSON::decode_json(<STDIN>);
    my $secrets = exists $data->{data}{data}
      ? $data->{data}{data}
      : $data->{data};
    print $secrets->{POSTGRES_PASSWORD};
  ')

export POSTGRES_DB=$(echo "$RESPONSE" | \
  perl -MJSON -e '
    local $/;
    my $data = JSON::decode_json(<STDIN>);
    my $secrets = exists $data->{data}{data}
      ? $data->{data}{data}
      : $data->{data};
    print $secrets->{POSTGRES_DB};
  ')


#export POSTGRES_USER=$(parse_secret "POSTGRES_USER")
#export POSTGRES_PASSWORD=$(parse_secret "POSTGRES_PASSWORD")
#export POSTGRES_DB=$(parse_secret "POSTGRES_DB")

# ── Validate ───────────────────────────────────────────
if [ -z "$POSTGRES_USER" ] || \
   [ -z "$POSTGRES_PASSWORD" ] || \
   [ -z "$POSTGRES_DB" ]; then
  echo "❌ One or more secrets empty"
  echo "   Raw response: $RESPONSE"
  exit 1
fi

echo "✅ Secrets loaded successfully"
echo "   User : $POSTGRES_USER"
echo "   DB   : $POSTGRES_DB"

# ── Start PostgreSQL ───────────────────────────────────
echo "Starting PostgreSQL..."
exec docker-entrypoint.sh postgres