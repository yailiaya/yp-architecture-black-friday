#!/bin/bash
set -e

# Start MongoDB in the background
mongod --configsvr --replSet config_server --port 27017 --bind_ip_all &

# Store the PID of MongoDB
MONGO_PID=$!

# Give MongoDB some time to start initially
sleep 5

# Function to check if MongoDB is ready locally
check_mongo_ready() {
  host=$1
  mongosh --host $host --eval "db.adminCommand('ping')" --quiet
  return $?
}

# Wait for all config servers to be ready
wait_for_mongo() {
  echo "Waiting for MongoDB instances to start..."

  # First wait for local instance
  until check_mongo_ready 127.0.0.1; do
    echo "Waiting for local MongoDB to start..."
    # Check if MongoDB process is still running
    if ! kill -0 $MONGO_PID 2>/dev/null; then
      echo "MongoDB process died unexpectedly. Check logs for errors."
      exit 1
    fi
    sleep 2
  done
  echo "Local MongoDB is ready!"

  echo "MongoDB instance is ready or timed out!"
}

# Initialize replica set
init_config_server() {
  echo "Initializing config server replica set..."

  # Adding more diagnostic output
  echo "Current MongoDB status:"
  mongosh --eval "db.adminCommand('ping')" || echo "Failed to ping MongoDB"

  # Try to initialize replica set
  mongosh --eval "
    rs.initiate({
      _id: \"config_server\",
      configsvr: true,
      version: 1,
      members: [
        { _id: 0, host : 'configSrv:27017' }
      ]
    })
  " || echo "Failed to initialize replica set"

  echo "Config server replica set initialization attempted."
}

# Main execution
echo "Starting MongoDB config server entrypoint script..."
wait_for_mongo
init_config_server

# Keep the script running to maintain the container
echo "Initialization completed, keeping container running with MongoDB process..."
wait $MONGO_PID
