# redis

## Purpose

Redis plus RedisInsight, a general-purpose local cache / key-value store. **Not used by the news
pipeline**: no reference in news-summary-agent, news-fetch-scheduler, news-consumer-ingester or
es-mcp-server.

## How it is set up

| Item | redis | redisinsight |
|---|---|---|
| Image | built from `Dockerfile` (`FROM redis:8.6-alpine` + curl, bash, perl, perl-json) | `redis/redisinsight:2.60` |
| Command | `bash /start-redis.sh` → `redis-server --requirepass "$REDIS_PASSWORD"` | image default |
| Secrets | start script in container reads `REDIS_PASSWORD` from Vault (`GET /v1/secret/data/CREDENTIALS`) | none (connection added in its UI) |
| Vault token | Compose secret `vault_token` (from `VAULT_TOKEN` in your shell), read from `/run/secrets/vault_token` | — |
| Volumes | `redis_data` → `/data` | `redisinsight_data` → `/data` |
| Other | `sysctls: net.core.somaxconn=512`; `vm.overcommit_memory=1` is set as an env var, which has no kernel effect | — |
| Healthcheck | none | none |
| Networks | `vault-network`, `services_network` | `services_network` |
| Restart | `unless-stopped` | `unless-stopped`, `depends_on: redis` |

The password is passed with `--requirepass` on the `redis-server` command line; redis-server
hides its arguments (the process shows as `redis-server *:6379`), and `docker inspect` only shows
`bash /start-redis.sh`.

**Logs:** `redis`, `redisinsight` log to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days.

## Depended on by

Not used by the news pipeline. Depends on Vault.

## Config & secrets

| Kind | Name |
|---|---|
| Vault | `secret/CREDENTIALS` → `REDIS_PASSWORD` |
| Env | `VAULT_ADDR=http://vault-server:8200`, `VAULT_SECRET_PATH=secret/data/CREDENTIALS` (token via the Compose secret) |

If `REDIS_PASSWORD` is missing, `start-redis.sh` lists the key **names** found at the path and
exits; it never prints values.

## Run locally

```bash
export VAULT_TOKEN=...          # Vault must be unsealed
cd ~/github/docker_services/redis
docker compose up -d --build
docker exec -it redis redis-cli -a "$(vault kv get -field=REDIS_PASSWORD secret/CREDENTIALS)" ping   # PONG
```

Also included by the root `../docker-compose.yml`.

## Ports

| Host | Container | Bind | Note |
|---|---|---|---|
| 6379 | 6379 | 127.0.0.1 | Redis |
| 5540 | 5540 | 127.0.0.1 | RedisInsight UI |
