-- stg_olist__sellers.sql
-- PRD: Foundation for mart_seller_performance (#72)

with source as (
    select * from {{ source('raw_olist', 'sellers') }}
),

renamed as (
    select
        seller_id,
        seller_zip_code_prefix,
        lower(seller_city)  as seller_city,
        upper(seller_state) as seller_state

    from source
)

select * from renamed
