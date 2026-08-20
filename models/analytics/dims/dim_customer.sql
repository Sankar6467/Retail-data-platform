{{ config(materialized='table') }}

-- Sources the dbt snapshot (Type-2 SCD) rather than stg_customers directly,
-- so history of loyalty_tier/address changes is preserved.
with snap as (
    select * from {{ ref('customers_snapshot') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_valid_from']) }} as customer_key,
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    city,
    state,
    country,
    loyalty_tier,
    signup_date,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    (dbt_valid_to is null) as is_current
from snap
