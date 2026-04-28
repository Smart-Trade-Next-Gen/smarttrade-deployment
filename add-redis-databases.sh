#!/bin/bash

# Script to add all Redis databases to RedisInsight
# Run this after RedisInsight is fully started

REDISINSIGHT_URL="http://localhost:8010"
REDIS_HOST="redis"
REDIS_PORT="6379"

echo "Adding Redis database connections to RedisInsight..."
echo "RedisInsight URL: $REDISINSIGHT_URL"

# Function to add a database
add_database() {
  local name=$1
  local db=$2

  echo ""
  echo "Adding: $name (DB $db)..."

  curl -s -X POST "$REDISINSIGHT_URL/api/v1/databases" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$name\",
      \"host\": \"$REDIS_HOST\",
      \"port\": $REDIS_PORT,
      \"db\": $db
    }" | jq . 2>/dev/null || echo "Added (or already exists)"
}

# Add all three databases
add_database "Event Bus (DB 0)" "0"
add_database "Rate Limit (DB 2)" "2"
add_database "Token Storage (DB 3)" "3"

echo ""
echo "✅ All Redis databases have been added to RedisInsight!"
echo "📍 Access RedisInsight at: $REDISINSIGHT_URL"
