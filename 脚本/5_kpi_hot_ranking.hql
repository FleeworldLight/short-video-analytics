-- KPI 3: 内容热度排行（Top 50）
-- 综合评分 = 完播率×0.30 + 观看比例×0.20 + 播放量对数×0.15 +
--            点赞率×0.15 + 评论率×0.10 + 分享率×0.10

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

INSERT OVERWRITE TABLE ads_content_hot_ranking
SELECT
  ROW_NUMBER() OVER (ORDER BY hot_score DESC) AS rank_no,
  video_id,
  hot_score,
  dt
FROM (
  SELECT
    video_id,
    MAX(dt) AS dt,
    ROUND(
        AVG(completion_flag)          * 0.30
      + AVG(watch_ratio)              * 0.20
      + LOG(COUNT(*) + 1)             * 0.15
      + AVG(like_flag)                * 0.15
      + AVG(COALESCE(comment_flag,0)) * 0.10
      + AVG(COALESCE(share_flag,0))   * 0.10
    , 4) AS hot_score
  FROM dwd_interaction_detail
  GROUP BY video_id
) t
ORDER BY hot_score DESC
LIMIT 50;
