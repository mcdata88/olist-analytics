-- stg_olist__order_payments.sql
-- PRD: Foundation for mart_order_revenue (#42)

with source as (
    select * from {{ source('raw_olist', 'order_payments') }}
),

renamed as (
    select
        order_id,
        payment_sequential,
        lower(payment_type) as payment_type,
        payment_installments,
        payment_value::number(12, 2) as payment_value

    from source
)

select * from renamed