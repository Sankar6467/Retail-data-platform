with source as (
    select * from {{ source('raw', 'stores') }}
),

renamed as (
    select
        store_id,
        trim(store_name) as store_name,
        upper(store_type) as store_type,
        region,
        city,
        state,
        country,
        cast(open_date as date) as open_date,
        cast(updated_at as timestamp_ntz) as updated_at
    from source
)

select * from renamed
