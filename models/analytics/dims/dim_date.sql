{{ config(materialized='table') }}

-- Generated date spine, independent of any source file, covering the
-- assessment's operating window plus headroom for future data.
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2024-01-01')",
        end_date="to_date('2027-12-31')"
    ) }}
),

enriched as (
    select
        {{ generate_date_key('date_day') }} as date_key,
        date_day as calendar_date,
        dayname(date_day) as day_of_week,
        day(date_day) as day_of_month,
        month(date_day) as month_number,
        monthname(date_day) as month_name,
        quarter(date_day) as quarter,
        year(date_day) as year,
        (dayofweek(date_day) in (0, 6)) as is_weekend,
        'FY' || year(date_day) || '-Q' || quarter(date_day) as fiscal_period
    from spine
)

select * from enriched
