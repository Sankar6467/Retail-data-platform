{{ config(materialized='table') }}

with stores as (
    select * from {{ ref('stg_stores') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['store_id']) }} as store_key,
    store_id,
    store_name,
    store_type,
    region,
    city,
    state,
    country,
    open_date
from stores
