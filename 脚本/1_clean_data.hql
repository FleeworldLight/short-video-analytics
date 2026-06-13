-- 短视频内容分析系统 — 数据清洗与聚合（ODS → DWD → DWS）
-- 执行流程：
--   1. 再次 CREATE TABLE（幂等）确保表存在
--   2. 清洗 ODS 数据写入 DWD（去重、过滤异常、派生字段）
--   3. 构建 dim_user / dim_video 维度表
--   4. 计算 DWS 层每日聚合

-- DDL（幂等建表）：确保依赖表存在

CREATE EXTERNAL TABLE IF NOT EXISTS ods_raw_interaction (
  user_id          INT,
  video_id         INT,
  play_duration    BIGINT,
  video_duration   BIGINT,
  `time`             STRING,
  `date`             INT,
  `timestamp`        DOUBLE,
  watch_ratio      DOUBLE
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = ",",
  "quoteChar"     = "\""
)
STORED AS TEXTFILE
LOCATION '/data/short_video/raw/ods_interaction'
TBLPROPERTIES ("skip.header.line.count" = "1");

CREATE EXTERNAL TABLE IF NOT EXISTS ods_raw_item_category (
  video_id INT,
  feat     STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = ",",
  "quoteChar"     = "\""
)
STORED AS TEXTFILE
LOCATION '/data/short_video/raw/ods_item_category'
TBLPROPERTIES ("skip.header.line.count" = "1");

CREATE EXTERNAL TABLE IF NOT EXISTS ods_raw_user_feature (
  user_id             INT,
  user_active_degree  STRING,
  is_lowactive_period INT,
  is_live_streamer    INT,
  is_video_author     INT,
  follow_user_num     INT,
  follow_user_num_range STRING,
  fans_user_num       INT,
  fans_user_num_range STRING,
  friend_user_num     INT,
  friend_user_num_range STRING,
  register_days       INT,
  register_days_range STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = ",",
  "quoteChar"     = "\""
)
STORED AS TEXTFILE
LOCATION '/data/short_video/raw/ods_user_feature'
TBLPROPERTIES ("skip.header.line.count" = "1");

CREATE EXTERNAL TABLE IF NOT EXISTS ods_raw_item_daily_features (
  video_id                INT,
  `date`                    INT,
  author_id               INT,
  video_type              STRING,
  upload_dt               STRING,
  upload_type             STRING,
  visible_status          STRING,
  video_duration          DOUBLE,
  video_width             INT,
  video_height            INT,
  music_id                BIGINT,
  video_tag_id            INT,
  video_tag_name          STRING,
  show_cnt                BIGINT,
  show_user_num           BIGINT,
  play_cnt                BIGINT,
  play_user_num           BIGINT,
  play_duration           DOUBLE,
  complete_play_cnt       BIGINT,
  complete_play_user_num  BIGINT,
  valid_play_cnt          BIGINT,
  valid_play_user_num     BIGINT,
  long_time_play_cnt      BIGINT,
  long_time_play_user_num BIGINT,
  short_time_play_cnt     BIGINT,
  short_time_play_user_num BIGINT,
  play_progress           DOUBLE,
  comment_stay_duration   DOUBLE,
  like_cnt                BIGINT,
  like_user_num           BIGINT,
  click_like_cnt          BIGINT,
  double_click_cnt        BIGINT,
  cancel_like_cnt         BIGINT,
  cancel_like_user_num    BIGINT,
  comment_cnt             BIGINT,
  comment_user_num        BIGINT,
  direct_comment_cnt      BIGINT,
  reply_comment_cnt       BIGINT,
  delete_comment_cnt      BIGINT,
  delete_comment_user_num BIGINT,
  comment_like_cnt        BIGINT,
  comment_like_user_num   BIGINT,
  follow_cnt              BIGINT,
  follow_user_num         BIGINT,
  cancel_follow_cnt       BIGINT,
  cancel_follow_user_num  BIGINT,
  share_cnt               BIGINT,
  share_user_num          BIGINT,
  download_cnt            BIGINT,
  download_user_num       BIGINT,
  report_cnt              BIGINT,
  report_user_num         BIGINT,
  reduce_similar_cnt      BIGINT,
  reduce_similar_user_num BIGINT,
  collect_cnt             BIGINT,
  collect_user_num        BIGINT,
  cancel_collect_cnt      BIGINT,
  cancel_collect_user_num BIGINT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = ",",
  "quoteChar"     = "\""
)
STORED AS TEXTFILE
LOCATION '/data/short_video/raw/ods_item_daily'
TBLPROPERTIES ("skip.header.line.count" = "1");

