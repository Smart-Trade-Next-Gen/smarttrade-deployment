# SmartTrade Deployment

Infrastructure and deployment configuration for the SmartTrade trading
platform. Single source of truth: `docker-compose.yml`.

## Contents

- `docker-compose.yml` — Compose stack (Postgres, Redis, RedisInsight, all
  backend services).
- `.env.example` — Environment variable template (copy to `.env` and fill
  in secrets).
- `init-db.sh` — Creates per-service Postgres databases on first boot.
- `add-redis-databases.sh`, `redisinsight-init.sh`, `redisinsight-config.json`
  — RedisInsight pre-configuration helpers.
- `DOCKER_SETUP.md` — Compose setup walkthrough.
- `SECRETS_SETUP.md` — Secret generation / rotation.
- `REDISINSIGHT_SETUP.md` — RedisInsight UI setup.

## Quick start

```bash
cp .env.example .env
# Fill in JWT_SECRET_KEY, TOKEN_ENCRYPTION_KEY, FYERS_APP_ID, FYERS_APP_SECRET

docker compose up -d
```

## Services

| Service | Host port | Container port |
|---------|-----------|----------------|
| PostgreSQL | 5432 | 5432 |
| Redis | 6379 | 6379 |
| RedisInsight | 8010 | 5540 |
| Authentication Service | 8001 | 8000 |
| Paper Broker Service (PBS) | 8002 | 8000 |
| Market Data Service (MDS) | 8004 | 8000 |
| Broker Adapter Service (BAS) | 8005 | 8000 |
| Strategy Service | 8006 | 8000 |
| Journal Service | 8007 | 8000 |
| Portfolio Service | 8008 | 8000 |
| Notification Service | 8011 | 8000 |
| AMIS Core Service | 8000 | 8000 |
| AMIS Lab Service | 8016 | 8000 |
| Frontend (dev) | 5173 | — |

## Service start order

Postgres → Redis → Auth → MDS → PBS → BAS → Strategy → Journal → Portfolio
→ Notification → AMIS Core → AMIS Lab → Frontend.

Compose `depends_on` + healthchecks enforce the ordering.

## Per-service databases

Each backend service owns its own database. `init-db.sh` creates them on
first Postgres boot:

- `smarttrade_authentication_service`
- `smarttrade_paper_broker_service`
- `smarttrade_market_data_service`
- `smarttrade_broker_adapter_service`
- `smarttrade_strategy_service`
- `smarttrade_journal_service`
- `smarttrade_portfolio_service`
- `smarttrade_notification_service`

Migrations are applied by each service during its own lifespan startup
(Alembic). No central migration step here.

## Redis

A single Redis instance backs the event bus (Streams + KV) and any
service-level rate limiting / token storage. Services use one `REDIS_URL`
pointing at the shared instance (consumer-group / database separation is
enforced in code, not by URL).

RedisInsight at <http://localhost:8010> for inspecting streams and keys —
see `REDISINSIGHT_SETUP.md`.

## Secrets

See `SECRETS_SETUP.md` for generating `JWT_SECRET_KEY` and
`TOKEN_ENCRYPTION_KEY`. Don't commit real values; `.env` is gitignored.
