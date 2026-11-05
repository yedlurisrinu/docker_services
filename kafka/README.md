# kafka

## Purpose

Apache Kafka (single broker, KRaft mode, no ZooKeeper) is the article queue between fetching and
indexing: news-fetch-scheduler produces new articles to topic `news_ai_pipeline_dev_t_0`,
news-consumer-ingester consumes them (group `news_ai_summary_group`), fetches full content and
indexes into Elasticsearch. Kafka UI (kafbat) is a browser view of the cluster.

## How it is set up

| Item | kafka | kafka-ui |
|---|---|---|
| Image | `apache/kafka:4.0.0` | `ghcr.io/kafbat/kafka-ui:v1.5.0` |
| Container | `kafka` | `kafka-ui` |
| Mode | KRaft, `KAFKA_PROCESS_ROLES=broker,controller`, `NODE_ID=1`, voters `1@kafka:9093` | cluster `local`, bootstrap `kafka:9092`, `DYNAMIC_CONFIG_ENABLED=true` |
| Listeners | `PLAINTEXT://:9092` (advertised `kafka:9092`, in-network), `PLAINTEXT_HOST://:29092` (advertised `localhost:29092`, host), `CONTROLLER://:9093`; all PLAINTEXT, inter-broker `PLAINTEXT` | — |
| Replication | offsets topic RF 1, transaction log RF 1 / min ISR 1, `GROUP_INITIAL_REBALANCE_DELAY_MS=0` | — |
| Volume | `kafka-data` → `/var/lib/kafka/data` (`KAFKA_LOG_DIRS`) | — |
| Healthcheck | `kafka-broker-api-versions.sh --bootstrap-server localhost:9092`, 15s, 5 retries, 30s start | none |
| Secrets | none: no Vault access, no authentication, no TLS | none |
| Network | `services_network` (external) | same |
| Restart | `unless-stopped` | `unless-stopped`, `depends_on: kafka` |

**Data persistence:** `KAFKA_LOG_DIRS=/var/lib/kafka/data` puts topics, messages, consumer
offsets and KRaft metadata on the `kafka-data` volume, so they survive restarts **and** container
recreates (verified 2026-11-04 with `up -d --force-recreate`). Before that date the broker used the
image default `/tmp/kafka-logs` inside the container; the topic was recreated empty when this was
fixed (every message had already been indexed). `docker compose down -v` still deletes the volume.

### Topic `news_ai_pipeline_dev_t_0`

| Property | Value |
|---|---|
| Partitions | 3 |
| Replication factor | 1 |
| Configs | defaults |
| Auto-create | off (`KAFKA_AUTO_CREATE_TOPICS_ENABLE=false`): producing to a missing topic fails with `UNKNOWN_TOPIC_OR_PARTITION` instead of silently creating a 1-partition topic |
| Created by | `~/github/kafka_topic_creation.sh` (outside this repo): `kafka-topics.sh --create --if-not-exists --topic news_ai_pipeline_dev_t_0 --partitions 3 --replication-factor 1` via `docker exec kafka` |
| Producer | news-fetch-scheduler (`TOPIC_NAME` in `src/resources/app-config-settings.toml`, `bootstrap.servers=kafka:9092`) |
| Consumer group | `news_ai_summary_group` (news-consumer-ingester, `application_config.toml`: `auto.offset.reset=latest`, `enable.auto.commit=false`) |

**Logs:** `kafka`, `kafka-ui` log to stdout/stderr. Docker keeps that copy (`docker logs <container>`), rotated at 3 × 10 MB per container with the oldest file deleted automatically (`logging:` in `docker-compose.yml`). [log-collector](../log-collector/README.md) also copies it to `~/github/logs/services/<container>/YYYY-MM-DD.log`, kept 14 days. Kafka also writes its own rotated files (`controller.log`, `kafka-request.log`, ...) to `/opt/kafka/logs` inside the container; those are not mounted and are lost on a recreate — the collected stdout copy is the one to use.

## Where it fits

Slice of the [canonical diagram](../README.md#architecture).

```mermaid
flowchart LR
  sched[news-fetch-scheduler]
  ingest[news-consumer-ingester]
  kafka[[Kafka<br/>kafka:9092]]

  sched -- "Kafka produce · news_ai_pipeline_dev_t_0" --> kafka
  kafka -- "Kafka consume · news_ai_summary_group" --> ingest

  classDef focus fill:#fde68a,stroke:#b45309,stroke-width:2px,color:#111;
  class kafka focus;
```

## Depends on / Depended on by

**Depends on:** only the `services_network` network. No Vault, no other service.

**Depended on by**

| Component | What for |
|---|---|
| news-fetch-scheduler | produces new (deduplicated) articles to `news_ai_pipeline_dev_t_0` via `kafka:9092` |
| news-consumer-ingester | consumes `news_ai_pipeline_dev_t_0` as group `news_ai_summary_group` via `kafka:9092`, commits offsets manually |
| kafka-ui | cluster browser at http://127.0.0.1:8082 (host 8082 → container 8080), reads the cluster via `kafka:9092` |

## Config & secrets

- All configuration is env vars in `docker-compose.yml` (`KAFKA_*`, `KAFKA_CLUSTERS_0_*`).
- No Vault path, no secrets. Anyone who can reach port 29092 or 8082 can read/write topics.
- Topic creation lives in `~/github/kafka_topic_creation.sh`, not in this directory.

## Run locally

Prerequisite: `services_network` exists. No `VAULT_TOKEN` needed.

```bash
cd ~/github/docker_services/kafka
docker compose up -d
bash ~/github/kafka_topic_creation.sh     # once, or after the kafka-data volume was removed
                                          # (topics survive container recreates)
```

Start before news-fetch-scheduler and news-consumer-ingester. Not included in the root
`../docker-compose.yml`.

## Test

```bash
docker inspect -f '{{.State.Health.Status}}' kafka
docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 \
  --describe --topic news_ai_pipeline_dev_t_0          # 3 partitions, RF 1, leader 1
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server kafka:9092 \
  --describe --group news_ai_summary_group             # lag per partition
docker exec kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 | head -1
# Kafka UI: http://localhost:8082
```

## Ports

| Host | Container | Bind | Note |
|---|---|---|---|
| 29092 | 29092 | 127.0.0.1 | host clients, advertised as `localhost:29092` |
| — | 9092 | `services_network` | `kafka:9092` for containers |
| — | 9093 | not published | KRaft controller |
| 8082 | 8080 | 127.0.0.1 | Kafka UI |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Producer: `UNKNOWN_TOPIC_OR_PARTITION` / topic missing | topic never created, or the `kafka-data` volume was removed (`down -v`); auto-create is off, so the broker does not create it | run `kafka_topic_creation.sh` |
| Ingester starts but skips existing messages | `auto.offset.reset=latest` with no committed offsets (new group or offsets lost) | expected; reset offsets with `kafka-consumer-groups.sh --reset-offsets` if needed |
| Host client cannot connect / resolve `kafka:9092` | host client bootstrapped with `kafka:9092`: `kafka` is not in `/etc/hosts` and 9092 is not published | host clients use `localhost:29092` (the advertised host listener); containers use `kafka:9092` |
| Container client times out on `localhost:29092` | advertised host listener points to the container itself | use `kafka:9092` |
| Consumer group stuck rebalancing | ingester exceeded `max.poll.interval.ms` (300 s) | check ingester logs / batch size |
| kafka-ui shows cluster offline | kafka not up yet (no healthcheck dependency) | `docker compose restart kafka-ui` |
