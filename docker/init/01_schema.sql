-- Source tables for the exercise. Primary keys are required so Hevo's
-- logical replication can track row changes.
CREATE TABLE IF NOT EXISTS public.raw_customers (
    id          integer PRIMARY KEY,
    first_name  varchar(255),
    last_name   varchar(255)
);

CREATE TABLE IF NOT EXISTS public.raw_orders (
    id          integer PRIMARY KEY,
    user_id     integer,
    order_date  date,
    status      varchar(50)
);

CREATE TABLE IF NOT EXISTS public.raw_payments (
    id              integer PRIMARY KEY,
    order_id        integer,
    payment_method  varchar(50),
    amount          integer
);
