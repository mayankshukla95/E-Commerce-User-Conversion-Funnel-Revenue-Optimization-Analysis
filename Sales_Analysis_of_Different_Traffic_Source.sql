SELECT * FROM `gen-lang-client-0503336981.Dataset.user_events`;

-- Total User
SELECT Count(DISTINCT user_id) as total_user_count FROM `gen-lang-client-0503336981.Dataset.user_events`;

--- How many event type do we have and what are there names.

Select Count(Distinct event_type) as event_type_count FROM `gen-lang-client-0503336981.Dataset.user_events`;

Select Distinct event_type FROM `gen-lang-client-0503336981.Dataset.user_events`;

--- How many traffic source do we have and what are there names.

Select Count(Distinct traffic_source) as traffic_source_count FROM `gen-lang-client-0503336981.Dataset.user_events`;

Select Distinct traffic_source FROM `gen-lang-client-0503336981.Dataset.user_events`;

-- Min Start Date
Select Min(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`;

-- Max Event Date
Select max(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`;

-- Total Rows
Select Count(*) as total_rows FROM `gen-lang-client-0503336981.Dataset.user_events`;

--- Define sales funnel and the different stages.

With funnel_stages AS (
  Select
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views,
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
    COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
    COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    
  FROM `gen-lang-client-0503336981.Dataset.user_events`
  Where event_date >= TIMESTAMP(DATE_SUB((Select max(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`), INTERVAL 30 DAY))

)
Select * From funnel_stages;

--- Conversion rates through the funnel
With funnel_stages AS (
  Select
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views,
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
    COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
    COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    
  FROM `gen-lang-client-0503336981.Dataset.user_events`

   WHERE event_date >= TIMESTAMP(DATE_SUB((Select max(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`), INTERVAL 30 DAY))

)
Select
  stage_1_views,
  stage_2_cart,
  ROUND(stage_2_cart * 100 / stage_1_views, 1) AS view_to_cart_rate,

  stage_3_checkout,
  ROUND(stage_3_checkout * 100 / stage_2_cart, 1) AS cart_to_checkout_rate,

  stage_4_payment,
  ROUND(stage_4_payment * 100 / stage_3_checkout, 1) AS checkout_to_payment_rate,

  stage_5_purchase,
  ROUND(stage_5_purchase * 100 / stage_4_payment, 1) AS payment_to_purchase_rate,

  ROUND(stage_5_purchase * 100 / stage_3_checkout, 1) AS checkout_to_purchase_rate,

  ROUND(stage_5_purchase * 100 / stage_1_views, 1) AS overall_conversion_rate,

From funnel_stages;


--- Funnel By Traffic Source

With source_funnel AS (

  Select
    traffic_source,
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS views,
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS carts,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchases

  FROM `gen-lang-client-0503336981.Dataset.user_events`

  WHERE event_date >= TIMESTAMP(DATE_SUB((Select max(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`), INTERVAL 30 DAY))
  GROUP BY traffic_source

)
SELECT
  traffic_source,
  views,
  carts,
  purchases,
  ROUND(carts * 100 / views) AS cart_conversion_rate,
  ROUND(purchases * 100 / views) AS purchase_conversion_rate,

  ROUND(purchases * 100 / carts) AS cart_to_purchase_conversion_rate

FROM source_funnel
ORDER BY purchases DESC;


--- Time to Conversion Analysis

With user_journey AS (

  Select
    user_id,
    MIN(CASE WHEN event_type = 'page_view' THEN event_date END) AS view_time,
    MIN(CASE WHEN event_type = 'add_to_cart' THEN event_date END) AS cart_time,
    MIN(CASE WHEN event_type = 'purchase' THEN event_date END) AS purchase_time

  FROM `gen-lang-client-0503336981.Dataset.user_events`

  WHERE event_date >= TIMESTAMP(DATE_SUB((Select max(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`), INTERVAL 30 DAY))
  GROUP BY user_id
  HAVING MIN(CASE WHEN event_type = 'purchase' THEN event_date END) IS NOT NULL

)

SELECT
  COUNT(*) AS converted_users,
  ROUND(AVG(TIMESTAMP_DIFF(cart_time, view_time, MINUTE)), 2) AS avg_view_to_cart_minutes,
  ROUND(AVG(TIMESTAMP_DIFF(purchase_time, cart_time, MINUTE)), 2) AS avg_cart_to_purchase_minutes,
  ROUND(AVG(TIMESTAMP_DIFF(purchase_time, view_time, MINUTE)), 2) AS avg_total_journey_minutes


FROM user_journey;

--- Revenue Funnel Analysis

With funnel_revenue AS (

  SELECT
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS total_visitors,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS total_buyers,
    SUM(CASE WHEN event_type = 'purchase' THEN amount END) AS total_revenue,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS total_orders

  FROM `gen-lang-client-0503336981.Dataset.user_events`

  WHERE event_date >= TIMESTAMP(DATE_SUB((Select max(event_date) FROM `gen-lang-client-0503336981.Dataset.user_events`), INTERVAL 30 DAY))
)
SELECT
  total_visitors,
  total_buyers,
  total_orders,
  ROUND(total_revenue, 2) AS total_revenue,
  ROUND(total_revenue / total_orders, 2) AS avg_order_value,
  ROUND(total_revenue / total_buyers, 2) AS revenue_per_buyer,
  ROUND(total_revenue / total_visitors, 2) AS revenue_per_visitor

FROM funnel_revenue;
















