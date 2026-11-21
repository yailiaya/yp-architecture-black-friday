#!/bin/bash
set -euo pipefail

mongod --shardsvr --replSet shard1 --port 27018 --bind_ip_all &
MONGO_PID=$!

cleanup() {
  kill "$MONGO_PID" 2>/dev/null || true
}
trap cleanup EXIT

until mongosh --host 127.0.0.1:27018 --quiet --eval 'db.adminCommand({ping: 1}).ok' >/dev/null 2>&1; do
  kill -0 "$MONGO_PID"
  sleep 2
done

mongosh --host 127.0.0.1:27018 --quiet --eval '
  try { rs.status() } catch (e) {
    if (e.codeName === "NotYetInitialized") {
      rs.initiate({_id: "shard1", members: [{_id: 0, host: "shard1:27018"}]});
    } else { throw e; }
  }
'

wait "$MONGO_PID"
