with source as (
    select * from {{ source('raw', 'order_items') }}
),

renamed as (
    select
        order_item_id,
        order_id,
        product_id,
        cast(quantity as number(10,0)) as quantity,
        cast(unit_price as number(12,2)) as unit_price,
        cast(discount_amount as number(12,2)) as discount_amount,
        cast(line_total as number(12,2)) as line_total,
        cast(updated_at as timestamp_ntz) as updated_at
    from source
)

select * from renamed
