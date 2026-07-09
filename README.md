# MedicalCircle Dev Infrastructure (Docker on VM)

Cost-saving replacement for GCP managed services in the dev environment.
Everything runs in Docker on a single VM instead of separate managed services.

| Service | Replaces | Port | UI |
|---|---|---|---|
| Kafka | `medicalcircle-kafka-cluster-dev` (Managed Kafka) | `9092` (SASL_PLAINTEXT) | `http://10.216.0.17:8080` |
| Redis | Cloud Memorystore | `6379` | `http://10.216.0.17:8081` |
| Bigtable | Cloud Bigtable | `8086` (gRPC) | — |

**VM:** `dev-emulator-kafka-redis-bigtable` · zone `me-central2-a` · internal `10.216.0.17` · external `34.166.80.237`

---

## Deploy (fresh VM)

```bash
# SSH into the VM
ssh -i ~/.ssh/id_ed25519 ubuntu@34.166.80.237

# Clone the repo (use HTTPS — SSH host key verification fails on this VM)
git clone https://github.com/mashhoudrajput/kafka-redis-bigtable.git
cd kafka-redis-bigtable

# Start all three stacks
cd kafka   && cp .env.example .env && nano .env   # set KAFKA_HOST_IP=10.216.0.17
docker compose up -d --build
bash create-topics.sh

cd ../redis
docker compose up -d

cd ../bigtable
docker compose up -d   # bigtable-init runs automatically and creates all tables
```

---

## Kafka

### How it works

- **Port 9092 (EXTERNAL)** — SASL_PLAINTEXT listener for Cloud Run. App connects with `ssl: false` + SASL/PLAIN. `AllowAllCallbackHandler` accepts any username/password (dev-only).
- **Port 29092 (INTERNAL)** — PLAINTEXT listener for Docker-internal access (`kafka-ui`, `create-topics.sh`, healthcheck).

The Docker image is built from `kafka/Dockerfile` (3 stages):
1. **kafka-libs** — pulls `apache/kafka:3.9.0` to expose its JARs for compilation
2. **builder** — `eclipse-temurin:21-jdk` compiles `AllowAllLoginModule.java` + `AllowAllCallbackHandler.java` against Kafka's classpath into `allowall.jar`
3. **final** — `apache/kafka:3.9.0` with `allowall.jar` installed in `/opt/kafka/libs/`

`kafka-startup.sh` is the container entrypoint. It generates self-signed SSL certs (unused but harmless) then starts the broker.

### Cloud Run requirements

Plain-value env vars set on the `messageingestion` service:

| Env var | Value | Purpose |
|---|---|---|
| `KAFKA_BROKER` | `10.216.0.17:9092` | VM broker address |
| `BIGTABLE_EMULATOR_HOST` | `10.216.0.17:8086` | Routes Bigtable to VM emulator |
| `BIGTABLE_DISABLE_METRICS` | `true` | Disables GCP LB metrics that can hijack the emulator connection |

Secret-based env vars remain unchanged: `KAFKA_USERNAME`, `KAFKA_PASSWORD`, `BIGTABLE_INSTANCE_ID`, `GCP_PROJECT`, etc.

App connects with `kafkaConfig.ssl = false` + SASL/PLAIN. No TLS — `NODE_TLS_REJECT_UNAUTHORIZED` can be removed from Cloud Run if it was previously added.

### Create / recreate topics

```bash
# Run from the VM host (not inside a container)
bash ~/kafka-redis-bigtable/kafka/create-topics.sh
```

### Kafka topics

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

UUID-based topics are created dynamically by the app. Set `KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"` in `kafka/docker-compose.yml` if needed.

---

## Redis

Single-node, no auth, 256 MB memory cap. No changes needed in Cloud Run — `REDIS_ENDPOINT` secret already points to `10.216.0.17:6379`.

---

## Bigtable Emulator

