# PRD: Product Dimension (dim_products)

**Author:** Admin
**Status:** Implemented
**Created:** 2026-05-12
**Last Updated:** 2026-05-12
**Linked Issue:** #94

---

## 1. Business Context

`fct_order_items` carries `product_id` as a foreign key but there is currently
no dimension table to join it to. This means the business cannot answer
category-level questions from the data warehouse:

- Which product categories generate the most revenue?
- Do heavier or bulkier products correlate with longer delivery times or lower
  review scores?
- Which categories have the highest freight-to-price ratio?

`dim_products` is the v2 dimensional model that closes this gap. It joins the
raw product catalog to its English category translations, producing a clean,
BI-ready product dimension that any mart or analysis can join to via `product_id`.

## 2. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `raw_olist.products` | Product catalog with physical dimensions | 1 row per product | Static |
| `seeds/product_category_name_translation.csv` | Portuguese → English category name mapping | 1 row per category | Static (version-controlled seed) |

> **Implementation note:** The translation table is managed as a **dbt seed** rather
> than a raw Snowflake table. It is version-controlled in `seeds/` and loaded via
> `dbt build`. The staging model references it with `{{ ref('product_category_name_translation') }}`.

> **Note:** ~600 products have a null `product_category_name`. These are left-joined
> to the translation table and assigned `'uncategorized'` as the English category name.

## 3. New Staging Models Required

Two staging models must be built before `dim_products` can be built. This follows
the established staging-first workflow.

| Model | Source | Purpose |
|---|---|---|
| `stg_olist__products` | `raw_olist.products` | Clean and rename product catalog columns |
| `stg_olist__product_category_translations` | `seeds/product_category_name_translation` via `ref()` | Rename translation columns |

## 4. Output Specification

- **Model name:** `dim_products`
- **Grain:** One row per **product_id**
- **Primary key:** `product_id`
- **Materialization:** table (full refresh)
- **Schema:** `core`

### Key Columns

| Column | Type | Description | Business Logic |
|---|---|---|---|
| `product_id` | VARCHAR | Primary key | From `products` |
| `product_category_name` | VARCHAR | Raw Portuguese category name | From `products`; null if uncategorized |
| `product_category_name_en` | VARCHAR | English category name | From `product_category_name_translation`; `'uncategorized'` if no match |
| `product_weight_g` | INTEGER | Product weight in grams | From `products` |
| `product_length_cm` | INTEGER | Length in centimeters | From `products` |
| `product_height_cm` | INTEGER | Height in centimeters | From `products` |
| `product_width_cm` | INTEGER | Width in centimeters | From `products` |
| `product_volume_cm3` | INTEGER | Derived volume | `product_length_cm * product_height_cm * product_width_cm` |
| `product_photos_qty` | INTEGER | Number of product photos | From `products` |

## 5. Metric Definitions

`dim_products` is a dimension table — it carries attributes, not measures.
Metrics are computed by joining this table to `fct_order_items`:

| Metric | Formula | Join |
|---|---|---|
| GMV by category | `SUM(fct.item_price)` grouped by `dim.product_category_name_en` | `fct_order_items.product_id = dim_products.product_id` |
| Avg weight per order | `AVG(dim.product_weight_g)` | Same join |
| Freight-to-price ratio by category | `{{ safe_divide(SUM(fct.freight_value), SUM(fct.item_price)) }}` | Same join |

## 6. Acceptance Criteria

- [x] `product_id` is unique and not null
- [x] Row count matches `COUNT(DISTINCT product_id)` from `raw_olist.products`
- [x] `product_category_name_en` is never null (nulls replaced with `'uncategorized'`)
- [x] `product_volume_cm3` is null only where any dimension (length, height, width) is null
- [x] `product_volume_cm3 > 0` for all non-null rows
- [ ] All `product_id` values in `fct_order_items` resolve to a row in `dim_products`

## 7. Downstream Consumers

- **`fct_order_items`** — join on `product_id` to enable category-level analysis
- **Future mart:** `mart_product_performance` (#81) — GMV, delivery rate, and review scores by category
- **Dashboard:** Product category breakdown (planned, no current owner)

## 8. SLA / Freshness

- **Freshness requirement:** Updated by 6:00 AM BRT daily alongside `fct_order_items`
- **Note:** Source data is static (Kaggle); full refresh is fast and appropriate

## 9. Open Questions / Risks

- [ ] ~600 products have null `product_category_name` — confirm with stakeholders
  whether `'uncategorized'` is the right label or whether a different fallback is preferred.
- [ ] Physical dimension columns (`weight_g`, `length_cm`, etc.) are null for some products.
  Downstream marts using `product_volume_cm3` must handle nulls gracefully.
