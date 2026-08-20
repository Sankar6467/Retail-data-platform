-- Joins order items to their parent order and computes derived line economics
-- (gross margin) once, so both FCT_SALES and any future mart can reuse it.
with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

joined as (
    select
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        o.customer_id,
        o.store_id,
        o.order_date,
        o.order_status,
        o.payment_method,
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        oi.line_total,
        p.unit_cost,
        (oi.line_total - (p.unit_cost * oi.quantity)) as gross_margin_amount,
        {{ safe_divide(
            'oi.line_total - (p.unit_cost * oi.quantity)',
            'oi.line_total'
        ) }} as gross_margin_pct
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
    left join products p on oi.product_id = p.product_id
)

select * from joined
