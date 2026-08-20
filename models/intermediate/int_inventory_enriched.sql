-- Adds derived availability + reorder flag once, shared by the inventory fact
-- and any future replenishment/alerting model.
with inventory as (
    select * from {{ ref('stg_inventory_snapshots') }}
)

select
    snapshot_date,
    store_id,
    product_id,
    quantity_on_hand,
    quantity_reserved,
    (quantity_on_hand - quantity_reserved) as quantity_available,
    reorder_point,
    (quantity_on_hand - quantity_reserved) < reorder_point as is_below_reorder_point
from inventory
