{{ config(materialized='table') }}

with products as (
    select * from {{ ref('stg_products') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
    product_id,
    sku,
    product_name,
    category,
    subcategory,
    brand,
    unit_cost,
    unit_price,
    is_active
from products
