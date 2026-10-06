#!/usr/bin/env bash
# Loads the three CSV files into the PostgreSQL container.
# Connection details are read from an env file OUTSIDE the repo; pass its path
# as the first argument or via HEVO_EXERCISE_ENV (default: ~/.config/hevo-exercise/postgres.env).
set -euo pipefail

ENV_FILE="${1:-${HEVO_EXERCISE_ENV:-$HOME/.config/hevo-exercise/postgres.env}}"
[ -f "$ENV_FILE" ] || { echo "Env file not found: $ENV_FILE" >&2; exit 1; }
set -a; . "$ENV_FILE"; set +a

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$ROOT/docker/docker-compose.yml")

load() {  # load <table> <csv>
  echo "Loading $2 -> $1"
  "${COMPOSE[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -c "TRUNCATE public.$1" \
    -c "\\copy public.$1 FROM STDIN WITH (FORMAT csv, HEADER true)" < "$ROOT/data/$2"
}

load raw_customers raw_customers.csv
load raw_orders    raw_orders.csv
load raw_payments  raw_payments.csv

"${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -c \
  "SELECT 'raw_customers', count(*) FROM public.raw_customers UNION ALL
   SELECT 'raw_orders', count(*) FROM public.raw_orders UNION ALL
   SELECT 'raw_payments', count(*) FROM public.raw_payments"
