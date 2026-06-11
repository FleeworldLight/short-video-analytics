SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

INSERT OVERWRITE TABLE ads_completion_rate_by_category
SELECT
  c.tag_name,
  COUNT(*) AS total_plays,
  SUM(tmp.completion_flag) AS total_completions,
  ROUND(SUM(tmp.completion_flag) / COUNT(*), 4) AS completion_rate
FROM (
  SELECT base.completion_flag, tag_str
  FROM (
    SELECT d.completion_flag, ic.feat
    FROM dwd_interaction_detail d
    JOIN ods_raw_item_category ic ON d.video_id = ic.video_id
  ) base
  LATERAL VIEW explode(split(regexp_replace(base.feat, '\\[|\\]', ''), ',')) t AS tag_str
) tmp
JOIN dim_category c ON c.tag_id = CAST(tmp.tag_str AS INT)
GROUP BY c.tag_name
ORDER BY completion_rate DESC;

INSERT OVERWRITE TABLE ads_completion_rate_by_author
SELECT
  v.uploader_id,
  COUNT(*)                AS total_plays,
  ROUND(AVG(d.completion_flag), 4) AS avg_completion_rate
FROM dwd_interaction_detail d
JOIN dim_video v ON d.video_id = v.video_id
WHERE v.uploader_id IS NOT NULL
GROUP BY v.uploader_id
ORDER BY avg_completion_rate DESC;
