#!/bin/sh

# Wait for RedisInsight to be ready
echo "Waiting for RedisInsight to be ready..."
for i in $(seq 1 30); do
  if wget -q -O- http://localhost:5540/health 2>/dev/null; then
    echo "RedisInsight is ready!"
    break
  fi
  echo "Attempt $i/30: Waiting for RedisInsight..."
  sleep 2
done

# Give it a bit more time to fully initialize
sleep 3

# Function to add a Redis database connection
add_redis_db() {
  local name=$1
  local host=$2
  local port=$3
  local db=$4

  echo "Adding Redis database: $name (DB $db)..."

  wget -q -O- --post-data="{\"name\":\"$name\",\"host\":\"$host\",\"port\":$port,\"db\":$db}" \
    --header="Content-Type: application/json" \
    http://localhost:5540/api/v1/databases 2>/dev/null || true
}

# Add all three database connections
add_redis_db "Event Bus (DB 0)" "redis" "6379" "0"

echo "RedisInsight initialization complete!"
