-- ============================================================
-- 5_kpi_hot_ranking.hql: KPI 3 内容热度排行
--   热度分 = 完播率×0.35 + 平均观看比例×0.25
--          + LOG(播放量+1)×0.20 + 互动率×0.20
-- ============================================================

INSERT OVERWRITE TABLE ads_content_hot_ranking
SELECT
  ROW_NUMBER() OVER (ORDER BY hot_score DESC) AS rank_no,
  video_id,
  hot_score,
  dt
FROM (
  SELECT
    video_id,
    dt,
    ROUND(
        AVG(completion_flag) * 0.35
      + AVG(watch_ratio)    * 0.25
      + LOG(COUNT(*) + 1)   * 0.20
      + AVG(like_flag)      * 0.20
    , 4) AS hot_score
  FROM dwd_interaction_detail
  GROUP BY video_id, dt
) t
ORDER BY hot_score DESC
LIMIT 30;