Instance name: `medicalcircles-messaging-dev`  
Project: `677473027585` (numeric ID for `lively-synapse-400818`)

> **Why the number?** `@google-cloud/bigtable` v6 resolves the project string to its numeric ID via the Resource Manager API before querying Bigtable. The emulator namespace must match what the client sends, so all tooling uses `677473027585`.

`bigtable-init` runs once on first `docker compose up` and creates all 10 tables.

### Tables

| Table | Column Family |
|---|---|
| `inbox_by_user` | `m` |
| `messages` | `body` |
| `broadcasts_global` | `b` |
| `broadcasts_hospital` | `b` |
| `progress_global_by_user` | `p` |
| `progress_hospital_by_user` | `p` |
| `counter_global` | `c` |
| `counter_hospital` | `c` |
| `counter_global_seq` | `c` |
| `counter_hospital_seq` | `c` |

To re-run the table bootstrap manually:

```bash
docker run --rm \
  --network bigtable_default \
  -e BIGTABLE_EMULATOR_HOST=bigtable-emulator:8086 \
  -e BIGTABLE_PROJECT=677473027585 \
  -e BIGTABLE_INSTANCE=medicalcircles-messaging-dev \
  -v $(pwd)/bigtable/bootstrap-bigtable.sh:/bootstrap.sh:ro \
  gcr.io/google.com/cloudsdktool/cloud-sdk:latest \
  bash /bootstrap.sh
```

---

## Useful commands

```bash
# ── Kafka ──────────────────────────────────────────────────────────────────
# List topics (uses the PLAINTEXT internal listener, no SSL/SASL needed)
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:29092 --list

# Re-create all topics after a restart
bash ~/kafka-redis-bigtable/kafka/create-topics.sh

# ── Redis ───────────────────────────────────────────────────────────────────
docker exec -it redis redis-cli

# ── Bigtable ────────────────────────────────────────────────────────────────
# List tables — cbt is only in cloud-sdk:latest, not in the emulator image
docker run --rm --network bigtable_default \
  -e BIGTABLE_EMULATOR_HOST=bigtable-emulator:8086 \
  gcr.io/google.com/cloudsdktool/cloud-sdk:latest \
  cbt -project 677473027585 -instance medicalcircles-messaging-dev ls

# ── Restart stacks ──────────────────────────────────────────────────────────
docker compose -f ~/kafka-redis-bigtable/kafka/docker-compose.yml restart
docker compose -f ~/kafka-redis-bigtable/redis/docker-compose.yml restart
docker compose -f ~/kafka-redis-bigtable/bigtable/docker-compose.yml restart

# ── Full reset (destroys data) ───────────────────────────────────────────────
docker compose -f ~/kafka-redis-bigtable/kafka/docker-compose.yml down -v
docker compose -f ~/kafka-redis-bigtable/redis/docker-compose.yml down -v
docker compose -f ~/kafka-redis-bigtable/bigtable/docker-compose.yml down -v
```

---

## File structure

```
kafka/
  Dockerfile                  3-stage build: kafka-libs → eclipse-temurin:21-jdk builder → apache/kafka:3.9.0
  AllowAllLoginModule.java     JAAS LoginModule (required by PlainLoginModule config)
  AllowAllCallbackHandler.java dev-only SASL callback handler — accepts any username/password
  kafka-startup.sh             entrypoint: generates SSL certs (unused), then starts the broker
  docker-compose.yml           SASL_PLAINTEXT on 9092, PLAINTEXT on 29092, kafka-ui on 8080
  create-topics.sh             creates all 20 topics (run manually after first start)
  .env                         KAFKA_HOST_IP=10.216.0.17  ← gitignored
  .env.example                 template

redis/
  docker-compose.yml           redis:7.4-alpine on 6379, redis-commander on 8081

bigtable/
  docker-compose.yml           cloud-sdk emulator on 8086 + init container
  bootstrap-bigtable.sh        creates all 10 tables in medicalcircles-messaging-dev instance
```
