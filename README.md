# MedicalCircle Dev Infrastructure

Local replacements for GCP managed services, running on the `db-init-cluster-001-dev` VM
(`me-central2-a`, internal IP `10.216.0.10`) to reduce dev environment costs.

| Service | Replaces | Port | UI |
|---|---|---|---|
| Kafka | `medicalcircle-kafka-cluster-dev` (Managed Kafka) | `9092` | `http://10.216.0.10:8080` |
| Redis | Cloud Memorystore | `6379` | `http://10.216.0.10:8081` |
| Bigtable | Cloud Bigtable | `8086` (gRPC) | — |

---

## Prerequisites

- Docker + Docker Compose v2 on the VM
- VM firewall allows TCP `9092`, `6379`, `8086`, `8080`, `8081` from Cloud Run's VPC subnet

```bash
gcloud compute firewall-rules create allow-dev-services-internal \
  --network=default \
  --allow=tcp:9092,tcp:6379,tcp:8086,tcp:8080,tcp:8081 \
  --source-ranges=10.0.0.0/8 \
  --description="Dev infra ports for Cloud Run internal access"
```

---

## Deploy

SSH into the VM, copy the folders, then start each service:

```bash
gcloud compute scp --recurse kafka/ redis/ bigtable/ \
  db-init-cluster-001-dev:~/ --zone=me-central2-a
```

```bash
gcloud compute ssh db-init-cluster-001-dev --zone=me-central2-a
```

### Kafka

```bash
cd ~/kafka
chmod +x init-topics.sh
sudo docker compose up -d

# Watch startup
sudo docker logs -f kafka

# Verify topics were created
sudo docker logs kafka-init
```

Creates 20 topics mirroring production. UI at `http://10.216.0.10:8080`.

### Redis

```bash
cd ~/redis
sudo docker compose up -d
```

Single-node, no auth, 256 MB memory cap. UI at `http://10.216.0.10:8081`.

### Bigtable emulator

```bash
cd ~/bigtable
chmod +x init-tables.sh
sudo docker compose up -d

# Verify tables were created
sudo docker logs bigtable-init
```

---

## Update Cloud Run services

For each Cloud Run service, update these environment variables:

### Kafka

```
KAFKA_BOOTSTRAP_SERVERS  →  10.216.0.10:9092
KAFKA_SECURITY_PROTOCOL  →  PLAINTEXT
```
Remove any `KAFKA_SSL_*` or `KAFKA_SASL_*` variables.

### Redis

```
REDIS_HOST  →  10.216.0.10
REDIS_PORT  →  6379
```
Remove any TLS or auth variables used with Memorystore.

### Bigtable

```
BIGTABLE_EMULATOR_HOST  →  10.216.0.10:8086
```
Setting `BIGTABLE_EMULATOR_HOST` makes the official Google Bigtable client libraries
automatically route all traffic to the emulator instead of GCP.
Do not set `GOOGLE_APPLICATION_CREDENTIALS` for Bigtable in dev — the emulator ignores auth.

---

## Topics (Kafka)

| Topic | Partitions |
|---|---|
| `ehr.events` | 1 |
| `workflow.events` | 1 |
| `notification` | 5 |
| `cluster_broadcast_stream` | 1 |
| `public_medicalcircle_stream` | 1 |
| `msg.broadcastlist.t0` | 3 |
| `msg.group.t0/t1/t2` | 3 each |
| `msg.pclist.t0/t1/t2` | 3 each |
| `msg.subnetworkbroadcastlist.t0/t1` | 1 each |
| `msg.tasklist.t0/t1/t2` | 3 each |
| `msg.user.t0/t1/t2` | 3 each |

UUID-based topics (`ab3b7a1d-...`, `private_*_stream`) are created dynamically by the app.
Enable `KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"` in `kafka/docker-compose.yml` if needed.

---

## Useful commands

```bash
# Restart everything
sudo docker compose -f ~/kafka/docker-compose.yml restart
sudo docker compose -f ~/redis/docker-compose.yml restart
sudo docker compose -f ~/bigtable/docker-compose.yml restart

# Stop and wipe data (full reset)
sudo docker compose -f ~/kafka/docker-compose.yml down -v
sudo docker compose -f ~/redis/docker-compose.yml down -v
sudo docker compose -f ~/bigtable/docker-compose.yml down -v

# Re-run topic/table init manually
sudo docker start kafka-init
sudo docker start bigtable-init

# List Kafka topics
sudo docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list

# Redis CLI
sudo docker exec -it redis redis-cli
```

---

## File structure

```
kafka/
  docker-compose.yml    apache/kafka:3.9.0 + kafka-ui
  init-topics.sh        creates all 20 topics on first start

redis/
  docker-compose.yml    redis:7.4-alpine + redis-commander

bigtable/
  docker-compose.yml    cloud-sdk bigtable emulator
  init-tables.sh        creates tables on first start
```
