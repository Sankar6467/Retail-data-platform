{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['date_key', 'store_key', 'product_key'],
        on_schema_change='append_new_columns'
    )
}}

-- Grain: one row per store/product/day snapshot.
with enriched as (
    select * from {{ ref('int_inventory_enriched') }}
    {{ incremental_watermark_filter('snapshot_date', ref('dim_date')) }}
)

select
    {{ dbt_utils.generate_surrogate_key(['e.snapshot_date', 'e.store_id', 'e.product_id']) }} as inventory_key,
    {{ generate_date_key('e.snapshot_date') }} as date_key,
    s.store_key,
    p.product_key,
    e.quantity_on_hand,
    e.quantity_reserved,
    e.quantity_available,
    e.reorder_point,
    e.is_below_reorder_point
from enriched e
left join {{ ref('dim_store') }}   s on e.store_id = s.store_id
left join {{ ref('dim_product') }} p on e.product_id = p.product_id
