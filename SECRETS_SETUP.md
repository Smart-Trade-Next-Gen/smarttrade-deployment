# Secrets Management Setup

This guide explains how to set up secrets and environment variables for SmartTrade development and production.

## Local Development

### 1. Copy the Local Environment File

```bash
cp .env.local .env
```

The `.env.local` file contains safe dummy values suitable for local development with mock services.

### 2. Load Environment Variables

Docker Compose will automatically read the `.env` file in the project root. No additional setup required.

### 3. Verify Setup

```bash
docker-compose up
```

The services should start without missing environment variable errors.

## Environment Variables Reference

| Variable | Purpose | Example | Required |
|----------|---------|---------|----------|
| `JWT_SECRET_KEY` | JWT signing key (min 32 chars) | `base64-encoded-32-char-key` | Yes |
| `TOKEN_ENCRYPTION_KEY` | Token encryption key (base64) | `base64-encoded-key=` | Yes |
| `FYERS_APP_ID` | Fyers broker app ID | `PVH3PJ8L0D-100` | Yes |
| `FYERS_APP_SECRET` | Fyers broker app secret | `FM7DZKQPZE` | Yes |
| `POSTGRES_PASSWORD` | Database password | `postgres` (dev only) | Yes |
| `LOG_LEVEL` | Logging level | `INFO`, `DEBUG`, `WARNING` | No (defaults to INFO) |
| `ENV` | Environment name | `local`, `dev`, `staging`, `prod` | No (defaults to local) |
| `EVENT_BUS` | Event bus type | `redis`, `kafka` | No (defaults to redis) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | JWT expiry in minutes | `1440` (24 hours) | No |

## Production Setup

### 1. Generate Secure Keys

```bash
# Generate JWT Secret (32+ characters)
openssl rand -base64 32

# Generate Token Encryption Key (base64)
openssl rand -base64 32
```

### 2. Set Environment Variables

Use your infrastructure's secret management system:
- **AWS**: AWS Secrets Manager or Parameter Store
- **Kubernetes**: Kubernetes Secrets
- **Docker**: Docker Secrets (swarm mode)
- **Cloud Run/Functions**: Cloud Secret Manager

Example for Kubernetes:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: smarttrade-secrets
type: Opaque
stringData:
  JWT_SECRET_KEY: "your-generated-key-here"
  TOKEN_ENCRYPTION_KEY: "your-generated-key-here"
  FYERS_APP_ID: "your-fyers-id"
  FYERS_APP_SECRET: "your-fyers-secret"
  POSTGRES_PASSWORD: "strong-password"
```

### 3. Pass to Services

Docker Compose:
```bash
export JWT_SECRET_KEY="your-key-here"
export TOKEN_ENCRYPTION_KEY="your-key-here"
# ... other variables
docker-compose up
```

### 4. Rotate Secrets Regularly

- JWT/Token keys: Quarterly or after suspected compromise
- Broker credentials: Per broker's recommendations (usually annually)
- Database password: With database updates

## Security Best Practices

1. **Never commit `.env` files** - Use `.env.example` and `.env.local` only
2. **Use strong keys** - Minimum 32 characters for JWT and token encryption keys
3. **Rotate regularly** - Especially for high-risk secrets like API keys
4. **Audit access** - Log all access to secret management systems
5. **Use dedicated secrets manager** - Not environment variables for production
6. **Encrypt in transit** - Use TLS/HTTPS for all service communication
7. **Limit scope** - Only give services the secrets they need

## Environment Variable Files

- `.env.example` - Template showing all required variables (committed to git)
- `.env.local` - Local development values with safe dummy keys (committed to git)
- `.env` - Actual local secrets (gitignored, never committed)
- `.env.*.local` - Machine-specific overrides (gitignored)

## Troubleshooting

### Missing Environment Variable Error

If you see: `Error: Missing required environment variable: JWT_SECRET_KEY`

1. Check that `.env` file exists: `ls -la .env`
2. Verify variable is set: `grep JWT_SECRET_KEY .env`
3. Reload environment: `docker-compose down && docker-compose up`

### Services Can't Connect

If services can't connect to each other, verify:
- `BROKER_ADAPTER_SERVICE_URL` is set correctly
- `EVENT_BUS_URL` points to valid Redis instance
- `DATABASE_URL` format is correct for each service

### Secrets Exposed

If secrets are accidentally committed:

1. Remove from history:
   ```bash
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch .env' \
     --prune-empty --tag-name-filter cat -- --all
   ```

2. Rotate all exposed secrets immediately

3. Force push to repository:
   ```bash
   git push --force --all
   ```

4. Notify team and infrastructure team
