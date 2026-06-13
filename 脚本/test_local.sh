#!/bin/bash
set -e

# 短视频内容分析系统 — 本地全流程测试脚本
# 功能：一键执行从原始数据准备 → HDFS初始化 → Hive清洗建表
#       → KPI计算 → 结果导出 → MySQL导入 的完整流水线
# 步骤0：准备原始数据样本（前1000行）
# 步骤1：初始化 HDFS 目录并上传样本数据
# 步骤2：执行 HiveQL 建表（DDL）和清洗（ODS→DWD）
# 步骤3：构建维度表（dim_category, dim_creator）
# 步骤4：计算 6 个 KPI 指标
# 步骤5：验证 ADS 表数据量
# 步骤6：导出 DWD 清洗样例（前100行）
# 步骤7：导出 ADS 结果表为 CSV
# 步骤8：将 CSV 导入 MySQL

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
HDFS_BASE="/data/short_video"
MYSQL_USER="root"
MYSQL_PASS="123456"
MYSQL_DB="short_video"

echo "本地测试全流程测试脚本"

# 步骤0：准备原始数据样本（前1000行）
# 从全量数据 big_matrix.csv 截取前 1000 行（含表头）作为样本，避免在全量数据上反复调试
echo ""
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

# 步骤1：初始化 HDFS 目录并上传样本数据
echo ""
echo "步骤1：初始化HDFS"
hdfs dfs -mkdir -p $HDFS_BASE/raw/ods_interaction
hdfs dfs -mkdir -p $HDFS_BASE/raw/ods_item_category
hdfs dfs -mkdir -p $HDFS_BASE/raw/ods_user_feature
hdfs dfs -mkdir -p $HDFS_BASE/raw/ods_item_daily
hdfs dfs -mkdir -p $HDFS_BASE/dwd
hdfs dfs -mkdir -p $HDFS_BASE/dws
hdfs dfs -mkdir -p $HDFS_BASE/ads

hdfs dfs -put -f "$ROOT_DIR/数据样例/big_matrix_1000.csv"         $HDFS_BASE/raw/ods_interaction/
hdfs dfs -put -f "$ROOT_DIR/数据样例/item_categories_sample.csv"    $HDFS_BASE/raw/ods_item_category/
hdfs dfs -put -f "$ROOT_DIR/数据样例/user_features_raw_sample.csv"  $HDFS_BASE/raw/ods_user_feature/
hdfs dfs -put -f "$ROOT_DIR/数据样例/item_daily_features_sample.csv" $HDFS_BASE/raw/ods_item_daily/

# 步骤2：执行 HiveQL 建表（DDL）和清洗（ODS→DWD）
echo ""
echo "步骤2：建表并清洗数据（ODS → DWD）"
hive -f "$ROOT_DIR/脚本/2_create_tables.hql"
hive -f "$ROOT_DIR/脚本/1_clean_data.hql"

# 步骤3：构建维度表（dim_category 手动16条、dim_creator 聚合统计）
echo ""
echo "步骤3：构建维度表"
hive -e "
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

# 步骤4：计算 6 个 KPI 指标
echo ""
echo "步骤4：KPI指标计算"
hive -f "$ROOT_DIR/脚本/3_kpi_completion_rate.hql"
hive -f "$ROOT_DIR/脚本/4_kpi_retention.hql"
hive -f "$ROOT_DIR/脚本/5_kpi_hot_ranking.hql"
hive -f "$ROOT_DIR/脚本/6_kpi_influencer.hql"

# 时段分析（直接写入 ADS，无需独立 HQL 文件）
hive -e "
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

# 步骤4b：从 DWD 表提取不重复日期，展开为年/月/日/星期/季度
echo ""
echo "步骤4b：构建日期维度表"
hive -e "
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

# 步骤5：验证 6 张 ADS 表数据量
echo ""
echo "步骤5：验证ADS表"
hive -e "
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

# 步骤6：导出 DWD 清洗样例（前100行）
echo ""
echo "步骤6：导出DWD清洗样例（前100行）"
hive -e "
  SET hive.cli.print.header=true;
  SELECT *
  FROM dwd_interaction_detail
  LIMIT 100;
" | tr '\011' ',' > "$ROOT_DIR/结果数据/dwd_sample.csv"

# 步骤7：导出 6 张 ADS 表为 CSV（同时供步骤8 MySQL 导入用）
echo ""
echo "步骤7：导出ADS结果表为CSV"
mkdir -p "$ROOT_DIR/结果数据"

# ADS_MAP 格式：Hive表名（去掉 ads_ 前缀）:CSV文件名（不含扩展名）
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
  hive -e "SELECT * FROM ads_$tbl" \
    | tr '\011' ',' \
    | tail -n +2 \
    > "$ROOT_DIR/结果数据/$csv_name.csv"
done

echo "  CSV文件："
ls -la "$ROOT_DIR/结果数据/"*.csv 2>/dev/null || echo "  (空)"

# 步骤8：导入 CSV 到 MySQL（建库建表 + LOAD DATA）
echo ""
echo "步骤8：导入MySQL"

mysql -u $MYSQL_USER -p$MYSQL_PASS -e "SET GLOBAL local_infile = 1;"
mysql -u $MYSQL_USER -p$MYSQL_PASS --local-infile <<EOF
DROP DATABASE IF EXISTS $MYSQL_DB;
CREATE DATABASE $MYSQL_DB DEFAULT CHARSET utf8;
USE $MYSQL_DB;

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
EOF

for entry in "${ADS_MAP[@]}"; do
  tbl="${entry%%:*}"
  csv_name="${entry#*:}"
  CSV="$ROOT_DIR/结果数据/$csv_name.csv"
  if [ -f "$CSV" ]; then
    echo "  导入 $CSV 到 ads_$tbl ..."
    mysql -u $MYSQL_USER -p$MYSQL_PASS --local-infile $MYSQL_DB \
      -e "LOAD DATA LOCAL INFILE '$CSV' INTO TABLE ads_$tbl FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';"
  fi
done

echo ""
echo "  验证MySQL数据："
mysql -u $MYSQL_USER -p$MYSQL_PASS --local-infile -e "
USE $MYSQL_DB;
SELECT 'completion_rate_by_category', COUNT(*) FROM ads_completion_rate_by_category
UNION ALL SELECT 'completion_rate_by_author', COUNT(*) FROM ads_completion_rate_by_author
UNION ALL SELECT 'user_retention', COUNT(*) FROM ads_user_retention
UNION ALL SELECT 'content_hot_ranking', COUNT(*) FROM ads_content_hot_ranking
UNION ALL SELECT 'influencer_index', COUNT(*) FROM ads_influencer_index
UNION ALL SELECT 'time_period_analysis', COUNT(*) FROM ads_time_period_analysis;
"

echo ""
echo "流水线执行完成！"
