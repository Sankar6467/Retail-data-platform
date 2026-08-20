with source as (
    select * from {{ source('raw', 'products') }}
),

renamed as (
    select
        product_id,
        sku,
        trim(product_name) as product_name,
        category,
        subcategory,
        brand,
        cast(unit_cost as number(12,2)) as unit_cost,
        cast(unit_price as number(12,2)) as unit_price,
        (upper(is_active) = 'TRUE') as is_active,
        cast(created_at as timestamp_ntz) as created_at,
        cast(updated_at as timestamp_ntz) as updated_at
    from source
)

select * from renamed
