# ---------- Base builder ----------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS builder
WORKDIR /app/mock-service
# Create venv OUTSIDE bind-mounted folders
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"    
# Copy dependency files
COPY mock-service/pyproject.toml mock-service/uv.lock ./
COPY smarttrade-common/ /app/smarttrade-common/
COPY mock-service/src/ ./src
COPY mock-service/migrations/ ./migrations
COPY mock-service/alembic.ini .
COPY mock-service/rbac_policies.yaml ./rbac_policies.yaml


# Install deps into /opt/venv
RUN uv venv $VIRTUAL_ENV \
 && uv sync --frozen --no-dev

# ---------- Runtime (production) ----------
FROM python:3.12-slim AS runtime
WORKDIR /app/mock-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/mock-service/src ./src
COPY --from=builder /app/mock-service/migrations ./migrations
COPY --from=builder /app/mock-service/alembic.ini .
COPY --from=builder /app/mock-service/rbac_policies.yaml ./rbac_policies.yaml


EXPOSE 8000
CMD ["uvicorn", "mock_service.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ---------- Runtime (development) ----------
# Reuse uv image so we have uv available inside container
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS runtime-dev
WORKDIR /app/mock-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/mock-service ./
EXPOSE 8000
CMD ["sh", "-c", "uv sync && uv run uvicorn mock_service.main:app --host 0.0.0.0 --port 8000 --reload"]