CREATE TABLE IF NOT EXISTS dwd_interaction_detail (
  user_id            INT,
  video_id           INT,
  play_duration_sec  DOUBLE,
  video_duration_sec DOUBLE,
  watch_ratio        DOUBLE,
  completion_flag    INT,
  like_flag          INT,
  comment_flag       INT,
  share_flag         INT,
  event_date         STRING,
  event_hour         INT,
  weekday            INT,
  time_period        STRING,
  category_ids       STRING,
  ts                 BIGINT
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- ODS → DWD 清洗：去重、过滤异常、派生字段

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

-- 清洗逻辑：
--   1. 按 user_id, video_id, date 分组，取最大时间戳的行（去重）
--   2. 过滤异常值：播放时长 > 0，视频时长 > 0，播放时长不超过视频时长的3倍
--   3. 派生字段：
--      - completion_flag: watch_ratio>=1 视为完播
--      - like_flag: watch_ratio>2 视为高兴趣
--      - time_period: 按小时划分为 凌晨/上午/中午/下午/晚间/深夜
--   4. 关联品类标签、评论/分享数据
INSERT OVERWRITE TABLE dwd_interaction_detail PARTITION (dt)
SELECT
  i.user_id,
  i.video_id,
  ROUND(play_duration / 1000.0, 2)       AS play_duration_sec,
  ROUND(video_duration / 1000.0, 2)      AS video_duration_sec,
  watch_ratio,
  IF(watch_ratio >= 1, 1, 0)           AS completion_flag,
  IF(watch_ratio > 2, 1, 0)            AS like_flag,
  IF(df.comment_cnt > 0, 1, 0)           AS comment_flag,
  IF(df.share_cnt > 0, 1, 0)             AS share_flag,
  CAST(i.`date` AS STRING)                    AS event_date,
  HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) AS event_hour,
  CAST((FROM_UNIXTIME(CAST(i.`timestamp` AS INT), 'u')) AS INT) AS weekday,
  CASE
    WHEN HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) BETWEEN 0  AND 5  THEN '凌晨'
    WHEN HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) BETWEEN 6  AND 11 THEN '上午'
    WHEN HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) BETWEEN 12 AND 13 THEN '中午'
    WHEN HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) BETWEEN 14 AND 17 THEN '下午'
    WHEN HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) BETWEEN 18 AND 21 THEN '晚间'
    WHEN HOUR(FROM_UNIXTIME(CAST(i.`timestamp` AS INT))) BETWEEN 22 AND 23 THEN '深夜'
  END AS time_period,
  c.feat                                   AS category_ids,
  CAST(i.`timestamp` AS BIGINT)              AS ts,
  CAST(i.`date` AS STRING)                     AS dt
FROM (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, video_id, `date`
      ORDER BY `timestamp` DESC
    ) AS rn
  FROM ods_raw_interaction
  WHERE play_duration > 0
    AND video_duration > 0
    AND play_duration <= video_duration * 3
) i
LEFT JOIN ods_raw_item_category c
  ON i.video_id = c.video_id
LEFT JOIN (
  SELECT video_id, `date`,
    MAX(comment_cnt) AS comment_cnt,
    MAX(share_cnt)   AS share_cnt
  FROM ods_raw_item_daily_features
  WHERE comment_cnt IS NOT NULL OR share_cnt IS NOT NULL
  GROUP BY video_id, `date`
) df
  ON i.video_id = df.video_id AND i.`date` = df.`date`
WHERE i.rn = 1;

-- 构建维度表：dim_user（用户画像）、dim_video（视频信息）

