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
| AI Scoring Service | 8017 | 8000 |
| Frontend (dev) | 5173 | — |

## Service start order

Postgres → Redis → Auth → MDS → PBS → BAS → Strategy → Journal → Portfolio
→ Notification → AI Scoring → Frontend.

Compose `depends_on` + healthchecks enforce the ordering.

## Research agent (opt-in profile)

`research-agent` is not part of the default `docker compose up` — it
runs under the `agents` profile:

```bash
docker compose --profile agents up -d research-agent
```

It watches `events:scoring.research.awaiting_analysis` (Redis-only —
entries stay pending until the run settles, and a periodic pending
sweep covers retries/restarts; no HTTP polling) and completes each
parked research run by spawning
a headless Devin CLI session that runs the `company-investment-research`
skill — fetch package → web research → submit `ExternalAnalysisSubmission`
with an independent agent score. The LLM lives in this agent process,
never inside the services.

The agent source lives in the sibling `../research-agent` repo (this
service builds from that context). It's generic — use-cases are declared
in `handlers.json`, and each handler's dispatch prompt is fetched at
run time from ai-scoring (`/api/v1/research/agent-prompts/{name}`), so
prompts are editable from the frontend's Research page (AGENT PROMPT
card) or via PUT on that endpoint — no image rebuild needed.

Required in `.env`:

- `RESEARCH_AGENT_USERNAME` / `RESEARCH_AGENT_PASSWORD` — the account the
  agent authenticates as (needs `research.compute`; a dedicated account
  is recommended). `RESEARCH_AGENT_TOKEN` is a short-lived alternative.
- Devin auth: either `WINDSURF_API_KEY`, or a one-time
  `devin auth login` on the host (the mounted
  `~/.local/share/devin/credentials.toml` is shared into the container).
- `DEVIN_EXT_DIR` if the Devin CLI extension dir differs from the
  default mount path.

Tunables: `RESEARCH_AGENT_RECLAIM_SECONDS` (300), `RESEARCH_AGENT_BLOCK_MS`
(30000), `RESEARCH_AGENT_TIMEOUT_SECONDS` (3600),
`RESEARCH_AGENT_MAX_ATTEMPTS` (2), `RESEARCH_AGENT_MAX_PARALLEL` (4 —
concurrent Devin sessions; N workers multiply credit burn by ~N),
`DEVIN_PERMISSION_MODE` (dangerous — required for unattended runs),
`DEVIN_MODEL` (`swe-2-high` — reasoning effort is encoded in the model
name: `swe-2-low`/`swe-2-high`/`swe-2-max`).

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
- `smarttrade_ai_scoring_service`

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
