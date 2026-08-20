with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        store_id,
        cast(order_date as timestamp_ntz) as order_date,
        upper(order_status) as order_status,
        upper(payment_method) as payment_method,
        upper(currency) as currency,
        cast(updated_at as timestamp_ntz) as updated_at
    from source
)

select * from renamed
