-- stg_olist__product_category_translations.sql
-- PRD: Foundation for dim_products (#94)

with source as (
    select * from {{ source('raw_olist', 'product_category_name_translation') }}
),

renamed as (
    select
        product_category_name           as product_category_name_pt,
        product_category_name_english   as product_category_name_en

    from source
)

select * from renamed
