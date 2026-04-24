#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    SELECT 'CREATE DATABASE smarttrade_authentication_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_authentication_service')\gexec
    SELECT 'CREATE DATABASE smarttrade_broker_adapter_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_broker_adapter_service')\gexec
    SELECT 'CREATE DATABASE smarttrade_market_data_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_market_data_service')\gexec
    SELECT 'CREATE DATABASE smarttrade_paper_broker_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_paper_broker_service')\gexec
    SELECT 'CREATE DATABASE smarttrade_strategy_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_strategy_service')\gexec
    SELECT 'CREATE DATABASE smarttrade_journal_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_journal_service')\gexec
    SELECT 'CREATE DATABASE smarttrade_portfolio_service' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'smarttrade_portfolio_service')\gexec
EOSQL
