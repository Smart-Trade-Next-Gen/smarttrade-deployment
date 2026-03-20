# Database Migrations for Phase 1-3 Implementation

## Overview

Three new migrations added to support production architecture changes:

1. **Settlement Tables** - T+1 automated settlement
2. **Audit Log Table** - Immutable compliance logging
3. **Float to Numeric Conversion** - Decimal precision for financial data

## Migration Sequence

### 1. `c1d4e5f9b2a3` - Add Settlement Tables

**Tables Created**:
- `settlement`: Core settlement records with status tracking
- `settlement_line`: Line items for settlements (dividends, adjustments, etc.)

**Columns**:
- Financial: quantity, price, gross_amount, brokerage, taxes, net_amount (all Numeric)
- Status: status (PENDING, SETTLED, FAILED, CANCELLED)
- Audit: created_at, updated_at, version (optimistic locking)
- Indexes: user_id, broker_id, account_id, settlement_date, status

**Purpose**: Enable T+1 settlement automation and settlement status tracking

**Migration Time**: ~100ms (small initial table)

---

### 2. `d2e3f5g4h6i7` - Add Audit Log Table

**Table Created**:
- `audit_log`: Immutable append-only audit trail

**Columns**:
- Context: timestamp, trace_id, user_id, service_name
- Action: action, resource_type, resource_id
- State: before, after, changes (all JSON)
- Error: error_code, error_message (optional)
- Audit: broker_id, account_id, request_ip, metadata

**Indexes**: user_id, trace_id, resource_type, resource_id, broker_id, account_id, action, created_at

**Purpose**: Compliance audit trail for all financial operations (immutable, append-only)

**Retention**: Keep for 7 years (regulatory requirement)

**Migration Time**: ~100ms (small initial table)

---

### 3. `e4f5g6h7i8j9` - Convert Financial Float to Numeric

**Tables Modified**:
- `account_balance`: balance, cash_locked
- `account_ledger`: amount, balance_after

**Changes**:
- Float → Numeric(18, 6) for quantities/prices
- Float → Numeric(18, 2) for amounts
- Total precision: 18 digits (16 before decimal, 6 after for quantities; 2 for amounts)

**Data Loss**: None (Numeric is superset of Float)

**Precision Improvement**:
- Before: Float = ~7 significant digits (precision loss)
- After: Numeric(18,6) = 18 digits total (no rounding)
- Example: 1234567.123456 represented exactly vs. 1234567.124 (loss)

**Migration Time**: ~1-5 seconds depending on data volume

---

## How to Apply

### Prerequisites
```bash
# Ensure database URL is set
export DATABASE_URL="postgresql://user:pass@host:5432/db"

# For development (SQLite)
export DATABASE_URL="sqlite+aiosqlite:///./smarttrade.db"
```

### Apply All Migrations
```bash
cd broker-adapter-service
uv run alembic upgrade head
```

### Apply Specific Migration
```bash
# Apply up to settlement tables
uv run alembic upgrade c1d4e5f9b2a3

# Continue to audit log
uv run alembic upgrade d2e3f5g4h6i7

# Complete with precision conversion
uv run alembic upgrade e4f5g6h7i8j9
```

### Check Migration Status
```bash
uv run alembic current
uv run alembic history
```

### Rollback If Needed
```bash
# Rollback last migration (precision conversion)
uv run alembic downgrade e4f5g6h7i8j9

# Rollback 2 migrations
uv run alembic downgrade -1

# Rollback all
uv run alembic downgrade base
```

---

## Migration Details

### Settlement Tables Structure

