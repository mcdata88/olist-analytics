# Olist Analytics — dbt + Snowflake + PRD-Driven Workflow

A production-style dbt project built on the
[Olist Brazilian E-Commerce Kaggle dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce),
running on **Snowflake** and demonstrating a **PRD-first** analytics engineering
workflow with GitHub CI/CD, reusable Jinja macros, and dimensional modeling.

## Architecture

    RAW_OLIST (9 tables)
        │
        ▼
    STAGING (6 views) ──── Clean, rename, cast. No business logic.
        │
        ▼
    INTERMEDIATE (2 views) ──── Reusable aggregations shared across marts.
        │
        ▼
    MARTS
    ├── CORE
    │   ├── fct_order_items ──────────── Atomic fact table (order × item grain)
    │   ├── mart_order_revenue ────────── Single source of truth for order revenue
    │   └── mart_seller_performance ───── Seller GMV, delivery rates, and tiers
    └── MARKETING
        └── mart_customer_segmentation ── RFM-based customer segments

## PRD-Driven Workflow

Every model starts with a Product Requirements Document before any SQL is written.

    Issue (template) → PRD draft → PRD review → Feature branch → Build → PR (template) → CI → Merge

See `docs/prds/` for live examples:

| PRD | Issue | Status |
|---|---|---|
| [fct_order_items](docs/prds/fct_order_items.md) | #89 | Draft |
| [mart_seller_performance](docs/prds/mart_seller_performance.md) | #72 | Draft |
| [mart_order_revenue](docs/prds/mart_order_revenue.md) | #42 | Approved |
| [mart_customer_segmentation](docs/prds/mart_customer_segmentation.md) | #58 | Approved |

## Jinja Macros

Reusable SQL generators in `macros/`. Each file has a plain-language docstring
explaining arguments and compiled output.

| Macro | Purpose |
|---|---|
| `classify_tier(column, tiers)` | Generates a CASE WHEN tier label from a numeric column and configurable thresholds set in `dbt_project.yml` vars |
| `safe_divide(numerator, denominator)` | Null-safe division — returns null instead of erroring when denominator is zero |

## Quick Start

### 1. Snowflake Setup
Run `setup/snowflake_setup.sql` in Snowsight, then load the
[Kaggle CSVs](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
into `RAW_OLIST`.

### 2. Local Setup

    python3 -m venv venv && source venv/bin/activate
    pip install dbt-snowflake
    cp profiles.yml.example ~/.dbt/profiles.yml  # edit with your credentials
    dbt deps
    dbt debug

### 3. Build

    dbt build                                        # all models + tests
    dbt build --select fct_order_items               # fact table only
    dbt build --select mart_seller_performance+      # mart + its dependencies

## Project Structure

    ├── setup/snowflake_setup.sql        # Snowflake DDL
    ├── docs/prds/                       # PRDs — start here before writing SQL
    │   ├── TEMPLATE.md
    │   ├── fct_order_items.md
    │   ├── mart_order_revenue.md
    │   ├── mart_customer_segmentation.md
    │   └── mart_seller_performance.md
    ├── macros/
    │   ├── classify_tier.sql            # Configurable tier labeling
    │   └── safe_divide.sql             # Null-safe division
    ├── models/
    │   ├── staging/olist/               # 6 views — 1:1 with raw sources
    │   ├── intermediate/                # 2 views — reusable aggregations
    │   └── marts/
    │       ├── core/                    # fct_order_items, mart_order_revenue,
    │       │                            # mart_seller_performance
    │       └── marketing/               # mart_customer_segmentation
    ├── .github/
    │   ├── ISSUE_TEMPLATE/              # Forces PRD before work begins
    │   ├── PULL_REQUEST_TEMPLATE.md     # Requires PRD link in every PR
    │   └── workflows/dbt_ci.yml        # CI: PRD header check on new marts
    ├── profiles.yml.example             # Template for local config
    └── dbt_project.yml                  # Vars: seller_tier_thresholds

## Tech Stack

- **Snowflake** — Cloud data warehouse
- **dbt-snowflake 1.10** — Transformation framework
- **GitHub Actions** — CI/CD (PRD compliance check)
- **Olist Kaggle Dataset** — 9 tables, ~100k orders, Brazilian e-commerce

## Contributing

1. Read `docs/prds/TEMPLATE.md`
2. Open an issue using the "New Data Model Request" template
3. Draft and get your PRD approved before writing SQL
4. Follow the PR template checklist
