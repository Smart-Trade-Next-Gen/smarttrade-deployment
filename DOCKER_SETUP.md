# Docker Compose Setup — SmartTrade

Single `docker-compose.yml` brings up the full backend stack for local
development and testing.

## Stack

Infrastructure:
- **PostgreSQL** (5432) — shared database server (per-service databases)
- **Redis** (6379) — event bus, KV snapshots, rate limiting, token storage
- **RedisInsight** (host 8010 → container 5540) — Redis UI

Services (host : container port `8000` in every container):
- Authentication Service (8001)
- Paper Broker Service / PBS (8002)
- Market Data Service / MDS (8004)
- Broker Adapter Service / BAS (8005)
- Strategy Service (8006)
- Journal Service (8007)
- Portfolio Service (8008)
- Notification Service (8011)

## Quick start

```bash
cd smarttrade-deployment
cp .env.example .env             # fill in JWT/TOKEN/FYERS secrets

docker compose up -d
docker compose ps                # check health
docker compose logs -f           # follow logs
```

To stop:

```bash
docker compose down              # keep volumes
docker compose down -v           # wipe data (irreversible)
```

## Configuration

All services read variables from the project-root `.env`. Key vars
(see `.env.example` for the full template):

```ini
# Auth
JWT_SECRET_KEY=<32-byte-key>
TOKEN_ENCRYPTION_KEY=<32-byte-key>

# Broker
FYERS_APP_ID=<app-id>
FYERS_APP_SECRET=<app-secret>

# Infra
REDIS_URL=redis://redis:6379/0
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Env
LOG_LEVEL=INFO
ENV=local
```

## Databases

Each service owns its own Postgres database. `init-db.sh` creates them on
first boot:

- `smarttrade_authentication_service`
- `smarttrade_paper_broker_service`
- `smarttrade_market_data_service`
- `smarttrade_broker_adapter_service`
- `smarttrade_strategy_service`
- `smarttrade_journal_service`
- `smarttrade_portfolio_service`
- `smarttrade_notification_service`

Service URL pattern (compose-internal DNS):

```
postgresql+asyncpg://postgres:postgres@postgres:5432/smarttrade_<service>
```

Alembic migrations run automatically during each service's lifespan
startup. To run manually:

```bash
docker compose exec broker-adapter-service uv run alembic upgrade head
```

## Service start order

`depends_on` + healthchecks in `docker-compose.yml` enforce:

1. **postgres**, **redis** (infrastructure)
2. **auth-service**
3. **market-data-service**
4. **paper-broker-service**
5. **broker-adapter-service**
6. **strategy-service**, **journal-service**, **portfolio-service**,
   **notification-service**
7. **amis-core-service**
8. **amis-lab-service** (depends on amis-core-service)

## Health checks

All services expose `/` (liveness) and `/ready` (readiness) probes. Compose
healthchecks hit `/ready` over the container-internal port 8000.

```bash
docker compose ps
```

## Troubleshooting

**Postgres connection refused**
```bash
docker compose logs postgres
docker compose exec postgres pg_isready -U postgres
```

**Port conflict on host**
```bash
lsof -i :8005    # find process; either stop it or change the host port in compose
```

**Migrations didn't apply**
- Check the failing service's logs — Alembic prints to stdout during startup.
- Run manually with `docker compose exec <service> uv run alembic upgrade head`.

## See also

- `README.md` — service / port map and Redis layout.
- `SECRETS_SETUP.md` — generating JWT / token-encryption keys.
- `REDISINSIGHT_SETUP.md` — Redis UI walkthrough.
- `init-db.sh` — per-service database creation.
