{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='order_item_id',
        on_schema_change='append_new_columns'
    )
}}

-- Grain: one row per order line item (order_item_id).
-- Incremental watermark is the order date itself (orders are immutable once
-- placed in this source system, so order_date is a safe high-water mark).
with enriched as (
    select * from {{ ref('int_order_items_enriched') }}
),

filtered as (
    select * from enriched
    {{ incremental_watermark_filter('order_date', ref('dim_date')) }}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_item_id']) }} as sales_key,
    f.order_item_id,
    f.order_id,
    {{ generate_date_key('f.order_date') }} as date_key,
    c.customer_key,
    p.product_key,
    s.store_key,
    f.order_status,
    f.payment_method,
    f.quantity,
    f.unit_price,
    f.discount_amount,
    f.line_total,
    f.unit_cost,
    f.gross_margin_amount,
    f.gross_margin_pct
from filtered f
left join {{ ref('dim_customer') }} c on f.customer_id = c.customer_id and c.is_current
left join {{ ref('dim_product') }}  p on f.product_id = p.product_id
left join {{ ref('dim_store') }}    s on f.store_id = s.store_id
