-- Singular test: total customer_lifetime_value must equal the total of all
-- payments that belong to an order, so no payment is lost or double-counted.
select
    customers_total,
    payments_total
from (
    select sum(customer_lifetime_value) as customers_total from {{ ref('customers') }}
) c
cross join (
    select sum(p.amount) as payments_total
    from {{ ref('stg_payments') }} p
    inner join {{ ref('stg_orders') }} o on p.order_id = o.order_id
) p
where customers_total != payments_total
