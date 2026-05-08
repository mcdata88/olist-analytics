-- stg_olist__order_items.sql
-- PRD: Foundation for mart_order_revenue (#42)

with source as (
    select * from {{ source('raw_olist', 'order_items') }}
),

renamed as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,

        shipping_limit_date::timestamp_ntz  as shipping_limit_at,
        price::number(12, 2)                as item_price,
        freight_value::number(12, 2)        as freight_value

    from source
)

select * from renamed