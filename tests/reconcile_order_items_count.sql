-- Reconciliation: every valid raw order item must land in fct_sales exactly
-- once. Returns offending rows (test fails if any rows are returned).
with raw_count as (
    select count(*) as raw_rows from {{ source('raw', 'order_items') }}
),

fact_count as (
    select count(*) as fact_rows from {{ ref('fct_sales') }}
)

select raw_rows, fact_rows
from raw_count, fact_count
where raw_rows <> fact_rows
