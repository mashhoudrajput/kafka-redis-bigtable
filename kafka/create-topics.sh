#!/bin/bash
# Run this script on the VM host (not inside a container)
# Usage: bash create-topics.sh

set -e
BIN="docker exec kafka /opt/kafka/bin/kafka-topics.sh"
BS="--bootstrap-server localhost:9092"

echo "Waiting for Kafka..."
until $BIN $BS --list > /dev/null 2>&1; do sleep 2; done
echo "Kafka ready."

t() { $BIN $BS --create --if-not-exists --topic "$1" --partitions "$2" --replication-factor 1 && echo "  [ok] $1" || echo "  [skip] $1"; }

t ehr.events                       1
t workflow.events                  1
t notification                     5
t cluster_broadcast_stream         1
t public_medicalcircle_stream      1
t msg.broadcastlist.t0             3
t msg.group.t0                     3
t msg.group.t1                     3
t msg.group.t2                     3
t msg.pclist.t0                    3
t msg.pclist.t1                    3
t msg.pclist.t2                    3
t msg.subnetworkbroadcastlist.t0   1
t msg.subnetworkbroadcastlist.t1   1
t msg.tasklist.t0                  3
t msg.tasklist.t1                  3
t msg.tasklist.t2                  3
t msg.user.t0                      3
t msg.user.t1                      3
t msg.user.t2                      3

echo ""
echo "=== Topics ==="
$BIN $BS --list | grep -v "^__"
