# ---------- Base builder ----------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS builder
WORKDIR /app/market-data-service
# Create venv OUTSIDE bind-mounted folders
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"    
# Copy dependency files
COPY market-data-service/pyproject.toml market-data-service/uv.lock ./
COPY smarttrade-common/ /app/smarttrade-common/
COPY market-data-service/src/ ./src
COPY market-data-service/migrations/ ./migrations
COPY market-data-service/alembic.ini .
COPY market-data-service/rbac_policies.yaml ./rbac_policies.yaml


# Install deps into /opt/venv
RUN uv venv $VIRTUAL_ENV \
 && uv sync --frozen --no-dev

# ---------- Runtime (production) ----------
FROM python:3.12-slim AS runtime
WORKDIR /app/market-data-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/market-data-service/src ./src
COPY --from=builder /app/market-data-service/migrations ./migrations
COPY --from=builder /app/market-data-service/alembic.ini .
COPY --from=builder /app/market-data-service/rbac_policies.yaml ./rbac_policies.yaml


EXPOSE 8000
CMD ["uvicorn", "market_data_service.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ---------- Runtime (development) ----------
# Reuse uv image so we have uv available inside container
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS runtime-dev
WORKDIR /app/market-data-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/market-data-service ./
EXPOSE 8000
CMD ["sh", "-c", "uv sync && uv run uvicorn market_data_service.main:app --host 0.0.0.0 --port 8000 --reload"]
