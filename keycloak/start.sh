set -euo pipefail

: "${VAULT_ADDR:?set VAULT_ADDR, e.g. http://localhost:8200}"
: "${VAULT_TOKEN:?set VAULT_TOKEN}"
KC_VAULT_PATH="${KC_VAULT_PATH:-secret/CREDENTIALS}"

# -field prints the raw value, so no JSON parsing is needed. set -e stops the script if either read fails.
KC_ADMIN_USER="$(vault kv get -field=KC_ADMIN_USER "$KC_VAULT_PATH")"
KC_ADMIN_PASSWORD="$(vault kv get -field=KC_ADMIN_PASSWORD "$KC_VAULT_PATH")"
export KC_ADMIN_USER KC_ADMIN_PASSWORD

if [ "$#" -eq 0 ]; then
  set -- up -d
fi

cd "$(dirname "$0")"
docker compose -f docker-compose.yml "$@"