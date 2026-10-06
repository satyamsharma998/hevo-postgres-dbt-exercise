select
    id as customer_id,
    first_name,
    last_name
from {{ source('hevo_raw', 'raw_customers') }}
