# ---------- Base builder ----------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS builder

WORKDIR /app/authentication-service

# Create venv OUTSIDE bind-mounted folders
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Copy dependency files
COPY authentication-service/pyproject.toml authentication-service/uv.lock ./
COPY smarttrade-common/ /app/smarttrade-common/
COPY authentication-service/src/ ./src
COPY authentication-service/migrations/ ./migrations
COPY authentication-service/alembic.ini .
COPY authentication-service/rbac_policies.yaml ./rbac_policies.yaml

# Install deps into /opt/venv
RUN uv venv $VIRTUAL_ENV \
 && uv sync --frozen --no-dev

# ---------- Runtime (production) ----------
FROM python:3.12-slim AS runtime

WORKDIR /app/authentication-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/authentication-service/src ./src
COPY --from=builder /app/authentication-service/migrations ./migrations
COPY --from=builder /app/authentication-service/alembic.ini .
COPY --from=builder /app/authentication-service/rbac_policies.yaml ./rbac_policies.yaml

EXPOSE 8000

CMD ["uvicorn", "authentication_service.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ---------- Runtime (development) ----------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS runtime-dev

WORKDIR /app/authentication-service

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/authentication-service ./

EXPOSE 8000

CMD ["sh", "-c", "uv sync && uv run uvicorn authentication_service.main:app --host 0.0.0.0 --port 8000 --reload"]