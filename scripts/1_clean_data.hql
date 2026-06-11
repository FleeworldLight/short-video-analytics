-- ============================================================
-- 1_clean_data.hql: ODS → DWD 数据清洗
-- KuaiRec big_matrix: user_id, video_id, play_duration(ms),
--                     video_duration(ms), time, date, timestamp,
--                     watch_ratio
--
-- 清洗逻辑：
--   1. 过滤 play_duration <= 0 或 video_duration <= 0
--   2. 过滤 play_duration > video_duration * 3（异常值）
--   3. 去重（ROW_NUMBER over user_id+video_id+date）
--   4. 衍生字段：completion_flag, like_flag, time_period
--   5. 关联分类标签
-- ============================================================

-- 建 ODS 外部表（如果尚未创建）
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
  register_days_range STRING,
  onehot_feat0        INT,
  onehot_feat1        INT,
  onehot_feat2        INT,
  onehot_feat3        INT,
  onehot_feat4        INT,
  onehot_feat5        INT,
  onehot_feat6        INT,
  onehot_feat7        INT,
  onehot_feat8        INT,
  onehot_feat9        INT,
  onehot_feat10       INT,
  onehot_feat11       INT,
  onehot_feat12       INT,
  onehot_feat13       INT,
  onehot_feat14       INT,
  onehot_feat15       INT,
  onehot_feat16       INT,
  onehot_feat17       INT
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  "separatorChar" = ",",
  "quoteChar"     = "\""
)
STORED AS TEXTFILE
LOCATION '/data/short_video/raw/ods_user_feature'
TBLPROPERTIES ("skip.header.line.count" = "1");

-- DWD 明细事实表
CREATE TABLE IF NOT EXISTS dwd_interaction_detail (
  user_id            INT,
  video_id           INT,
  play_duration_sec  DOUBLE,
  video_duration_sec DOUBLE,
  watch_ratio        DOUBLE,
  completion_flag    INT,
  like_flag          INT,
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

-- 动态分区写入 DWD
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

INSERT OVERWRITE TABLE dwd_interaction_detail PARTITION (dt)
SELECT
  i.user_id,
  i.video_id,
  ROUND(play_duration / 1000.0, 2)     AS play_duration_sec,
  ROUND(video_duration / 1000.0, 2)    AS video_duration_sec,
  watch_ratio,
  IF(watch_ratio >= 1, 1, 0)           AS completion_flag,
  IF(watch_ratio > 2, 1, 0)            AS like_flag,
  CAST(`date` AS STRING)                  AS event_date,
  HOUR(FROM_UNIXTIME(CAST(`timestamp` AS INT))) AS event_hour,
  -- weekday: 1=Monday ... 7=Sunday for Hive
  CAST((FROM_UNIXTIME(CAST(`timestamp` AS INT), 'u')) AS INT) AS weekday,
  CASE
    WHEN HOUR(FROM_UNIXTIME(CAST(`timestamp` AS INT))) BETWEEN 0  AND 5  THEN '凌晨'
    WHEN HOUR(FROM_UNIXTIME(CAST(`timestamp` AS INT))) BETWEEN 6  AND 11 THEN '上午'
    WHEN HOUR(FROM_UNIXTIME(CAST(`timestamp` AS INT))) BETWEEN 12 AND 13 THEN '中午'
    WHEN HOUR(FROM_UNIXTIME(CAST(`timestamp` AS INT))) BETWEEN 14 AND 17 THEN '下午'
    WHEN HOUR(FROM_UNIXTIME(CAST(`timestamp` AS INT))) BETWEEN 18 AND 21 THEN '晚间'
    ELSE '深夜'
  END AS time_period,
  c.feat                               AS category_ids,
  CAST(`timestamp` AS BIGINT)            AS ts,
  CAST(`date` AS STRING)                  AS dt
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
WHERE i.rn = 1;

-- 维度表：dim_user
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

-- DWS 用户日汇总
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

-- DWS 视频日汇总
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
  ROUND(
      AVG(completion_flag) * 0.35
    + AVG(watch_ratio)    * 0.25
    + LOG(COUNT(*) + 1)   * 0.20
    + AVG(like_flag)      * 0.20
  , 4) AS hot_score,
  dt
FROM dwd_interaction_detail
GROUP BY video_id, dt;

-- DWS 分类日汇总
CREATE TABLE IF NOT EXISTS dws_category_daily_agg (
  tag_id             INT,
  play_count         BIGINT,
  completion_count   BIGINT,
  avg_completion     DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- DWS 用户周汇总
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

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;

INSERT OVERWRITE TABLE dws_user_weekly_agg PARTITION (dt)
SELECT
  user_id,
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
