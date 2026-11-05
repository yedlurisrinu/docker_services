# mcp-lab-lb (legacy)

## Status

**Legacy lab setup, superseded by [`../es-mcp-lb/`](../es-mcp-lb/README.md).** Not part of the
news pipeline; nothing in the news repos uses it, and its containers are not running.

## What it was

Thread 04-B, Topic 4A, C0 step 4: two stub MCP replicas behind nginx, to prove round-robin
load balancing, Host-header forwarding and SSE pass-through before the real es-mcp-server
existed.

| Service | Details |
|---|---|
| `mcp-replica-1`, `mcp-replica-2` | image `mcp-lab-stub:0.0.1` built from `stub/` (`python:3.12-slim`, `mcp==2.3.0`, `uvicorn==0.54.0`, non-root uid 10001). `stub/server.py`: stateless streamable HTTP, one tool `which_replica`, `/healthz`, DNS-rebinding protection with `MCP_ALLOWED_HOSTS=localhost:8001`, no auth |
| `mcp-lb` | `nginx:1.30.6-alpine`, `127.0.0.1:8001` → container 80, upstream `mcp-replica-1:8000`, `mcp-replica-2:8000` (`max_fails=2 fail_timeout=10s`, no `resolve`, no keepalive), `/mcp` only, `proxy_buffering off`, `proxy_read_timeout 300s`, `/lb-healthz` |

All on `services_network`; no secrets, no Vault, no restart policy.

## What still references it

| Reference | Note |
|---|---|
| `../keycloak/realm/mcp-lab-realm.json` | lab realm `mcp-lab` (import attempted at every Keycloak start, skipped because the realm already exists): resource `http://localhost:8001/mcp` (this balancer) for client `news-mcp-server` |
| `../keycloak/realm/exports/realm-export.json`, `mcp-lab-client-profiles.json` | same URL in the lab realm exports |

The live pipeline uses `http://es-mcp-lb:9599/mcp` instead.

## Run (only if you need the lab)

```bash
cd ~/github/docker_services/mcp-lab-lb && docker compose up -d --build
curl -s http://127.0.0.1:8001/lb-healthz
```

## Logs

**Logs:** `mcp-lb`, `mcp-replica-1`, `mcp-replica-2` log to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days. (Legacy and not started: these apply if it is run again.)