-- dim_user：从原始用户特征表导入，去空ID
CREATE TABLE IF NOT EXISTS dim_user (
  user_id             INT,
  user_active_degree  STRING,
  is_lowactive_period INT,
  is_live_streamer    INT,
  is_video_author     INT,
  follow_user_num     INT,
  fans_user_num       INT,
  friend_user_num     INT,
  register_days       INT
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

INSERT OVERWRITE TABLE dim_user
SELECT
  user_id,
  user_active_degree,
  is_lowactive_period,
  is_live_streamer,
  is_video_author,
  follow_user_num,
  fans_user_num,
  friend_user_num,
  register_days
FROM ods_raw_user_feature
WHERE user_id IS NOT NULL;

-- dim_video：关联交互表（去重）和品类表、每日特征表，聚合视频信息
CREATE TABLE IF NOT EXISTS dim_video (
  video_id       INT,
  duration_sec   DOUBLE,
  category_list  STRING,
  uploader_id    INT
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

INSERT OVERWRITE TABLE dim_video
SELECT
  i.video_id,
  ROUND(i.video_duration / 1000.0, 2) AS duration_sec,
  c.feat                              AS category_list,
  d.author_id                         AS uploader_id
FROM (
  SELECT DISTINCT video_id, video_duration
  FROM ods_raw_interaction
) i
LEFT JOIN ods_raw_item_category c ON i.video_id = c.video_id
LEFT JOIN (
  SELECT DISTINCT video_id, author_id
  FROM ods_raw_item_daily_features
) d ON i.video_id = d.video_id;

-- DWS 每日聚合计算：用户/视频/品类/周粒度

-- dws_user_daily_agg：用户粒度日聚合
CREATE TABLE IF NOT EXISTS dws_user_daily_agg (
  user_id           INT,
  video_count       BIGINT,
  total_watch_sec   DOUBLE,
  completion_count  BIGINT,
  avg_completion    DOUBLE,
  like_count        BIGINT
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

INSERT OVERWRITE TABLE dws_user_daily_agg PARTITION (dt)
SELECT
  user_id,
  COUNT(*)              AS video_count,
  SUM(play_duration_sec) AS total_watch_sec,
  SUM(completion_flag)  AS completion_count,
  ROUND(AVG(watch_ratio), 4) AS avg_completion,
  SUM(like_flag)        AS like_count,
  dt
FROM dwd_interaction_detail
GROUP BY user_id, dt;

-- dws_video_daily_agg：视频粒度日聚合，含热度评分
CREATE TABLE IF NOT EXISTS dws_video_daily_agg (
  video_id           INT,
  play_count         BIGINT,
  total_watch_sec    DOUBLE,
  completion_count   BIGINT,
  avg_completion     DOUBLE,
  like_count         BIGINT,
  hot_score          DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

INSERT OVERWRITE TABLE dws_video_daily_agg PARTITION (dt)
SELECT
  video_id,
  COUNT(*)              AS play_count,
  SUM(play_duration_sec) AS total_watch_sec,
  SUM(completion_flag)  AS completion_count,
  ROUND(AVG(watch_ratio), 4) AS avg_completion,
  SUM(like_flag)        AS like_count,
  -- 热度评分 = 完播率×0.3 + 观看比例×0.2 + 播放量对数×0.15 + 点赞率×0.15 + 评论率×0.10 + 分享率×0.10
  ROUND(
      AVG(completion_flag)          * 0.30
    + AVG(watch_ratio)              * 0.20
    + LOG(COUNT(*) + 1)             * 0.15
    + AVG(like_flag)                * 0.15
    + AVG(COALESCE(comment_flag,0)) * 0.10
    + AVG(COALESCE(share_flag,0))   * 0.10
  , 4) AS hot_score,
  dt
FROM dwd_interaction_detail
GROUP BY video_id, dt;

-- dws_category_daily_agg：品类粒度日聚合
-- 使用 LATERAL VIEW explode 将多标签展开为单行
CREATE TABLE IF NOT EXISTS dws_category_daily_agg (
  tag_id             INT,
  play_count         BIGINT,
  completion_count   BIGINT,
  avg_completion     DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

INSERT OVERWRITE TABLE dws_category_daily_agg PARTITION (dt)
SELECT
  CAST(tag_str AS INT) AS tag_id,
  COUNT(*)              AS play_count,
  SUM(d.completion_flag) AS completion_count,
  ROUND(AVG(d.watch_ratio), 4) AS avg_completion,
  d.dt
FROM dwd_interaction_detail d
LATERAL VIEW explode(split(regexp_replace(d.category_ids, '\\[|\\]', ''), ',')) t AS tag_str
WHERE tag_str IS NOT NULL AND tag_str != ''
GROUP BY CAST(tag_str AS INT), d.dt;

-- dws_user_weekly_agg：用户周聚合（用于留存分析）
CREATE TABLE IF NOT EXISTS dws_user_weekly_agg (
  user_id           INT,
  week_start        STRING,
  active_days       INT,
  total_plays       BIGINT,
  total_watch_sec   DOUBLE,
  total_completions BIGINT,
  avg_completion    DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

INSERT OVERWRITE TABLE dws_user_weekly_agg PARTITION (dt)
SELECT
  user_id,
  -- 计算周一的日期（作为周标识）
  date_sub(
    from_unixtime(unix_timestamp(event_date, 'yyyyMMdd'), 'yyyy-MM-dd'),
    CAST(from_unixtime(unix_timestamp(event_date, 'yyyyMMdd'), 'u') AS INT) - 1
  ) AS week_start,
  COUNT(DISTINCT event_date) AS active_days,
  COUNT(*)                   AS total_plays,
  SUM(play_duration_sec)     AS total_watch_sec,
  SUM(completion_flag)       AS total_completions,
  ROUND(AVG(watch_ratio), 4) AS avg_completion,
  dt
FROM dwd_interaction_detail
GROUP BY user_id,
  date_sub(
    from_unixtime(unix_timestamp(event_date, 'yyyyMMdd'), 'yyyy-MM-dd'),
    CAST(from_unixtime(unix_timestamp(event_date, 'yyyyMMdd'), 'u') AS INT) - 1
  ),
  dt;
