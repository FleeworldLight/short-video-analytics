import csv, json, os, re

SNAKE_RE = re.compile(r'_([a-z])')

def camel(s):
    return SNAKE_RE.sub(lambda m: m.group(1).upper(), s)

FILES = [
    ("results/completion_rate_by_category.csv", "completionCategory",
     {"tag_name": str, "total_plays": int, "completion_rate": float}),
    ("results/retention.csv", "retention",
     {"report_date": str, "dau": int, "day1_retention": float,
      "day7_retention": float, "day30_retention": float}),
    ("results/hot_ranking.csv", "hotRanking",
     {"rank_no": int, "video_id": int, "hot_score": float, "dt": str}),
    ("results/influencer.csv", "influencer",
     {"rank_no": int, "uploader_id": int, "total_plays": int,
      "avg_completion": float, "avg_interaction": float, "influence_score": float}),
    ("results/time_period_analysis.csv", "timePeriod",
     {"time_period": str, "play_count": int, "avg_watch_ratio": float}),
    ("results/completion_rate_by_author.csv", "completionAuthor",
     {"uploader_id": int, "total_plays": int, "avg_completion_rate": float}),
]

def load_csv(path, types):
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
