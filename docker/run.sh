#!/bin/bash
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

echo "短视频平台内容分析系统 - 全流程执行脚本"
echo ""

# 步骤0：准备原始数据样本（前1000行）
echo "步骤0：准备原始数据样本（前1000行）"
SAMPLE_FILE="$ROOT_DIR/数据样例/big_matrix_1000.csv"
FULL_DATA="$ROOT_DIR/KuaiRec/KuaiRec 2.0/data/big_matrix.csv"
if [ ! -f "$SAMPLE_FILE" ] && [ -f "$FULL_DATA" ]; then
  echo "  从全量数据截取前1000行 ..."
  head -n 1001 "$FULL_DATA" > "$SAMPLE_FILE"
  echo "  已生成：$(wc -l < "$SAMPLE_FILE") 行（含表头）"
elif [ -f "$SAMPLE_FILE" ]; then
  echo "  样本文件已存在，跳过生成"
else
  echo "  全量数据不存在（$FULL_DATA），跳过样本生成"
fi

# 步骤1：启动Docker集群
echo "步骤1：启动Docker集群"
cd "$(dirname "$0")"
docker compose up -d
echo "  等待服务就绪 ..."
sleep 25

# 步骤2：初始化HDFS目录并上传数据
echo "步骤2：初始化HDFS目录并上传数据"
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_interaction
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_item_category
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_user_feature
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_item_daily
docker exec namenode hdfs dfs -mkdir -p /data/short_video/dwd
docker exec namenode hdfs dfs -mkdir -p /data/short_video/dws
docker exec namenode hdfs dfs -mkdir -p /data/short_video/ads

docker exec namenode hdfs dfs -put -f /data/samples/big_matrix_1000.csv     /data/short_video/raw/ods_interaction/
docker exec namenode hdfs dfs -put -f /data/samples/item_categories_sample.csv /data/short_video/raw/ods_item_category/
docker exec namenode hdfs dfs -put -f /data/samples/user_features_raw_sample.csv /data/short_video/raw/ods_user_feature/
docker exec namenode hdfs dfs -put -f /data/samples/item_daily_features_sample.csv /data/short_video/raw/ods_item_daily/

echo "  HDFS已上传："
docker exec namenode hdfs dfs -ls -R /data/short_video/raw/

# 步骤3：建表并清洗数据（ODS → DWD）
echo "步骤3：建表并清洗数据（ODS → DWD）"
docker exec hive-server hive -f /scripts/2_create_tables.hql
docker exec hive-server hive -f /scripts/1_clean_data.hql

# 步骤4：构建维度表
echo "步骤4：构建维度表"
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

# 步骤5：KPI指标计算
echo "步骤5：KPI指标计算"
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

# 步骤5b：构建日期维度表
echo "步骤5b：构建日期维度表"
docker exec hive-server hive -e "
  INSERT OVERWRITE TABLE dim_date
  SELECT
    date_id,
    CAST(SUBSTR(date_id, 1, 4) AS INT) AS year,
    CAST(SUBSTR(date_id, 5, 2) AS INT) AS month,
    CAST(SUBSTR(date_id, 7, 2) AS INT) AS day,
    CAST(FROM_UNIXTIME(UNIX_TIMESTAMP(date_id, 'yyyyMMdd'), 'u') AS INT) AS weekday,
    CASE WHEN CAST(FROM_UNIXTIME(UNIX_TIMESTAMP(date_id, 'yyyyMMdd'), 'u') AS INT) >= 6 THEN 1 ELSE 0 END AS is_weekend,
    CASE
      WHEN CAST(SUBSTR(date_id, 5, 2) AS INT) BETWEEN 1  AND 3  THEN 1
      WHEN CAST(SUBSTR(date_id, 5, 2) AS INT) BETWEEN 4  AND 6  THEN 2
      WHEN CAST(SUBSTR(date_id, 5, 2) AS INT) BETWEEN 7  AND 9  THEN 3
      ELSE 4
    END AS quarter
  FROM (
    SELECT DISTINCT dt AS date_id FROM dwd_interaction_detail
  ) d
  ORDER BY date_id;
"

