# mongodb

## Purpose

MongoDB plus the Mongo Express web UI, a general-purpose local document store. **Not used by the
news pipeline**: no reference in news-summary-agent, news-fetch-scheduler,
news-consumer-ingester or es-mcp-server.

## How it is set up

| Item | mongodb | mongo-express |
|---|---|---|
| Image | built from `Dockerfile` (`FROM mongo:8.0` + curl, perl, libjson-perl) | built from `Dockerfile-express` (`FROM mongo-express:1.0.2` + bash, curl, perl, perl-json) |
| Command | `bash /start-mongodb.sh` → `docker-entrypoint.sh mongod` | `bash /start-mongo-express.sh` → `/docker-entrypoint.sh mongo-express` |
| Secrets | start script in container reads `MONGO_USER`, `MONGO_PASSWORD` from Vault (`GET /v1/secret/data/CREDENTIALS`), exports `MONGO_INITDB_ROOT_USERNAME/PASSWORD` | same keys → `ME_CONFIG_MONGODB_ADMINUSERNAME/PASSWORD`, `ME_CONFIG_MONGODB_URL=mongodb://...@mongodb:27017/` |
| Vault token | Compose secret `vault_token` (from `VAULT_TOKEN` in your shell), read from `/run/secrets/vault_token` | same |
| Volumes | `mongodb_data` → `/data/db` | — |
| Healthcheck | none | none |
| Networks | `vault-network`, `services_network` | same |
| Restart | `unless-stopped` | `unless-stopped`, `depends_on: mongodb` |

`ME_CONFIG_BASICAUTH=false`: Mongo Express has no login of its own.

**Logs:** `mongodb`, `mongo-express` log to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days.

## Depended on by

Not used by the news pipeline. Depends on Vault.

## Config & secrets

| Kind | Name |
|---|---|
| Vault | `secret/CREDENTIALS` → `MONGO_USER`, `MONGO_PASSWORD` |
| Env | `VAULT_ADDR=http://vault-server:8200`, `VAULT_SECRET_PATH=secret/data/CREDENTIALS`, `ME_CONFIG_BASICAUTH=false` (token via the Compose secret) |

The start scripts print the Mongo user name but never the password. Mongo Express has no login,
so it is published on `127.0.0.1:8081` only.

## Run locally

```bash
export VAULT_TOKEN=...          # Vault must be unsealed
cd ~/github/docker_services/mongodb
docker compose up -d --build
docker exec mongodb mongosh --quiet --eval 'db.runCommand({ping:1})'   # auth may be needed for more
```

Also included by the root `../docker-compose.yml`.

## Ports

| Host | Container | Bind | Note |
|---|---|---|---|
| 27017 | 27017 | 127.0.0.1 | MongoDB |
| 8081 | 8081 | 127.0.0.1 | Mongo Express (no auth) |
