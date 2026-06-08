#!/bin/bash
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

echo "=========================================="
echo "  短视频平台内容分析系统 - 全流程执行脚本"
echo "=========================================="
echo ""

# ========== Step 1: Start cluster ==========
echo "=== Step 1: Starting Docker cluster ==="
cd "$(dirname "$0")"
docker-compose up -d
echo "Waiting for services to be ready ..."
sleep 25

# ========== Step 2: Init HDFS ==========
echo "=== Step 2: Init HDFS directories & upload data ==="
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_interaction
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_item_category
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_user_feature
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_item_daily
docker exec namenode hdfs dfs -mkdir -p /data/short_video/dwd
docker exec namenode hdfs dfs -mkdir -p /data/short_video/dws
docker exec namenode hdfs dfs -mkdir -p /data/short_video/ads

docker exec namenode hdfs dfs -put -f /data/samples/big_matrix_sample.csv     /data/short_video/raw/ods_interaction/
docker exec namenode hdfs dfs -put -f /data/samples/item_categories_sample.csv /data/short_video/raw/ods_item_category/
docker exec namenode hdfs dfs -put -f /data/samples/user_features_raw_sample.csv /data/short_video/raw/ods_user_feature/
docker exec namenode hdfs dfs -put -f /data/samples/item_daily_features_sample.csv /data/short_video/raw/ods_item_daily/

echo "HDFS data uploaded:"
docker exec namenode hdfs dfs -ls -R /data/short_video/raw/

# ========== Step 3: Create tables & clean data ==========
echo "=== Step 3: Create tables & clean data (ODS -> DWD) ==="
docker exec hive-server hive -f /scripts/2_create_tables.hql
docker exec hive-server hive -f /scripts/1_clean_data.hql

# ========== Step 4: Build dim_category ==========
echo "=== Step 4: Build dimension tables ==="
docker exec hive-server hive -e "
  INSERT OVERWRITE TABLE dim_category VALUES
    (1, 'Gaming', '娱乐'), (2, 'Music', '艺术'), (5, 'Fashion', '生活'),
    (6, 'Entertainment', '娱乐'), (7, 'Sports', '生活'), (9, 'Comedy', '娱乐'),
    (11, 'Life', '生活'), (12, 'Food', '生活'), (13, 'Agriculture', '生活'),
    (17, 'Animals', '生活'), (18, 'Cars', '生活'), (20, 'Film', '艺术'),
    (26, 'Photography', '文化'), (27, 'Other', '其他'), (28, 'News', '文化'),
    (31, 'Knowledge', '文化');

  INSERT OVERWRITE TABLE dim_creator
  SELECT
    author_id               AS creator_id,
    COUNT(DISTINCT video_id) AS total_videos,
    COUNT(DISTINCT video_tag_id) AS distinct_categories,
    ROUND(AVG(video_duration), 2) AS avg_video_duration
  FROM ods_raw_item_daily_features
  WHERE author_id IS NOT NULL
  GROUP BY author_id;
"

# ========== Step 5: KPI calculations ==========
echo "=== Step 5: KPI calculations ==="
docker exec hive-server hive -f /scripts/3_kpi_completion_rate.hql
docker exec hive-server hive -f /scripts/4_kpi_retention.hql
docker exec hive-server hive -f /scripts/5_kpi_hot_ranking.hql
docker exec hive-server hive -f /scripts/6_kpi_influencer.hql

docker exec hive-server hive -e "
  INSERT OVERWRITE TABLE ads_time_period_analysis
  SELECT
    time_period,
    COUNT(*)              AS play_count,
    ROUND(AVG(watch_ratio), 4) AS avg_watch_ratio,
    SUM(like_flag)        AS like_count
  FROM dwd_interaction_detail
  GROUP BY time_period
  ORDER BY play_count DESC;
"

