# qdrant

## Purpose

Qdrant vector database, a general-purpose local service. **Not used by the news pipeline**: no
reference in news-summary-agent, news-fetch-scheduler, news-consumer-ingester or es-mcp-server
(es-mcp-server's search is lexical, `multi_match` on `title`/`content`; the Elasticsearch
`content.semantic` field exists in the mapping but is not queried yet).

## How it is set up

| Item | Value |
|---|---|
| Image | `qdrant/qdrant:v1.18.2` |
| Container | `qdrant` |
| Volumes | `qdrant_data` → `/qdrant/storage` |
| Secrets | none: no Vault access, no API key configured |
| Healthcheck | none |
| Network | `services_network` |
| Restart | `unless-stopped` |

The compose file runs the official image directly (an unused, broken `Dockerfile` was removed).

**Logs:** `qdrant` logs to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days.

## Depended on by

Not used by the news pipeline. Depends on nothing.

## Config & secrets

None. All defaults of the image.

## Run locally

```bash
cd ~/github/docker_services/qdrant
docker compose up -d
curl -s http://127.0.0.1:6333/healthz          # dashboard: http://localhost:6333/dashboard
```

Also included by the root `../docker-compose.yml`. No `VAULT_TOKEN` needed.

## Ports

| Host | Container | Bind | Note |
|---|---|---|---|
| 6333 | 6333 | 127.0.0.1 | REST + dashboard |
| 6334 | 6334 | 127.0.0.1 | gRPC |
