#!/usr/bin/env bash
#
# bootstrap-bigtable.sh
#
# Purpose:
#   Creates all Bigtable tables and column families required by the
#   Medical Circles backend against a Cloud Bigtable EMULATOR instance.
#   Safe to re-run — every step is idempotent (already-exists is not an error).
#
# Usage:
#   BIGTABLE_EMULATOR_HOST=34.166.80.237:8086 ./bootstrap-bigtable.sh
#
#   Optional overrides:
#     BIGTABLE_PROJECT=lively-synapse-400818
#     BIGTABLE_INSTANCE=medicalcircles-messaging-dev

set -euo pipefail

: "${BIGTABLE_EMULATOR_HOST:?ERROR: BIGTABLE_EMULATOR_HOST must be set, e.g. BIGTABLE_EMULATOR_HOST=34.166.80.237:8086}"
BIGTABLE_PROJECT="${BIGTABLE_PROJECT:-lively-synapse-400818}"
BIGTABLE_INSTANCE="${BIGTABLE_INSTANCE:-medicalcircles-messaging-dev}"

export BIGTABLE_EMULATOR_HOST

if ! command -v cbt >/dev/null 2>&1; then
  echo "ERROR: 'cbt' not found. Install: gcloud components install cbt" >&2
  exit 1
fi

echo "== Bigtable bootstrap =="
echo "Emulator host : ${BIGTABLE_EMULATOR_HOST}"
echo "Project       : ${BIGTABLE_PROJECT}"
echo "Instance      : ${BIGTABLE_INSTANCE}"
echo "========================"

CBT="cbt -project ${BIGTABLE_PROJECT} -instance ${BIGTABLE_INSTANCE}"

create_table_and_family() {
  local table="$1"
  local family="$2"
  ${CBT} createtable "${table}" 2>/dev/null || echo "  -> table '${table}' already exists"
  ${CBT} createfamily "${table}" "${family}" 2>/dev/null || echo "  -> family '${table}:${family}' already exists"
  echo "  [ok] ${table} / ${family}"
}

echo ""
echo "Creating tables..."

# Inbox pointer table — CF 'm' (touch, delivery_status, delivered_at, notification_ack_time)
create_table_and_family inbox_by_user m

# Canonical message payload — CF 'body'
create_table_and_family messages body

# Global broadcast log — CF 'b'
create_table_and_family broadcasts_global b

# Per-hospital/network broadcast log — CF 'b'
create_table_and_family broadcasts_hospital b

# Per-user read-progress tracking — CF 'p' (base, join_seq)
create_table_and_family progress_global_by_user p
create_table_and_family progress_hospital_by_user p

# Sequence counters (two naming schemes coexist — both created to avoid NOT_FOUND)
create_table_and_family counter_global     c
create_table_and_family counter_hospital   c
create_table_and_family counter_global_seq   c
create_table_and_family counter_hospital_seq c

echo ""
echo "Bootstrap complete. Tables in ${BIGTABLE_INSTANCE}:"
${CBT} ls
