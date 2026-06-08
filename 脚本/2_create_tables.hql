CREATE EXTERNAL TABLE IF NOT EXISTS ods_raw_interaction (
  user_id          INT,
  video_id         INT,
  play_duration    BIGINT,
  video_duration   BIGINT,
  time             STRING,
  date             INT,
  timestamp        DOUBLE,
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

CREATE EXTERNAL TABLE IF NOT EXISTS ods_raw_item_daily_features (
  video_id                INT,
  date                    INT,
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

CREATE TABLE IF NOT EXISTS dim_video (
  video_id       INT,
  duration_sec   DOUBLE,
  category_list  STRING,
  uploader_id    INT
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

CREATE TABLE IF NOT EXISTS dim_category (
  tag_id         INT,
  tag_name       STRING,
  category_group STRING
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

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

CREATE TABLE IF NOT EXISTS dim_creator (
  creator_id           INT,
  total_videos         BIGINT,
  distinct_categories  BIGINT,
  avg_video_duration   DOUBLE
)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");


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

CREATE TABLE IF NOT EXISTS dws_category_daily_agg (
  tag_id             INT,
  play_count         BIGINT,
  completion_count   BIGINT,
  avg_completion     DOUBLE
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");


CREATE TABLE IF NOT EXISTS ads_completion_rate_by_category (
  tag_name        STRING,
  total_plays     BIGINT,
  total_completions BIGINT,
  completion_rate DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/completion_rate_by_category';

CREATE TABLE IF NOT EXISTS ads_completion_rate_by_author (
  uploader_id          INT,
  total_plays          BIGINT,
  avg_completion_rate  DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/completion_rate_by_author';

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

CREATE TABLE IF NOT EXISTS ads_content_hot_ranking (
  rank_no      INT,
  video_id     INT,
  hot_score    DOUBLE,
  dt           STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/content_hot_ranking';

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

CREATE TABLE IF NOT EXISTS ads_time_period_analysis (
  time_period  STRING,
  play_count   BIGINT,
  avg_watch_ratio DOUBLE,
  like_count   BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/short_video/ads/time_period_analysis';
