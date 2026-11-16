#!/bin/bash
set -euo pipefail

echo "Waiting for config server replica set to elect a primary..."
until mongosh --host config_server/configSrv:27017 --quiet --eval 'rs.status().members.some(m => m.stateStr === "PRIMARY")' 2>/dev/null | grep -q true; do
  sleep 5
done

echo "Starting mongos..."
mongos --port 27017 --configdb config_server/configSrv:27017 --bind_ip_all &
MONGOS_PID=$!
trap 'kill "$MONGOS_PID" 2>/dev/null || true' EXIT

until mongosh --host 127.0.0.1:27017 --quiet --eval 'db.adminCommand({ping: 1}).ok' >/dev/null 2>&1; do
  kill -0 "$MONGOS_PID"
  sleep 2
done

mongosh --host 127.0.0.1:27017 --quiet --eval '
  for (const [name, host] of [["shard1", "shard1:27018"], ["shard2", "shard2:27019"]]) {
    const found = db.adminCommand({listShards: 1}).shards.some(s => s._id === name);
    if (!found) sh.addShard(`${name}/${host}`);
  }
  sh.enableSharding("somedb");
  const appDB = db.getSiblingDB("somedb");
  if (!appDB.getCollectionNames().includes("helloDoc")) appDB.createCollection("helloDoc");
  const configDB = db.getSiblingDB("config");
  if (!configDB.collections.findOne({_id: "somedb.helloDoc"})) {
    sh.shardCollection("somedb.helloDoc", {name: "hashed"});
  }
'

wait "$MONGOS_PID"
