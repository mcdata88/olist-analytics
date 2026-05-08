-- stg_olist__customers.sql
-- PRD: Foundation for mart_customer_segmentation (#58)

with source as (
    select * from {{ source('raw_olist', 'customers') }}
),

renamed as (
    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        lower(customer_city)  as customer_city,
        upper(customer_state) as customer_state

    from source
)

select * from renamed