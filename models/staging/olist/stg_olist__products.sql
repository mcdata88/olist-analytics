-- stg_olist__products.sql
-- PRD: Foundation for dim_products (#94)

with source as (
    select * from {{ source('raw_olist', 'products') }}
),

renamed as (
    select
        product_id,
        product_category_name,

        -- fix typos in original Kaggle column names ("lenght" → "length")
        product_name_lenght         as product_name_length,
        product_description_lenght  as product_description_length,

        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm

    from source
)

select * from renamed
