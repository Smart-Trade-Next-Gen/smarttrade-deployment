# Docker Compose Setup — SmartTrade

**Status:** ✅ Consolidated into single `docker-compose.yml`

## Overview

SmartTrade uses Docker Compose for local development and testing with 6 services:
- **PostgreSQL** (5432) — Shared database for all services
- **Redis** (6379) — Event bus and rate limiting
- **Authentication Service** (8001)
- **Market Data Service** (8004)
- **Paper Broker Service** (8002)
- **Broker Adapter Service** (8005)

## Quick Start

### Prerequisites
```bash
# Ensure Docker and Docker Compose are installed
docker --version
docker-compose --version
```

### Start All Services
```bash
cd smarttrade-deployment

# Configure environment (if not already done)
cp .env.example .env  # Update credentials if needed

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check health
docker-compose ps
```

### Stop All Services
```bash
docker-compose down

# Remove data volumes (⚠️ WARNING: loses all data)
docker-compose down -v
```

## Service Ports

| Service | Port | URL |
|---------|------|-----|
| Auth Service | 8001 | http://localhost:8001 |
| Paper Broker | 8002 | http://localhost:8002 |
| Market Data | 8004 | http://localhost:8004 |
| Broker Adapter | 8005 | http://localhost:8005 |
| PostgreSQL | 5432 | `postgres://postgres@localhost:5432` |
| Redis | 6379 | `redis://localhost:6379` |

## Configuration

### Environment Variables
All services use variables from `.env` file:

```env
# Authentication
JWT_SECRET_KEY=<32-byte-key>
TOKEN_ENCRYPTION_KEY=<32-byte-key>

# Broker Configuration
FYERS_APP_ID=<app-id>
FYERS_APP_SECRET=<app-secret>

# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Logging & Environment
LOG_LEVEL=INFO
ENV=local
```

See `.env.example` for complete reference.

### Database URLs

Services automatically connect to PostgreSQL using:
```
postgresql+asyncpg://postgres:postgres@postgres:5432/smarttrade_<service>
```

Each service has its own database:
- `smarttrade_authentication_service`
- `smarttrade_broker_adapter_service`
- `smarttrade_market_data_service`
- `smarttrade_paper_broker_service`

See `init-db.sh` for database initialization.

### Health Checks

All services have built-in health checks:
```bash
# Check service health
docker-compose ps

# Example output:
# postgres               "postgres"           Up 2m (healthy)
# redis                  "redis-server ..."   Up 2m (healthy)
# auth-service           "bash -c ..."        Up 2m
# broker-adapter-service "bash -c ..."        Up 2m (healthy)
```

## Troubleshooting

### PostgreSQL Connection Timeout
**Symptom:** Tests fail with "Could not connect to database on 15432"

**Solution:** Ensure `.env` has correct credentials and PostgreSQL is healthy:
```bash
docker-compose logs postgres
docker-compose exec postgres pg_isready -U postgres
```

### Service Startup Order
Services depend on each other in this order:
1. **postgres** & **redis** (infrastructure)
2. **auth-service** (requires postgres + redis)
3. **market-data-service** (requires postgres, redis, auth)
4. **paper-broker-service** (requires postgres, market-data)
5. **broker-adapter-service** (requires all above)

### Port Conflicts
If services fail to start with "port already in use":
```bash
# Find process using port
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis
lsof -i :8005  # Broker Adapter

# Kill and restart
docker-compose restart
```

### Database Migrations
Migrations run automatically on service startup. If needed manually:
```bash
docker-compose exec broker-adapter-service \
  uv run alembic upgrade head
```

## Testing

### Unit Tests (No Docker Required)
Unit tests use in-memory SQLite to avoid database timeouts:
```bash
cd broker-adapter-service
python -m pytest tests/unit -v
```

### Integration Tests (Docker Required)
Integration tests use PostgreSQL in Docker:
```bash
# Ensure docker-compose is running
docker-compose up -d

cd broker-adapter-service
python -m pytest tests/integration -v
```

### E2E Tests (Full Docker Stack Required)
End-to-end tests require all services:
```bash
docker-compose up -d
python -m pytest tests/e2e -v
```

## History

**Previously:** Two docker-compose files caused confusion
- `docker-compose.yml` (parametrized, production-style)
- `docker-compose.local.yml` (hardcoded, for local testing)

**Now:** Single consolidated `docker-compose.yml` with:
- ✅ Environment variable support
- ✅ Proper health checks
- ✅ PostgreSQL on standard port 5432
- ✅ Clear service documentation
- ✅ Works for local dev, testing, and production

## See Also

- `Dockerfile` — Individual service container definitions
- `.env.example` — Environment variable template
- `init-db.sh` — Database initialization script
- `MIGRATIONS.md` — Database migration guide
