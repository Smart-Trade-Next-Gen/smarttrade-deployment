# ---------- Base builder ----------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS builder
WORKDIR /app/paper-broker-service
# Create venv OUTSIDE bind-mounted folders
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"    
# Copy dependency files
COPY paper-broker-service/pyproject.toml paper-broker-service/uv.lock ./
COPY smarttrade-common/ /app/smarttrade-common/
COPY paper-broker-service/src/ ./src
COPY paper-broker-service/migrations/ ./migrations
COPY paper-broker-service/alembic.ini .
COPY paper-broker-service/rbac_policies.yaml ./rbac_policies.yaml


# Install deps into /opt/venv
RUN uv venv $VIRTUAL_ENV \
 && uv sync --frozen --no-dev

# ---------- Runtime (production) ----------
FROM python:3.12-slim AS runtime
WORKDIR /app/paper-broker-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/paper-broker-service/src ./src
COPY --from=builder /app/paper-broker-service/migrations ./migrations
COPY --from=builder /app/paper-broker-service/alembic.ini .
COPY --from=builder /app/paper-broker-service/rbac_policies.yaml ./rbac_policies.yaml


EXPOSE 8000
CMD ["uvicorn", "paper_broker_service.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ---------- Runtime (development) ----------
# Reuse uv image so we have uv available inside container
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS runtime-dev
WORKDIR /app/paper-broker-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/paper-broker-service ./
EXPOSE 8000
CMD ["sh", "-c", "uv sync && uv run uvicorn paper_broker_service.main:app --host 0.0.0.0 --port 8000 --reload"]
