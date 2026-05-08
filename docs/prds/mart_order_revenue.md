# PRD: Order Revenue Summary (mart_order_revenue)

**Author:** Ana Silva
**Status:** Approved
**Created:** 2026-04-15
**Last Updated:** 2026-04-22
**Linked Issue:** #42

---

## 1. Business Context

The Finance and Growth teams need a single reliable table summarizing revenue
per order, including payment breakdowns and shipping costs. Today this logic is
duplicated across three Looker Explores and two ad-hoc notebooks, each producing
slightly different numbers. This mart becomes the **single source of truth** for
order-level revenue reporting.

## 2. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `raw_olist.orders` | Order header with status and timestamps | 1 row per order | Daily |
| `raw_olist.order_items` | Line items with price and freight | 1 row per order + product | Daily |
| `raw_olist.order_payments` | Payment installments by type | 1 row per order + payment seq | Daily |

## 3. Output Specification

- **Model name:** `mart_order_revenue`
- **Grain:** One row per **order_id**
- **Primary key:** `order_id`
- **Materialization:** table (full refresh daily)

### Key Columns

| Column | Type | Description | Business Logic |
|---|---|---|---|
| `order_id` | VARCHAR | Unique order identifier | From `orders` |
| `customer_id` | VARCHAR | FK to customer | From `orders` |
| `order_status` | VARCHAR | Current status | From `orders`; keep all statuses |
| `order_purchase_at` | TIMESTAMP | When the order was placed | From `orders.order_purchase_timestamp` |
| `order_delivered_at` | TIMESTAMP | When delivered to customer | From `orders.order_delivered_customer_date` |
| `total_items` | INTEGER | Count of distinct products | `COUNT(DISTINCT product_id)` from `order_items` |
| `total_item_revenue` | NUMERIC | Sum of product prices | `SUM(price)` from `order_items` |
| `total_freight` | NUMERIC | Sum of freight charges | `SUM(freight_value)` from `order_items` |
| `total_payment` | NUMERIC | Actual amount paid | `SUM(payment_value)` from `order_payments` |
| `payment_types` | VARCHAR | Comma-separated payment methods | `LISTAGG(DISTINCT payment_type)` |
| `payment_installments_max` | INTEGER | Highest installment count | `MAX(payment_installments)` |
| `revenue_freight_delta` | NUMERIC | Discrepancy check | `total_payment - (total_item_revenue + total_freight)` |

## 4. Metric Definitions

| Metric | Formula | Notes |
|---|---|---|
| Gross Merchandise Value (GMV) | `SUM(total_item_revenue)` across orders | Exclude cancelled/unavailable orders for reporting |
| Average Order Value (AOV) | `GMV / COUNT(order_id)` | Only delivered orders |
| Freight-to-Revenue Ratio | `SUM(total_freight) / SUM(total_item_revenue)` | Flag if > 30% |

## 5. Acceptance Criteria

- [ ] `order_id` is unique and not null
- [ ] `total_item_revenue >= 0` for all rows
- [ ] Row count matches `COUNT(DISTINCT order_id)` from `raw_olist.orders`
- [ ] `SUM(total_payment)` reconciles with `SUM(payment_value)` from raw payments (exact match)
- [ ] `revenue_freight_delta` is 0 for 95%+ of delivered orders (document exceptions)
- [ ] No orphaned orders (every order_id in items/payments exists in orders)

## 6. Downstream Consumers

- **Dashboard:** Looker "Revenue Overview" (Finance team)
- **Dashboard:** Looker "Seller Performance" (Marketplace Ops)
- **Model:** `mart_seller_performance` (depends on this mart)
- **Notebook:** Monthly investor reporting (Growth team)

## 7. SLA / Freshness

- **Freshness requirement:** Updated by 7:00 AM BRT daily
- **Staleness alert:** If source data older than 36 hours

## 8. Open Questions / Risks

- [x] ~Should we include cancelled orders?~ **Decision: Yes, include all statuses. Filter at dashboard level.**
- [ ] Voucher/discount amounts are embedded in payment_value — confirm with Finance whether to break out separately in v2.