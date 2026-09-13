echo "=== Step 1: All Docker Networks ==="
docker network ls

echo ""
echo "=== Step 2: Vault Container Networks ==="
docker inspect vault-server \
  --format '{{json .NetworkSettings.Networks}}' | \
  python3 -m json.tool

echo ""
echo "=== Step 3: Vault Container Name ==="
docker ps --format "{{.Names}}" | grep vault

echo ""
echo "=== Step 4: Test vault reachable on each network ==="
# Get all network names vault is on
NETWORKS=$(docker inspect vault-server \
  --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')

for NETWORK in $NETWORKS; do
  echo -n "Testing network '$NETWORK': "
  RESULT=$(docker run --rm \
    --network $NETWORK \
    alpine \
    wget -qO- --timeout=3 \
    http://vault-server:8200/v1/sys/health \
    2>&1)
  if echo "$RESULT" | grep -q "initialized"; then
    echo "✅ REACHABLE — use this network name"
  else
    echo "❌ not reachable"
  fi
done