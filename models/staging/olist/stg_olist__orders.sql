-- stg_olist__orders.sql
-- PRD: Foundation for mart_order_revenue (#42) and mart_customer_segmentation (#58)
-- Cleans and renames raw order data. No joins, no business logic.

with source as (
    select * from {{ source('raw_olist', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,

        lower(order_status) as order_status,

        order_purchase_timestamp::timestamp_ntz  as ordered_at,
        order_approved_at::timestamp_ntz         as approved_at,
        order_delivered_carrier_date::timestamp_ntz   as shipped_at,
        order_delivered_customer_date::timestamp_ntz  as delivered_at,
        order_estimated_delivery_date::timestamp_ntz  as estimated_delivery_at

    from source
)

select * from renamed