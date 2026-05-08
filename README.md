# Olist Analytics — dbt + Snowflake + PRD-Driven Workflow

A production-style dbt project built on the
[Olist Brazilian E-Commerce Kaggle dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce),
running on **Snowflake** and demonstrating a **PRD-first** analytics engineering
workflow with GitHub CI/CD.

## Architecture

    RAW_OLIST (9 tables)
        │
        ▼
    STAGING (5 views) ──── Clean, rename, cast. No business logic.
        │
        ▼
    INTERMEDIATE (2 views) ──── Reusable aggregations shared across marts.
        │
        ▼
    MARTS (2 tables)
    ├── CORE: mart_order_revenue ──── Single source of truth for order revenue
    └── MARKETING: mart_customer_segmentation ──── RFM-based customer segments

## PRD-Driven Workflow

Every model starts with a Product Requirements Document before any SQL is written.

    Issue (template) → PRD draft → PRD review → Feature branch → Build → PR (template) → CI → Merge

See `docs/prds/` for live examples:
- [mart_order_revenue PRD](docs/prds/mart_order_revenue.md) — Finance team's order-level revenue
- [mart_customer_segmentation PRD](docs/prds/mart_customer_segmentation.md) — Marketing team's customer segments

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

    dbt build    # run all models + tests

## Project Structure

    ├── setup/snowflake_setup.sql        # Snowflake DDL
    ├── docs/prds/                       # PRDs — start here
    │   ├── TEMPLATE.md
    │   ├── mart_order_revenue.md
    │   └── mart_customer_segmentation.md
    ├── models/
    │   ├── staging/olist/               # 1:1 with raw sources
    │   ├── intermediate/                # Reusable aggregations
    │   └── marts/
    │       ├── core/                    # mart_order_revenue
    │       └── marketing/               # mart_customer_segmentation
    ├── .github/
    │   ├── ISSUE_TEMPLATE/              # Forces PRD before work begins
    │   ├── PULL_REQUEST_TEMPLATE.md     # Requires PRD link in every PR
    │   └── workflows/dbt_ci.yml        # CI: PRD header check
    ├── profiles.yml.example             # Template for local config
    └── dbt_project.yml

## Tech Stack

- **Snowflake** — Cloud data warehouse
- **dbt-snowflake** — Transformation framework
- **GitHub Actions** — CI/CD (PRD compliance check)
- **Olist Kaggle Dataset** — 9 tables, ~100k orders, Brazilian e-commerce

## Contributing

1. Read `docs/prds/TEMPLATE.md`
2. Open an issue using the "New Data Model Request" template
3. Draft and get your PRD approved before writing SQL
4. Follow the PR template checklist