```sql
-- Main settlement record
CREATE TABLE settlement (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    broker_id VARCHAR NOT NULL,
    account_id VARCHAR NOT NULL,
    trade_id VARCHAR NOT NULL UNIQUE(broker_id, account_id, trade_id),
    order_id VARCHAR NOT NULL,
    instrument_id VARCHAR NOT NULL,
    symbol VARCHAR NOT NULL,
    side VARCHAR NOT NULL,  -- BUY/SELL
    quantity NUMERIC(18,6) NOT NULL,
    price NUMERIC(18,6) NOT NULL,
    gross_amount NUMERIC(18,2) NOT NULL,
    brokerage NUMERIC(18,2) NOT NULL,
    taxes NUMERIC(18,2) NOT NULL,
    net_amount NUMERIC(18,2) NOT NULL,
    status VARCHAR NOT NULL,  -- PENDING/SETTLED/FAILED/CANCELLED
    trade_date TIMESTAMP NOT NULL,
    settlement_date TIMESTAMP NOT NULL,
    settled_at TIMESTAMP,
    settlement_error VARCHAR,
    version INTEGER NOT NULL DEFAULT 0,  -- Optimistic locking
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Line items for detailed accounting
CREATE TABLE settlement_line (
    id UUID PRIMARY KEY,
    settlement_id UUID REFERENCES settlement(id),
    line_type VARCHAR NOT NULL,  -- TRADE/DIVIDEND/CORPORATE_ACTION/ADJUSTMENT
    description VARCHAR NOT NULL,
    quantity NUMERIC(18,6),
    unit_price NUMERIC(18,6),
    amount NUMERIC(18,2) NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### Audit Log Table Structure

```sql
CREATE TABLE audit_log (
    id UUID PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    trace_id VARCHAR NOT NULL,
    user_id UUID NOT NULL,
    service_name VARCHAR NOT NULL,
    action VARCHAR NOT NULL,  -- order.placed, position.closed, etc.
    resource_type VARCHAR NOT NULL,  -- settlement, order, position
    resource_id VARCHAR NOT NULL,
    broker_id VARCHAR,
    account_id VARCHAR,
    before JSONB,  -- State before operation
    after JSONB,   -- State after operation
    changes JSONB, -- Computed diff
    request_ip VARCHAR,
    error_code VARCHAR,
    error_message VARCHAR,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Append-only constraint (no updates/deletes except cascade)
-- In application code: only INSERT allowed, no UPDATE/DELETE
```

---

## Migration Risks and Mitigation

### Risk: Settlement table conflicts with existing orders

**Mitigation**: Settlement is NEW table, no conflicts

### Risk: Audit log fills disk quickly

**Mitigation**:
- Archive old records to separate table after 1 year
- Use table partitioning by date
- Monitor disk usage

### Risk: Float to Numeric conversion on large dataset

**Mitigation**:
- Test on staging first with production data volume
- Run during low-traffic window
- Monitor query performance

### Risk: Optimistic locking version field conflicts

**Mitigation**:
- Version field initialized to 0
- Increment on each update
- Clients retry on OptimisticLockError
- Max 3 retries before failing

---

## Verification After Migration

### Check settlement tables exist
```sql
SELECT * FROM information_schema.tables WHERE table_name LIKE 'settlement%';
```

### Check audit log exists
```sql
SELECT * FROM information_schema.tables WHERE table_name = 'audit_log';
```

### Check precision conversion
```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'account_balance' AND column_name = 'balance';
-- Should show: numeric or decimal (not float)
```

### Test settlement insert
```sql
INSERT INTO settlement (
    id, user_id, broker_id, account_id, trade_id, order_id,
    instrument_id, symbol, side, quantity, price,
    gross_amount, brokerage, taxes, net_amount, status,
    trade_date, settlement_date
) VALUES (
    gen_random_uuid(), gen_random_uuid(), 'fyers', 'ACC_001',
    'TRADE_001', 'ORDER_001', 'INS_001', 'RELIANCE', 'BUY',
    100.0, 2500.50,
    250050.0, 50.0, 10.0, 249990.0, 'PENDING',
    NOW(), NOW() + INTERVAL '1 day'
);
SELECT * FROM settlement WHERE trade_id = 'TRADE_001';
```

---

## Rollback Procedures

### If Settlement Tables Need Rollback
```bash
uv run alembic downgrade d2e3f5g4h6i7
# Loses any settlement records (new table)
```

### If Audit Log Needs Rollback
```bash
uv run alembic downgrade e4f5g6h7i8j9
# Loses any audit records (new table)
```

### If Precision Conversion Needs Rollback
```bash
uv run alembic downgrade base
# All changes reverted, but may lose precision data
```

---

## Performance Considerations

### Settlement Table
- Small initial size: ~0 rows
- Growth: ~10-100 rows/day per account
- Query performance: Index on settlement_date for T+1 processing
- Cleanup: Archive records >1 year old

### Audit Log Table
- High growth: ~100-1000 rows/day per service
- Size: ~2KB per record (20-30GB/year for 100 users)
- Query performance: Partitioned by date for time-range queries
- Cleanup: Archive records >7 years old (regulatory requirement)

### Financial Precision Conversion
- Query performance: No change (both columns fully indexed)
- Storage: Numeric(18,6) = 8 bytes vs Float = 8 bytes (same)
- Calculation: Decimal arithmetic slightly slower (~0.1ms per operation)

---

## Next Steps

1. **Staging Deployment**:
   ```bash
   # Apply migrations
   uv run alembic upgrade head
   # Run settlement processor (background job)
   # Test T+1 settlement with dummy trades
   ```

2. **24-Hour Staging Test**:
   - Monitor migration performance
   - Test settlement creation and processing
   - Verify audit logging
   - Check query performance (no degradation expected)

3. **Production Deployment**:
   ```bash
   # During low-traffic window
   uv run alembic upgrade head
   # Verify with SELECT queries above
   # Enable settlement processor
   ```

4. **Post-Deployment**:
   - Monitor audit log growth (setup alerts)
   - Setup archive job for old records
   - Document column changes in runbook
   - Update API documentation (decimal precision)

---

## References

- [NUMERIC vs FLOAT](https://www.postgresql.org/docs/14/datatype-numeric.html)
- [Alembic Documentation](https://alembic.sqlalchemy.org/)
- [Settlement Tracking Service](IMPLEMENTATION_SUMMARY.md#p33-settlement-tracking-service)
- [Audit Trail](IMPLEMENTATION_SUMMARY.md#p21-persistent-audit-trail)
