#!/bin/bash
# Creates the replication user and publication Hevo needs for Logical Replication.
# The user name and password come from container environment variables, which
# are supplied by an env file kept outside the repo.
set -euo pipefail

psql -v ON_ERROR_STOP=1 -v db_name="$POSTGRES_DB" -v hevo_user="$HEVO_DB_USER" -v hevo_pass="$HEVO_DB_PASSWORD" \
     --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
CREATE ROLE :"hevo_user" WITH LOGIN REPLICATION PASSWORD :'hevo_pass';
GRANT CONNECT ON DATABASE :"db_name" TO :"hevo_user";
GRANT USAGE ON SCHEMA public TO :"hevo_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"hevo_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"hevo_user";

-- Hevo reads changes through a publication (pgoutput plugin).
CREATE PUBLICATION hevo_publication
    FOR TABLE public.raw_customers, public.raw_orders, public.raw_payments;

-- Hevo (Edge pipelines) asks for an existing replication slot name.
SELECT pg_create_logical_replication_slot('hevo_slot', 'pgoutput');
EOSQL

# Allow replication connections from outside the container (Hevo / tunnel).
echo "host replication all all scram-sha-256" >> "$PGDATA/pg_hba.conf"
