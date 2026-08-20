with source as (
    select * from {{ source('raw', 'inventory_snapshots') }}
),

renamed as (
    select
        cast(snapshot_date as date) as snapshot_date,
        store_id,
        product_id,
        cast(quantity_on_hand as number(10,0)) as quantity_on_hand,
        cast(quantity_reserved as number(10,0)) as quantity_reserved,
        cast(reorder_point as number(10,0)) as reorder_point,
        cast(updated_at as timestamp_ntz) as updated_at
    from source
)

select * from renamed