echo "ADS table row counts:"
docker exec hive-server hive -e "
  SELECT 'completion_rate_by_category' AS tbl, COUNT(*) FROM ads_completion_rate_by_category
  UNION ALL
  SELECT 'completion_rate_by_author',   COUNT(*) FROM ads_completion_rate_by_author
  UNION ALL
  SELECT 'user_retention',              COUNT(*) FROM ads_user_retention
  UNION ALL
  SELECT 'content_hot_ranking',         COUNT(*) FROM ads_content_hot_ranking
  UNION ALL
  SELECT 'influencer_index',            COUNT(*) FROM ads_influencer_index
  UNION ALL
  SELECT 'time_period_analysis',        COUNT(*) FROM ads_time_period_analysis;
"

# ========== Step 6: Export ADS to CSV files ==========
echo "=== Step 6: Export ADS tables to CSV ==="
rm -rf "$ROOT_DIR/结果数据"/*.csv

ADS_TABLES=(
  "completion_rate_by_category"
  "completion_rate_by_author"
  "user_retention"
  "content_hot_ranking"
  "influencer_index"
  "time_period_analysis"
)

for tbl in "${ADS_TABLES[@]}"; do
  echo "Exporting $tbl ..."
  docker exec hive-server hive -e "SELECT * FROM ads_$tbl" \
    | sed 's/[\t]/,/g' \
    | tail -n +2 \
    > "$ROOT_DIR/结果数据/$tbl.csv"
done

echo "CSV files generated:"
ls -la "$ROOT_DIR/结果数据/"*.csv 2>/dev/null || echo "  (empty)"

# ========== Step 7: Export to MySQL ==========
echo "=== Step 7: Import into MySQL ==="

echo "Waiting for MySQL ..."
sleep 10

docker exec mysql mysql -h localhost -p123456 -e "
  DROP DATABASE IF EXISTS short_video;
  CREATE DATABASE short_video DEFAULT CHARSET utf8;
  USE short_video;

  CREATE TABLE ads_completion_rate_by_category (
    tag_name VARCHAR(100), total_plays BIGINT, total_completions BIGINT, completion_rate DOUBLE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  CREATE TABLE ads_completion_rate_by_author (
    uploader_id INT, total_plays BIGINT, avg_completion_rate DOUBLE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  CREATE TABLE ads_user_retention (
    report_date VARCHAR(10), dau BIGINT, day1_retention DOUBLE, day7_retention DOUBLE, day30_retention DOUBLE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  CREATE TABLE ads_content_hot_ranking (
    rank_no INT, video_id INT, hot_score DOUBLE, dt VARCHAR(10)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  CREATE TABLE ads_influencer_index (
    rank_no INT, uploader_id INT, total_plays BIGINT, avg_completion DOUBLE, avg_interaction DOUBLE, influence_score DOUBLE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  CREATE TABLE ads_time_period_analysis (
    time_period VARCHAR(10), play_count BIGINT, avg_watch_ratio DOUBLE, like_count BIGINT
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

  SHOW TABLES;
"

for tbl in "${ADS_TABLES[@]}"; do
  CSV="/import/$tbl.csv"
  echo "Loading $CSV into ads_$tbl ..."
  docker exec mysql mysql -h localhost -p123456 short_video \
    -e "LOAD DATA LOCAL INFILE '$CSV' INTO TABLE ads_$tbl FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';"
done

echo ""
echo "Verifying MySQL data:"
docker exec mysql mysql -h localhost -p123456 -e "
  USE short_video;
  SELECT 'completion_rate_by_category', COUNT(*) FROM ads_completion_rate_by_category
  UNION ALL SELECT 'completion_rate_by_author', COUNT(*) FROM ads_completion_rate_by_author
  UNION ALL SELECT 'user_retention', COUNT(*) FROM ads_user_retention
  UNION ALL SELECT 'content_hot_ranking', COUNT(*) FROM ads_content_hot_ranking
  UNION ALL SELECT 'influencer_index', COUNT(*) FROM ads_influencer_index
  UNION ALL SELECT 'time_period_analysis', COUNT(*) FROM ads_time_period_analysis;
"

echo ""
echo "=========================================="
echo "  Pipeline complete!"
echo "=========================================="
echo ""
echo "Next: start the dashboard"
echo ""
echo "  cd $ROOT_DIR/可视化源码/dashboard"
echo "  mvn spring-boot:run"
echo ""
echo "  Then open http://localhost:8080"
