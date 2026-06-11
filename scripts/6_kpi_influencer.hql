-- ============================================================
-- 6_kpi_influencer.hql: KPI 4 创作者影响力指数
--   综合创作者所有视频的总播放量、平均完播率、平均互动率
--   影响力分 = avg_completion×0.3 + avg_like×0.3 + LOG(total_plays+1)×0.4
-- ============================================================

INSERT OVERWRITE TABLE ads_influencer_index
SELECT
  ROW_NUMBER() OVER (ORDER BY influence_score DESC) AS rank_no,
  uploader_id,
  total_plays,
  avg_completion,
  avg_interaction,
  influence_score
FROM (
  SELECT
    v.uploader_id,
    COUNT(*)                    AS total_plays,
    ROUND(AVG(d.completion_flag), 4) AS avg_completion,
    ROUND(AVG(d.like_flag), 4)       AS avg_interaction,
    ROUND(
        AVG(d.completion_flag) * 0.3
      + AVG(d.like_flag)       * 0.3
      + LOG(COUNT(*) + 1)      * 0.4
    , 4) AS influence_score
  FROM dwd_interaction_detail d
  JOIN dim_video v ON d.video_id = v.video_id
  WHERE v.uploader_id IS NOT NULL
  GROUP BY v.uploader_id
) t
ORDER BY influence_score DESC
LIMIT 20;
