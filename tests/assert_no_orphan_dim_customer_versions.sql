-- Exactly one is_current=true row per customer_id in dim_customer.
-- Guards the Type-2 SCD logic - if a bad snapshot run leaves 0 or 2+
-- "current" rows for a customer, this test fails.
select customer_id, count(*) as current_row_count
from {{ ref('dim_customer') }}
where is_current
group by customer_id
having count(*) <> 1
