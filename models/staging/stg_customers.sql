with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        customer_id,
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        lower(trim(email)) as email,
        phone,
        address_line1,
        city,
        state,
        postal_code,
        country,
        upper(loyalty_tier) as loyalty_tier,
        cast(signup_date as date) as signup_date,
        cast(updated_at as timestamp_ntz) as updated_at
    from source
)

select * from renamed
