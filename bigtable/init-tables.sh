#!/bin/bash
set -e

export BIGTABLE_EMULATOR_HOST="${BIGTABLE_EMULATOR_HOST:-localhost:8086}"
PROJECT="${PROJECT_ID:-lively-synapse-400818}"
INSTANCE="medicalcircle-dev"

echo "Waiting for Bigtable emulator at $BIGTABLE_EMULATOR_HOST..."
until bash -c "echo > /dev/tcp/bigtable-emulator/8086" 2>/dev/null; do
  echo "  not ready, retrying in 2s..."
  sleep 2
done
echo "Emulator is ready."

create_table() {
  local table="$1"
  local families="$2"

  cbt -project "$PROJECT" -instance "$INSTANCE" createtable "$table" 2>/dev/null || \
    echo "  [skip] $table already exists"

  for family in $(echo "$families" | tr ',' ' '); do
    cbt -project "$PROJECT" -instance "$INSTANCE" createfamily "$table" "$family" 2>/dev/null || true
    echo "    + family: $family"
  done
  echo "  [ok] $table"
}

echo ""
echo "=== Creating tables in instance: $INSTANCE ==="
# The emulator accepts any instance name — no createinstance needed.
create_table "users"         "profile,settings,metadata"
create_table "sessions"      "data,ttl"
create_table "messages"      "content,meta"
create_table "notifications" "data,status"

echo ""
echo "=== Done. Tables in $INSTANCE ==="
cbt -project "$PROJECT" -instance "$INSTANCE" ls
