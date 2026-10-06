# Hevo exercise: PostgreSQL → Hevo (Logical Replication) → Snowflake → dbt

Pipeline: three CSV files are loaded into a self-hosted, Docker-based PostgreSQL
database. A Hevo pipeline in **Logical Replication** mode replicates them to
Snowflake, and a dbt project builds a materialized `customers` table on top of
the replicated tables.

```
CSV (data/) → PostgreSQL (Docker) → Hevo (Logical Replication) → Snowflake → dbt `customers`
```

## No secrets in this repo

No server URLs, credentials, database names or keys are hardcoded or stored in
any file in this project. Everything is read from files **outside** the repo
or from environment variables:

| What | Where it lives |
|---|---|
| PostgreSQL / Hevo DB user settings | env file outside the repo (default `~/.config/hevo-exercise/postgres.env`) |
| Snowflake connection for dbt | `~/.dbt/profiles.yml`, which reads `SNOWFLAKE_*` environment variables |
| Source database/schema for dbt | `DBT_SOURCE_DATABASE`, `DBT_SOURCE_SCHEMA` environment variables |
| Hevo pipeline / Snowflake destination | entered in the Hevo UI |

Env file format (create it yourself, `chmod 600`, keep it out of git):

```
POSTGRES_USER=<admin user>
POSTGRES_PASSWORD=<strong password>
POSTGRES_DB=<database name>
POSTGRES_PORT=<port, e.g. 5432>
HEVO_DB_USER=<replication user for Hevo>
HEVO_DB_PASSWORD=<strong password>
```

## Prerequisites

Docker, Python 3.9–3.13 (for dbt), a Snowflake trial account, a Hevo trial
account (started from Snowflake Partner Connect), and a way for Hevo's cloud to
reach your database (cloud VM with an open port, SSH tunnel, or ngrok).

## 1. Start PostgreSQL (logical replication enabled)

```bash
docker compose --env-file ~/.config/hevo-exercise/postgres.env -f docker/docker-compose.yml up -d
```

The container starts with `wal_level=logical`, `max_replication_slots=10`,
`max_wal_senders=10`, `wal_sender_timeout=0` (Hevo's requirements). On first
start, `docker/init/` creates the three tables (with primary keys), a
replication user for Hevo, read grants, a `hevo_publication` publication for the
three tables, a `hevo_slot` logical replication slot, and a `pg_hba.conf` replication rule.

## 2. Load the CSV files

```bash
./scripts/load_csv.sh            # or: ./scripts/load_csv.sh /path/to/postgres.env
```

Expected row counts: `raw_customers` 100, `raw_orders` 99, `raw_payments` 113.

## 3. Create the Hevo pipeline (Hevo UI)

1. Create a Snowflake trial account, then open Hevo from **Snowflake Partner Connect**.
2. Make the database reachable from Hevo (whitelist Hevo's IPs for your region,
   or use an SSH tunnel / ngrok TCP tunnel to the PostgreSQL port).
3. **Pipelines → Create Pipeline → PostgreSQL → Snowflake**, then:
   - **Pipeline Mode: Logical Replication**
   - Host/port/database from your env file, user = the Hevo replication user,
     publication key `hevo_publication`, replication slot `hevo_slot`
   - Enable *Load Historical Data*; select `raw_customers`, `raw_orders`, `raw_payments`
4. Note the **Pipeline ID** and your **Team ID** for the submission email.

## 4. Build and test the dbt model

```bash
python3.13 -m venv .venv && source .venv/bin/activate
pip install dbt-snowflake
```

`~/.dbt/profiles.yml` (outside the repo):

```yaml
hevo_exercise:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('SNOWFLAKE_ROLE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
      schema: "{{ env_var('SNOWFLAKE_SCHEMA') }}"
      threads: 4
```

(Snowflake is moving away from password logins; you can swap `password` for
`private_key_path` / `private_key_passphrase` using key-pair authentication.)

Export the variables, then run:

```bash
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=... SNOWFLAKE_PASSWORD=...
export SNOWFLAKE_ROLE=... SNOWFLAKE_WAREHOUSE=... SNOWFLAKE_DATABASE=... SNOWFLAKE_SCHEMA=...
export DBT_SOURCE_DATABASE=...   # database Hevo loaded into
export DBT_SOURCE_SCHEMA=...     # schema Hevo loaded into

dbt build        # runs the models and all tests
```

## The `customers` model

| Column | Logic |
|---|---|
| `customer_id` | customers.id |
| `first_name`, `last_name` | customers |
| `first_order` | min(order_date) |
| `most_recent_order` | max(order_date) |
| `number_of_orders` | count of orders |
| `customer_lifetime_value` | sum of all payments made by the customer (payments → orders → customer) |

Customers without orders are kept (left joins), with null dates and values.
Amounts are summed as stored; they appear to be in cents.

## Tests

- `unique` / `not_null` on all keys (sources, staging and `customers`)
- `relationships`: orders → customers, payments → orders
- `accepted_values` for order `status` and `payment_method`
- Singular test `tests/assert_lifetime_value_matches_payments.sql`: total lifetime
  value must equal total payments attached to orders.

## Notes

- Hevo creates a replication slot; unconsumed WAL can grow if the pipeline is
  paused for long. Monitor disk usage on the PostgreSQL host.
- Free ngrok tunnels change host/port on restart, which breaks the pipeline
  until the host is updated in Hevo.
