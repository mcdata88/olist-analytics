-- int_order_payments_agg.sql
-- Aggregates payments to one row per order.
-- Used by: mart_order_revenue (PRD #42)

with payments as (
    select * from {{ ref('stg_olist__order_payments') }}
),

aggregated as (
    select
        order_id,

        sum(payment_value)                             as total_payment,
        listagg(distinct payment_type, ', ')
            within group (order by payment_type)        as payment_types,
        max(payment_installments)                       as payment_installments_max

    from payments
    group by 1
)

select * from aggregated