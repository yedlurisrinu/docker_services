# pypi-server

## Purpose

A local PyPI index (pypiserver) that used to host the private wheel `py-commons-per` (Vault
config loader + logging setup). **Not used by the news pipeline any more**: per
`~/github/news-intelligence-platform/docs/adr/0006-thread-03d-gate-1-news-fetch-scheduler.md`
the shared code was inlined into each service and `pypi-server` / `py-commons-per` were retired.
The container is not running.

## How it is set up

| Item | Value |
|---|---|
| Image | `pypiserver/pypiserver:v2.4.1` |
| Compose project | `name: infra` |
| Container | `pypi-server` |
| Command | `run -p 8080 -a . -P . --overwrite /data/packages` — authentication disabled for all actions (`-a . -P .`), uploads may overwrite |
| Volumes | `pypi_packages` (named) → `/data/packages` |
| Secrets | none, no Vault |
| Healthcheck | none |
| Network | `infra-network` (bridge, created by this file; **not** `services_network`) |
| Restart | `unless-stopped` |

**Logs:** `pypi-server` logs to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days. (Retired and not started: these apply if it is run again.)

## Depended on by

Nothing current. Stale mention: `~/github/news-fetch-scheduler/CLAUDE.md` still describes
`requirements_locales.txt` installing `py-commons-per` from `http://localhost:8080/simple/`
(that file no longer exists in the scheduler repo). Port 8080 is historically why Keycloak uses 8180.

## Config & secrets

None.

## Run locally

```bash
cd ~/github/docker_services/pypi-server
docker compose up -d
curl -s http://127.0.0.1:8080/simple/
```

**Not** started by the root `../docker-compose.yml`: its `include` line there is commented out (retired).

## Ports

| Host | Container | Bind |
|---|---|---|
| 8080 | 8080 | 0.0.0.0 |
