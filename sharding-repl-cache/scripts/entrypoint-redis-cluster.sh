#!/bin/sh
set -eu

nodes="redis_1:6379 redis_2:6379 redis_3:6379 redis_4:6379 redis_5:6379 redis_6:6379"

wait_for_redis() {
  node="$1"
  host=${node%:*}
  port=${node##*:}
  attempt=0
  until redis-cli -h "$host" -p "$port" ping 2>/dev/null | grep -q '^PONG$'; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 60 ]; then
      echo "Timed out waiting for Redis at $node" >&2
      exit 1
    fi
    sleep 2
  done
}

cluster_value() {
  node="$1"
  field="$2"
  host=${node%:*}
  port=${node##*:}
  redis-cli -h "$host" -p "$port" cluster info 2>/dev/null \
    | sed -n "s/^${field}://p" | tr -d '\r'
}

echo "Waiting for Redis nodes..."
for node in $nodes; do
  wait_for_redis "$node"
done

state=$(cluster_value redis_1:6379 cluster_state)
if [ "$state" = "ok" ]; then
  echo "Redis Cluster is already healthy; no initialization needed."
  exit 0
fi

known_nodes=$(cluster_value redis_1:6379 cluster_known_nodes)
if [ "$known_nodes" != "1" ]; then
  echo "Redis nodes have existing cluster metadata, but the cluster is not healthy (state=${state:-unknown}, known_nodes=${known_nodes:-unknown}). Refusing to recreate it." >&2
  exit 1
fi

echo "Creating Redis Cluster with three primaries and three replicas..."
redis-cli --cluster create $nodes --cluster-replicas 1 --cluster-yes

echo "Waiting for all cluster slots to become available..."
attempt=0
until [ "$(cluster_value redis_1:6379 cluster_state)" = "ok" ] \
  && [ "$(cluster_value redis_1:6379 cluster_slots_ok)" = "16384" ]; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "Redis Cluster did not reach healthy state with all slots assigned." >&2
    redis-cli -h redis_1 -p 6379 cluster info >&2 || true
    exit 1
  fi
  sleep 2
done

echo "Redis Cluster is healthy with all 16384 slots assigned."
