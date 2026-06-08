SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

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
    COUNT(*)                           AS total_plays,
    ROUND(AVG(d.completion_flag), 4)   AS avg_completion,
    ROUND((AVG(d.like_flag) + AVG(COALESCE(d.comment_flag,0)) + AVG(COALESCE(d.share_flag,0))) / 3, 4) AS avg_interaction,
    ROUND(
        AVG(d.completion_flag)               * 0.25
      + AVG(d.like_flag)                     * 0.15
      + AVG(COALESCE(d.comment_flag,0))      * 0.15
      + AVG(COALESCE(d.share_flag,0))        * 0.10
      + LOG(COUNT(*) + 1)                    * 0.35
    , 4) AS influence_score
  FROM dwd_interaction_detail d
  JOIN dim_video v ON d.video_id = v.video_id
  WHERE v.uploader_id IS NOT NULL
  GROUP BY v.uploader_id
) t
ORDER BY influence_score DESC
LIMIT 20;