# 步骤5c：周度热度排行
echo "步骤5c：周度热度排行"
docker exec hive-server hive -e "
  SELECT ROW_NUMBER() OVER (ORDER BY hot_score DESC) AS rank_no,
         video_id, hot_score, week_start
  FROM (
    SELECT d.video_id,
           CONCAT(SUBSTR(d.dt,1,4), '-W', LPAD(CEIL(CAST(SUBSTR(d.dt,5,2) AS INT)/4),2,'0')) AS week_start,
           ROUND(
               AVG(d.completion_flag) * 0.30
             + AVG(d.watch_ratio)     * 0.20
             + LOG(COUNT(*) + 1)      * 0.15
             + AVG(d.like_flag)       * 0.15
             + AVG(COALESCE(d.comment_flag,0)) * 0.10
             + AVG(COALESCE(d.share_flag,0))   * 0.10
           , 4) AS hot_score
    FROM dwd_interaction_detail d
    GROUP BY d.video_id,
             CONCAT(SUBSTR(d.dt,1,4), '-W', LPAD(CEIL(CAST(SUBSTR(d.dt,5,2) AS INT)/4),2,'0'))
  ) t
  ORDER BY hot_score DESC
  LIMIT 50;
" | tr '\011' ',' | tail -n +2 > "$ROOT_DIR/结果数据/hot_ranking_weekly.csv"

echo "  ADS表行数统计："
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

# 步骤6：导出ADS结果表为CSV
echo "步骤6：导出ADS结果表为CSV"
rm -f "$ROOT_DIR/结果数据"/*.csv

ADS_MAP=(
  "completion_rate_by_category:completion_rate_by_category"
  "completion_rate_by_author:completion_rate_by_author"
  "user_retention:retention"
  "content_hot_ranking:hot_ranking"
  "influencer_index:influencer"
  "time_period_analysis:time_period_analysis"
)

for entry in "${ADS_MAP[@]}"; do
  tbl="${entry%%:*}"
  csv_name="${entry#*:}"
  echo "  导出 $tbl → $csv_name.csv ..."
  docker exec hive-server hive -e "SELECT * FROM ads_$tbl" \
    | tr '\011' ',' \
    | tail -n +2 \
    > "$ROOT_DIR/结果数据/$csv_name.csv"
done

# 步骤6b：导出DWD清洗样例（前100行）
echo "步骤6b：导出DWD清洗样例（前100行）"
docker exec hive-server hive -e "
  SET hive.cli.print.header=true;
  SELECT *
  FROM dwd_interaction_detail
  LIMIT 100;
" | tr '\011' ',' > "$ROOT_DIR/结果数据/dwd_sample.csv"
echo "  DWD样例已导出到：结果数据/dwd_sample.csv"

echo "  生成的CSV文件："
ls -la "$ROOT_DIR/结果数据/"*.csv 2>/dev/null || echo "  (空)"

# 步骤7：导入MySQL
echo "步骤7：导入MySQL"

echo "  等待MySQL就绪 ..."
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

for entry in "${ADS_MAP[@]}"; do
  tbl="${entry%%:*}"
  csv_name="${entry#*:}"
  CSV="/import/$csv_name.csv"
  echo "  导入 $CSV 到 ads_$tbl ..."
  docker exec mysql mysql -h localhost -p123456 short_video \
    -e "LOAD DATA LOCAL INFILE '$CSV' INTO TABLE ads_$tbl FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';"
done

echo ""
echo "  验证MySQL数据："
docker exec mysql mysql -h localhost -p123456 -e "
  USE short_video;
  SELECT 'completion_rate_by_category', COUNT(*) FROM ads_completion_rate_by_category
  UNION ALL SELECT 'completion_rate_by_author', COUNT(*) FROM ads_completion_rate_by_author
  UNION ALL SELECT 'user_retention', COUNT(*) FROM ads_user_retention
  UNION ALL SELECT 'content_hot_ranking', COUNT(*) FROM ads_content_hot_ranking
  UNION ALL SELECT 'influencer_index', COUNT(*) FROM ads_influencer_index
  UNION ALL SELECT 'time_period_analysis', COUNT(*) FROM ads_time_period_analysis;
"

# 步骤8：启动可视化面板
echo "步骤8：启动可视化面板"
cd "$ROOT_DIR/可视化源码/dashboard"
nohup mvn spring-boot:run -DskipTests > "$ROOT_DIR/可视化源码/dashboard/dashboard.log" 2>&1 &
echo "  面板启动中，日志：可视化源码/dashboard/dashboard.log"
echo "  等待 15 秒后检查状态 ..."
sleep 15
if curl -s http://localhost:8080/api/completion/category > /dev/null 2>&1; then
  echo "  面板已启动成功！"
  echo "  访问地址：http://$(hostname -I | awk '{print $1}'):8080"
else
  echo "  面板可能还在启动中，请稍后手动检查："
  echo "  cat $ROOT_DIR/可视化源码/dashboard/dashboard.log"
fi
cd "$ROOT_DIR"

echo ""
echo "全流程执行完成！"
