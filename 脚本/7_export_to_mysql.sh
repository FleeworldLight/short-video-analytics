#!/bin/bash
set -e

MYSQL_HOST="mysql"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASS="123456"
MYSQL_DB="short_video"

echo "=== Step 1: Create MySQL tables ==="
docker exec mysql mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS <<EOF
CREATE DATABASE IF NOT EXISTS $MYSQL_DB DEFAULT CHARSET utf8;
USE $MYSQL_DB;

DROP TABLE IF EXISTS ads_completion_rate_by_category;
CREATE TABLE ads_completion_rate_by_category (
  tag_name        VARCHAR(100),
  total_plays     BIGINT,
  total_completions BIGINT,
  completion_rate DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS ads_completion_rate_by_author;
CREATE TABLE ads_completion_rate_by_author (
  uploader_id         INT,
  total_plays         BIGINT,
  avg_completion_rate DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS ads_user_retention;
CREATE TABLE ads_user_retention (
  report_date    VARCHAR(10),
  dau            BIGINT,
  day1_retention DOUBLE,
  day7_retention DOUBLE,
  day30_retention DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS ads_content_hot_ranking;
CREATE TABLE ads_content_hot_ranking (
  rank_no   INT,
  video_id  INT,
  hot_score DOUBLE,
  dt        VARCHAR(10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS ads_influencer_index;
CREATE TABLE ads_influencer_index (
  rank_no          INT,
  uploader_id      INT,
  total_plays      BIGINT,
  avg_completion   DOUBLE,
  avg_interaction  DOUBLE,
  influence_score  DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS ads_time_period_analysis;
CREATE TABLE ads_time_period_analysis (
  time_period    VARCHAR(10),
  play_count     BIGINT,
  avg_watch_ratio DOUBLE,
  like_count     BIGINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
echo "MySQL tables created."

echo "=== Step 2: Load CSV data ==="
ADS_TABLES=(
  "completion_rate_by_category"
  "completion_rate_by_author"
  "user_retention"
  "content_hot_ranking"
  "influencer_index"
  "time_period_analysis"
)

for tbl in "${ADS_TABLES[@]}"; do
  CSV="/import/$tbl.csv"
  echo "Loading $CSV into ads_$tbl ..."
  docker exec mysql mysql -h localhost -p123456 short_video \
    -e "LOAD DATA LOCAL INFILE '$CSV' INTO TABLE ads_$tbl FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';" \
    2>/dev/null || echo "  ($tbl.csv not found, skip)"
done

echo "=== Export complete ==="
