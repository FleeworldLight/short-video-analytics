"""
短视频内容分析系统 — CSV 转 JSON
功能：将 结果数据/ 目录下的 ADS 结果 CSV 转换为 docs/data.json，
      供前端可视化展示（ECharts 等）使用。
转换规则：
  - 列名下划线命名 → 驼峰命名（如 play_count → playCount）
  - 按配置的类型（str/int/float）自动转换类型
  - 忽略未在配置中定义的列
"""

import csv, json, os, re

SNAKE_RE = re.compile(r'_([a-z])')

def camel(s):
    """下划线转驼峰：completion_rate -> completionRate"""
    return SNAKE_RE.sub(lambda m: m.group(1).upper(), s)

# CSV 文件配置：(相对路径, JSON 顶层 key, 列名→类型映射)
FILES = [
    ("结果数据/completion_rate_by_category.csv", "completionCategory",
     {"tag_name": str, "total_plays": int, "completion_rate": float}),
    ("结果数据/retention.csv", "retention",
     {"report_date": str, "dau": int, "day1_retention": float,
      "day7_retention": float, "day30_retention": float}),
    ("结果数据/hot_ranking.csv", "hotRanking",
     {"rank_no": int, "video_id": int, "hot_score": float, "dt": str}),
    ("结果数据/influencer.csv", "influencer",
     {"rank_no": int, "uploader_id": int, "total_plays": int,
      "avg_completion": float, "avg_interaction": float, "influence_score": float}),
    ("结果数据/time_period_analysis.csv", "timePeriod",
     {"time_period": str, "play_count": int, "avg_watch_ratio": float}),
    ("结果数据/completion_rate_by_author.csv", "completionAuthor",
     {"uploader_id": int, "total_plays": int, "avg_completion_rate": float}),
]

def load_csv(path, types):
    """读取 CSV 并按类型映射转换为 dict 列表"""
    rows = []
    skipped_cols = set()
    with open(path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            r = {}
            for col, val in row.items():
                col = col.strip()
                key = col
                if key not in types:
                    key = col.split(".")[-1]
                if key not in types:
                    skipped_cols.add(col)
                    continue
                try:
                    r[camel(key)] = types[key](val.strip()) if val.strip() else None
                except (ValueError, TypeError):
                    r[camel(key)] = None
            rows.append(r)
    if skipped_cols:
        print(f"  [warn] unknown columns skipped: {sorted(skipped_cols)}")
    return rows

def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data = {}
    for path, key, types in FILES:
        full = os.path.join(base, path)
        rows = load_csv(full, types)
        data[key] = rows
    out = os.path.join(base, "docs", "data.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Written {len(json.dumps(data))} bytes to {out}")

if __name__ == "__main__":
    main()
