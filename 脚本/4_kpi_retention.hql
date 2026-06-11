WITH active_users AS (
  SELECT DISTINCT user_id,
    CAST(CONCAT(SUBSTR(dt,1,4), '-', SUBSTR(dt,5,2), '-', SUBSTR(dt,7,2)) AS DATE) AS event_date
  FROM dwd_interaction_detail
),
daily_active AS (
  SELECT
    a.event_date,
    COUNT(DISTINCT a.user_id) AS dau,
    COUNT(DISTINCT CASE WHEN b.user_id IS NOT NULL
      AND datediff(b.event_date, a.event_date) = 1
      THEN a.user_id END) AS d1_active,
    COUNT(DISTINCT CASE WHEN b7.user_id IS NOT NULL
      AND datediff(b7.event_date, a.event_date) = 7
      THEN a.user_id END) AS d7_active,
    COUNT(DISTINCT CASE WHEN b30.user_id IS NOT NULL
      AND datediff(b30.event_date, a.event_date) = 30
      THEN a.user_id END) AS d30_active
  FROM active_users a
  LEFT JOIN active_users b
    ON a.user_id = b.user_id
    AND datediff(b.event_date, a.event_date) = 1
  LEFT JOIN active_users b7
    ON a.user_id = b7.user_id
    AND datediff(b7.event_date, a.event_date) = 7
  LEFT JOIN active_users b30
    ON a.user_id = b30.user_id
    AND datediff(b30.event_date, a.event_date) = 30
  GROUP BY a.event_date
)
INSERT OVERWRITE TABLE ads_user_retention
SELECT
  event_date              AS report_date,
  dau,
  ROUND(d1_active  / dau, 4) AS day1_retention,
  ROUND(d7_active  / dau, 4) AS day7_retention,
  ROUND(d30_active / dau, 4) AS day30_retention
FROM daily_active
ORDER BY event_date;
