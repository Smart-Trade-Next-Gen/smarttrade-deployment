# RedisInsight Setup Guide

## Quick Start

RedisInsight is now available at: **http://localhost:8010**

## Adding Redis Database Connections

RedisInsight stores connections in its local database. Follow these steps to add all three Redis databases:

### Method 1: UI Setup (Recommended - 30 seconds)

1. **Open RedisInsight**: Visit http://localhost:8010
2. **Click "Add Redis Database"** (or the + button)
3. **Connection Type**: Select "Manually"
4. **Fill in the form for each database**:

#### Database 1: Event Bus (DB 0)
- **Alias**: `Event Bus (DB 0)`
- **Host**: `redis`
- **Port**: `6379`
- **Database**: `0`
- **Description**: Market quotes, strategy decisions, order events
- Click **"Add Redis"**

#### Database 2: Rate Limit (DB 2)
- **Alias**: `Rate Limit (DB 2)`
- **Host**: `redis`
- **Port**: `6379`
- **Database**: `2`
- **Description**: Broker rate limiting tracking
- Click **"Add Redis"**

#### Database 3: Token Storage (DB 3)
- **Alias**: `Token Storage (DB 3)`
- **Host**: `redis`
- **Port**: `6379`
- **Database**: `3`
- **Description**: OAuth/session tokens
- Click **"Add Redis"**

### Method 2: Command Line (One-liner)

If you prefer to set this up via command line (requires `jq`):

```bash
#!/bin/bash
# You can add this to ~/.bashrc or run manually

# Add Event Bus (DB 0)
curl -X POST http://localhost:8010/api/v1/databases \
  -H "Content-Type: application/json" \
  -d '{"name":"Event Bus (DB 0)","host":"redis","port":6379,"db":0}'

# Add Rate Limit (DB 2)
curl -X POST http://localhost:8010/api/v1/databases \
  -H "Content-Type: application/json" \
  -d '{"name":"Rate Limit (DB 2)","host":"redis","port":6379,"db":2}'

# Add Token Storage (DB 3)
curl -X POST http://localhost:8010/api/v1/databases \
  -H "Content-Type: application/json" \
  -d '{"name":"Token Storage (DB 3)","host":"redis","port":6379,"db":3}'
```

## What You Can Monitor

### Event Bus (DB 0) - Market Data & Events
- **Streams**: 
  - `market.quote.v1` — Live market quotes
  - `market.instrument.v1` — Instrument metadata updates
  - `strategy.decision.v1` — Trading signals
  - `order.*` — Order events
  - `execution.*` — Execution flow events
  - `instrument.sync.*` — Instrument sync events
- **Consumer Groups**: 
  - Each service has its own consumer group
  - Monitor lag to detect processing delays
- **Keys**: Various transient KV pairs

### Rate Limit (DB 2) - Broker Rate Limiting
- **Keys**: Rate limit counters per broker/endpoint
- **Format**: `BROKER:ENDPOINT:TIMESTAMP` patterns
- **Monitor**: Current usage vs limits

### Token Storage (DB 3) - Authentication
- **Keys**: OAuth tokens, session tokens
- **TTL**: Most have expiration times
- **Security**: Encrypted sensitive data

## RedisInsight Features

Once you add a database, you can:

- **View Streams**: See all messages, consumer group lag
- **Monitor Memory**: Key-by-key memory usage analysis
- **Run Commands**: Execute Redis commands directly
- **Profiler**: Track command patterns and hot keys
- **Slowlog**: Monitor slow commands
- **Memory Analysis**: Identify large keys

## Helpful Commands in RedisInsight Console

```bash
# Stream information
XINFO STREAM market.quote.v1
XINFO GROUPS market.quote.v1
XPENDING market.quote.v1 group_name

# Consumer group details
XINFO CONSUMERS market.quote.v1 group_name

# Stream length
XLEN market.quote.v1

# View recent messages
XRANGE market.quote.v1 - +
XREAD STREAMS market.quote.v1 0-0

# Check key patterns
KEYS *
SCAN 0 MATCH "order:*"

# Memory analysis
MEMORY USAGE key_name
MEMORY STATS
```

## Troubleshooting

**Can't connect to Redis?**
- Make sure `redis` service is running: `docker-compose ps | grep redis`
- Check Redis is healthy: `docker-compose logs redis | tail`
- Try connecting to `localhost:6379` with `redis-cli`

**Connection says "Cannot read property '...' of undefined"?**
- Refresh the page (F5)
- Clear browser cache if persists
- Restart RedisInsight: `docker-compose restart redis-insight`

**No streams showing?**
- Events may not have been published yet
- Run your application to generate events
- Check consumer groups exist: Run `XINFO GROUPS stream_name` command
