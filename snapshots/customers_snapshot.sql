{% snapshot customers_snapshot %}

{{
    config(
        target_database='RETAIL_STAGING_DB',
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True,
    )
}}

select * from {{ ref('stg_customers') }}

{% endsnapshot %}
