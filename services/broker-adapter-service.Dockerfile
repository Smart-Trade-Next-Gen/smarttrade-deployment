# ---------- Base builder ----------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS builder
WORKDIR /app/broker-adapter-service
# Create venv OUTSIDE bind-mounted folders
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"    
# Copy dependency files
COPY broker-adapter-service/pyproject.toml broker-adapter-service/uv.lock ./
COPY smarttrade-common/ /app/smarttrade-common/
COPY broker-adapter-service/src/ ./src
COPY broker-adapter-service/migrations/ ./migrations
COPY broker-adapter-service/alembic.ini .
COPY broker-adapter-service/rbac_policies.yaml ./rbac_policies.yaml


# Install deps into /opt/venv
RUN uv venv $VIRTUAL_ENV \
 && uv sync --frozen --no-dev

# ---------- Runtime (production) ----------
FROM python:3.12-slim AS runtime
WORKDIR /app/broker-adapter-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/broker-adapter-service/src ./src
COPY --from=builder /app/broker-adapter-service/migrations ./migrations
COPY --from=builder /app/broker-adapter-service/alembic.ini .
COPY --from=builder /app/broker-adapter-service/rbac_policies.yaml ./rbac_policies.yaml


EXPOSE 8000
CMD ["uvicorn", "broker_adapter_service.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ---------- Runtime (development) ----------
# Reuse uv image so we have uv available inside container
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS runtime-dev
WORKDIR /app/broker-adapter-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/broker-adapter-service ./
EXPOSE 8000
CMD ["sh", "-c", "uv sync && uv run uvicorn broker_adapter_service.main:app --host 0.0.0.0 --port 8000 --reload"]
