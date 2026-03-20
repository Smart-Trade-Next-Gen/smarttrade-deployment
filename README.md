# SmartTrade Deployment

Infrastructure and deployment configuration for the SmartTrade trading platform.

## Contents

- `docker-compose.yml` — Production/standard Docker Compose setup
- `docker-compose.local.yml` — Local development (uses host DB/Redis)
- `.env.example` — Environment variable template (copy to `.env` and fill in secrets)
- `MIGRATIONS.md` — Database migration guide
- `SECRETS_SETUP.md` — Secret key generation instructions
- `services/` — Dockerfiles for each service

## Quick Start

```bash
cp .env.example .env
# Fill in secrets in .env

docker-compose up
```

## Services

| Service | Port |
|---------|------|
| Authentication | 8001 |
| Mock Service | 8002 |
| Market Data | 8004 |
| Broker Adapter | 8005 |
| Frontend | 5173 |

## Service Start Order

PostgreSQL → Redis → Auth → MDS → BAS → Mock → Frontend
