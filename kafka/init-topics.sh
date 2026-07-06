#!/bin/bash
set -e

BOOTSTRAP="kafka:9092"
KAFKA_BIN="kafka-topics.sh"  # /opt/kafka/bin is on PATH in apache/kafka image

# Wait until Kafka is accepting connections
echo "Waiting for Kafka broker at $BOOTSTRAP..."
until $KAFKA_BIN --bootstrap-server "$BOOTSTRAP" --list > /dev/null 2>&1; do
  echo "  not ready yet, retrying in 3s..."
  sleep 3
done
echo "Kafka is ready."

create_topic() {
  local topic="$1"
  local partitions="$2"
  local rf="$3"

  if $KAFKA_BIN --bootstrap-server "$BOOTSTRAP" --describe --topic "$topic" > /dev/null 2>&1; then
    echo "  [skip] $topic already exists"
  else
    $KAFKA_BIN --bootstrap-server "$BOOTSTRAP" --create \
      --topic "$topic" \
      --partitions "$partitions" \
      --replication-factor "$rf"
    echo "  [ok]   $topic  (partitions=$partitions, rf=$rf)"
  fi
}

echo ""
echo "=== Creating application topics ==="

# Core event topics
create_topic "ehr.events"                    1  1
create_topic "workflow.events"               1  1
create_topic "notification"                  5  1
create_topic "cluster_broadcast_stream"      1  1
create_topic "public_medicalcircle_stream"   1  1

# Messaging - broadcast list
create_topic "msg.broadcastlist.t0"          3  1

# Messaging - group
create_topic "msg.group.t0"                  3  1
create_topic "msg.group.t1"                  3  1
create_topic "msg.group.t2"                  3  1

# Messaging - PC list
create_topic "msg.pclist.t0"                 3  1
create_topic "msg.pclist.t1"                 3  1
create_topic "msg.pclist.t2"                 3  1

# Messaging - subnetwork broadcast list
create_topic "msg.subnetworkbroadcastlist.t0"  1  1
create_topic "msg.subnetworkbroadcastlist.t1"  1  1

# Messaging - task list
create_topic "msg.tasklist.t0"               3  1
create_topic "msg.tasklist.t1"               3  1
create_topic "msg.tasklist.t2"               3  1

# Messaging - user
create_topic "msg.user.t0"                   3  1
create_topic "msg.user.t1"                   3  1
create_topic "msg.user.t2"                   3  1

echo ""
echo "=== All topics created ==="
$KAFKA_BIN --bootstrap-server "$BOOTSTRAP" --list | grep -v "^__"
