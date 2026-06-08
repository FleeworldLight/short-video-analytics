#!/bin/bash
set -e

echo "=== Step 1: Create HDFS directories ==="
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_interaction
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_item_category
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_user_feature
docker exec namenode hdfs dfs -mkdir -p /data/short_video/raw/ods_item_daily
docker exec namenode hdfs dfs -mkdir -p /data/short_video/dwd
docker exec namenode hdfs dfs -mkdir -p /data/short_video/dws
docker exec namenode hdfs dfs -mkdir -p /data/short_video/ads

echo "=== Step 2: Upload sample CSV to HDFS ==="
docker exec namenode hdfs dfs -put -f /data/samples/big_matrix_sample.csv     /data/short_video/raw/ods_interaction/
docker exec namenode hdfs dfs -put -f /data/samples/item_categories_sample.csv /data/short_video/raw/ods_item_category/
docker exec namenode hdfs dfs -put -f /data/samples/user_features_raw_sample.csv /data/short_video/raw/ods_user_feature/
docker exec namenode hdfs dfs -put -f /data/samples/item_daily_features_sample.csv /data/short_video/raw/ods_item_daily/

echo "=== Step 3: List uploaded files ==="
docker exec namenode hdfs dfs -ls -R /data/short_video/raw/

echo "=== Init done ==="
