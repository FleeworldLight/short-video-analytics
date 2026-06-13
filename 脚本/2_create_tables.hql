-- 短视频内容分析系统 — 四层数仓建表 DDL
-- 执行顺序：首先执行本文件，创建所有 ODS/DWD/DWS/DIM/ADS 表

-- ODS 原始数据层：加载 CSV 原始数据，仅定义 schema 不做转换

-- ods_raw_interaction：用户-视频交互原始记录（CSV 格式加载）
-- 字段：用户ID、视频ID、播放时长、视频时长、时间戳等
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

-- ods_raw_item_category：视频分类标签（CSV，video_id → feat 多标签）
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

-- ods_raw_item_daily_features：视频每日特征宽表（播放、点赞、评论、关注等）
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

-- ods_raw_user_feature：用户画像原始数据
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

-- DWD 明细数据层：清洗后的交互明细，按日分区，ORC + Snappy 压缩

-- dwd_interaction_detail：清洗后的交互明细，按日分区，ORC + Snappy 压缩
CREATE TABLE IF NOT EXISTS dwd_interaction_detail (
  user_id            INT,
  video_id           INT,
  play_duration_sec  DOUBLE,
  video_duration_sec DOUBLE,
  watch_ratio        DOUBLE,
  completion_flag    INT,       -- 1=完播（watch_ratio>=1），0=未完播
  like_flag          INT,       -- 1=高兴趣（watch_ratio>2），0=一般
  comment_flag       INT,
  share_flag         INT,
  event_date         STRING,
  event_hour         INT,
  weekday            INT,
  time_period        STRING,   -- 凌晨/上午/中午/下午/晚间/深夜
  category_ids       STRING,
  ts                 BIGINT
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- DIM 维度表：用户、视频、品类、日期、创作者

-- dim_user：用户维度（活跃度、粉丝数等静态特征）
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

-- dim_video：视频维度（时长、分类、上传者）
CREATE TABLE IF NOT EXISTS dim_video (
  video_id       INT,
  duration_sec   DOUBLE,
  category_list  STRING,
  uploader_id    INT
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- dim_category：品类维度（tag_id → tag_name + 文化/生活/娱乐/艺术 分组）
CREATE TABLE IF NOT EXISTS dim_category (
  tag_id         INT,
  tag_name       STRING,
  category_group STRING
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- dim_date：日期维度（年/月/日/星期/是否周末/季度）
CREATE TABLE IF NOT EXISTS dim_date (
  date_id     STRING,
  year        INT,
  month       INT,
  day         INT,
  weekday     INT,
  is_weekend  INT,
  quarter     INT
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- dim_creator：创作者维度（聚合统计：作品数、横跨分类数、平均时长）
CREATE TABLE IF NOT EXISTS dim_creator (
  creator_id           INT,
  total_videos         BIGINT,
  distinct_categories  BIGINT,
  avg_video_duration   DOUBLE
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- DWS 轻聚层：按用户/视频/品类/周粒度轻度聚合

-- dws_user_daily_agg：用户每日聚合（播放量、完播数、点赞数）
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

-- dws_video_daily_agg：视频每日聚合（含热度评分）
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

-- dws_user_weekly_agg：用户周聚合（活跃天数、完播率等）
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

-- dws_category_daily_agg：品类每日聚合
CREATE TABLE IF NOT EXISTS dws_category_daily_agg (
  tag_id             INT,
  play_count         BIGINT,
  completion_count   BIGINT,
  avg_completion     DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- ADS 应用层：最终 KPI 结果表，TEXTFILE 格式供 MySQL 导入

-- ads_completion_rate_by_category：各品类完播率（TEXTFILE 供 MySQL 导入）
CREATE TABLE IF NOT EXISTS ads_completion_rate_by_category (
  tag_name        STRING,
  total_plays     BIGINT,
  total_completions BIGINT,
  completion_rate DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/completion_rate_by_category';

-- ads_completion_rate_by_author：各创作者平均完播率
CREATE TABLE IF NOT EXISTS ads_completion_rate_by_author (
  uploader_id          INT,
  total_plays          BIGINT,
  avg_completion_rate  DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/completion_rate_by_author';

-- ads_user_retention：用户留存分析（次日/7日/30日留存率）
CREATE TABLE IF NOT EXISTS ads_user_retention (
  report_date    STRING,
  dau            BIGINT,
  day1_retention DOUBLE,
  day7_retention DOUBLE,
  day30_retention DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/user_retention';

-- ads_content_hot_ranking：内容热度排名（综合算法排序）
CREATE TABLE IF NOT EXISTS ads_content_hot_ranking (
  rank_no      INT,
  video_id     INT,
  hot_score    DOUBLE,
  dt           STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/content_hot_ranking';

-- ads_influencer_index：创作者影响力指数排名
CREATE TABLE IF NOT EXISTS ads_influencer_index (
  rank_no          INT,
  uploader_id      INT,
  total_plays      BIGINT,
  avg_completion   DOUBLE,
  avg_interaction  DOUBLE,
  influence_score  DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/influencer_index';

-- ads_time_period_analysis：时段分析（各时段播放量/完播率/点赞数）
CREATE TABLE IF NOT EXISTS ads_time_period_analysis (
  time_period  STRING,
  play_count   BIGINT,
  avg_watch_ratio DOUBLE,
  like_count   BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/time_period_analysis';
