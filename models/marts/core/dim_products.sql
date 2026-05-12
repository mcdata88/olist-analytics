-- dim_products.sql
-- ============================================================
-- PRD: docs/prds/dim_products.md (Issue #94)
-- Grain: One row per product_id
-- Materialization: table
-- ============================================================

with products as (
    select * from {{ ref('stg_olist__products') }}
),

translations as (
    select * from {{ ref('stg_olist__product_category_translations') }}
),

final as (
    select
        p.product_id,
        p.product_category_name,
        coalesce(t.product_category_name_en, 'uncategorized')  as product_category_name_en,

        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        case
            when p.product_length_cm is not null
            and  p.product_height_cm is not null
            and  p.product_width_cm  is not null
            then p.product_length_cm * p.product_height_cm * p.product_width_cm
        end                                                     as product_volume_cm3,

        p.product_photos_qty,
        p.product_name_length,
        p.product_description_length

    from products p
    left join translations t
        on p.product_category_name = t.product_category_name_pt
)

select * from final
