# log-collector

## Purpose
Copies the stdout/stderr of the infrastructure containers into files on the host, so their logs
sit next to the applications' logs: `~/github/logs/services/<container>/YYYY-MM-DD.log`, one file
per container per day. It is [Vector](https://vector.dev) reading logs through the Docker API.

The applications (news-summary-app, es-mcp-server-r1/r2, news_fetch_scheduler,
news_consumer_ingester) already write their own files to `~/github/logs` and are excluded, as is
the collector itself.

## How it is set up
| Item | Value |
|---|---|
| Image | `timberio/vector:0.47.0-alpine` |
| Config | `vector.yaml`: source `docker_logs`, a remap that prefixes each line with its UTC timestamp and stream, sink `file` with path `/logs/{{ container_name }}/%Y-%m-%d.log` |
| Output | `../../logs/services` mounted at `/logs` |
| Docker access | `/var/run/docker.sock` mounted **read-only**; runs as `1000:1000` with group `989` (the socket's `docker` group) so the files belong to you |
| Retention | the container's command deletes files older than `LOG_RETENTION_DAYS` (14) once a day, then empty directories |
| Healthcheck | Vector API `/health` on container-local `127.0.0.1:8686` (not published) |
| Restart / own logs | `unless-stopped`; Docker log rotation 3 × 10 MB like every other container |

## Depends on / Depended on by
| | Component | What for |
|---|---|---|
| Depends on | Docker engine (socket) | list containers and stream their logs |
| Depended on by | nobody | output is for people reading logs |

## Config & secrets
No Vault, no secrets. Settings: `LOG_RETENTION_DAYS` (compose environment), the excluded
container list (`vector.yaml`), the socket group id (`group_add`; check with
`stat -c %g /var/run/docker.sock`).

**Security note:** read access to the Docker socket is effectively root on the Docker host. Fine
for local development; do not copy this setup to a shared or production host.

## Run locally
```bash
cd ~/github/docker_services/log-collector
docker compose -f docker-compose.yml up -d
```
It collects from the moment it starts (no back-fill of older output); new containers are picked
up automatically.

## Test
```bash
docker inspect -f '{{.State.Health.Status}}' log-collector
ls ~/github/logs/services/                       # one directory per container
tail -f ~/github/logs/services/es-mcp-lb/$(date -u +%F).log
```

## Ports
None.

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| No files appear; logs show `permission denied` on `/var/run/docker.sock` | `group_add` does not match the socket's group id | `stat -c %g /var/run/docker.sock` and update `group_add` |
| A container is missing | it has written nothing since the collector started, or it is in `exclude_containers` | wait for output, or adjust `vector.yaml` |
| Gaps after the collector was down | Docker keeps only 3 × 10 MB per container; output rotated away while the collector was down is not in the files | keep the collector running (`restart: unless-stopped`) |
| Disk use | 14 days of daily files | lower `LOG_RETENTION_DAYS` |
