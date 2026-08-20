-- Reconciliation: total line_total in fct_sales must match total line_total
-- in the raw order_items feed within a tiny rounding tolerance. Catches
-- silent transformation bugs (e.g. a bad join dropping/duplicating rows).
with raw_total as (
    select sum(cast(line_total as number(12,2))) as raw_revenue
    from {{ source('raw', 'order_items') }}
),

fact_total as (
    select sum(line_total) as fact_revenue
    from {{ ref('fct_sales') }}
)

select raw_revenue, fact_revenue
from raw_total, fact_total
where abs(raw_revenue - fact_revenue) > 0.01
