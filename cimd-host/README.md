# cimd-host (legacy)

## Status

**Legacy lab setup, superseded by [`../news-cimd-host/`](../news-cimd-host/README.md).** Not
part of the news pipeline. Kept for reference; nothing in the news repos uses it, and the
container is not running.

## What it was

The first CIMD host, built for the Keycloak lab realm `mcp-lab` (Thread 04-B, Topic 4A, C0
step 3): nginx serving OAuth Client ID Metadata Documents over HTTPS as `https://cimd-host/`.

| Item | Value |
|---|---|
| Image | `nginx:1.30.6-alpine`, container `cimd-host`, network `services_network`, no host port, **no restart policy** |
| TLS | `certs/cimd-host.crt` (SAN `DNS:cimd-host`, expires Nov 2027), signed by its own `certs/ca.crt` — a **different CA** from news-cimd-host's |
| Secret | `start.sh` (host) reads `MCP_LAB_CIMD_HOST_TLS_KEY` from Vault `secret/CREDENTIALS` → Compose secret `cimd_host_tls_key` |
| Cert script | `make-certs.sh` (same flow as news-cimd-host; uses unpinned `alpine:3`) |
| Health | `wget http://127.0.0.1:8081/healthz` (container loopback) |
| Documents | `html/clients/news-cli-cimd.json`, `news-cli-cimd-refresh.json`, `news-cli-cimd-mismatch.json` (client_id deliberately not matching its URL, a negative test) — all for a CLI client with redirect `http://127.0.0.1:8766/callback` |

## What still references it

| Reference | Note |
|---|---|
| `../keycloak/realm/mcp-lab-realm.json` | import is attempted at every Keycloak start but skipped, because realm `mcp-lab` already exists; its CIMD client policy/profile names `cimd-host` |
| `../keycloak/realm/exports/realm-export.json`, `mcp-lab-client-policies.json`, `mcp-lab-client-profiles.json` | exports of the same lab realm (`cimd-policy`, `cimd-profile`) |
| Vault `secret/CREDENTIALS` → `MCP_LAB_CIMD_HOST_TLS_KEY`, `LOCAL_CA_KEY` (both written by `make-certs.sh`; `start.sh` reads the TLS key) | listed in the canonical [Vault table](../README.md#vault-paths) |

Keycloak's truststore only mounts `../news-cimd-host/certs/ca.crt`, so even if started,
Keycloak would not trust this host's certificate.

## Run (only if you need the lab)

```bash
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=...
cd ~/github/docker_services/cimd-host && ./start.sh up -d
```

## Logs

**Logs:** `cimd-host` logs to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days. (Legacy and not started: these apply if it is run again.)
