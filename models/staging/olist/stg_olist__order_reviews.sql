-- stg_olist__order_reviews.sql
-- PRD: Foundation for mart_customer_segmentation (#58)
--
-- NOTE: Raw data has 789 duplicate review_ids.
-- We deduplicate by keeping the most recent review per review_id.

with source as (
    select * from {{ source('raw_olist', 'order_reviews') }}
),

renamed as (
    select
        review_id,
        order_id,
        review_score::integer           as review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date::timestamp_ntz   as reviewed_at,
        review_answer_timestamp::timestamp_ntz as review_answered_at,

        -- Rank duplicates: keep the most recent review per review_id
        row_number() over (
            partition by review_id
            order by review_answer_timestamp desc nulls last
        ) as row_num

    from source
),

deduplicated as (
    select * from renamed
    where row_num = 1
)

select
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    reviewed_at,
    review_answered_at
from deduplicated