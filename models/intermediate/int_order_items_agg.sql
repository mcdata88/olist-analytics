-- int_order_items_agg.sql
-- Aggregates line items to one row per order.
-- Used by: mart_order_revenue (PRD #42), mart_customer_segmentation (PRD #58)

with order_items as (
    select * from {{ ref('stg_olist__order_items') }}
),

aggregated as (
    select
        order_id,

        count(distinct product_id)  as total_items,
        sum(item_price)             as total_item_revenue,
        sum(freight_value)          as total_freight

    from order_items
    group by 1
)

select * from aggregated