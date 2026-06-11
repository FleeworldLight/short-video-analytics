#!/bin/bash
set -e

echo "=== HDFS Status ==="
docker exec namenode hdfs dfsadmin -report 2>/dev/null | head -5 || echo "HDFS not available"

echo "=== Hive Tables ==="
docker exec hive-server hive -e "SHOW DATABASES;" 2>/dev/null || echo "Hive not available"

echo "=== HDFS Raw Data ==="
docker exec namenode hdfs dfs -ls -R /data/short_video/raw/ 2>/dev/null || echo "No raw data found"

echo "=== DWD Partitions ==="
docker exec hive-server hive -e "SHOW PARTITIONS dwd_interaction_detail;" 2>/dev/null || echo "No DWD partitions"

echo "=== ADS Data Sizes ==="
docker exec hive-server hive -e "
  SELECT 'ads_completion_rate_by_category' AS tbl, COUNT(*) FROM ads_completion_rate_by_category
  UNION ALL
  SELECT 'ads_completion_rate_by_author',   COUNT(*) FROM ads_completion_rate_by_author
  UNION ALL
  SELECT 'ads_user_retention',              COUNT(*) FROM ads_user_retention
  UNION ALL
  SELECT 'ads_content_hot_ranking',         COUNT(*) FROM ads_content_hot_ranking
  UNION ALL
  SELECT 'ads_influencer_index',            COUNT(*) FROM ads_influencer_index
  UNION ALL
  SELECT 'ads_time_period_analysis',        COUNT(*) FROM ads_time_period_analysis;
" 2>/dev/null || echo "ADS tables not available"
