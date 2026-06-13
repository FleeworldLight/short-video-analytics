# 短视频平台内容分析系统

基于 **KuaiRec 2.0**（快手真实用户行为数据）的离线数仓 + 可视化分析系统。
四层架构（ODS → DWD → DWS → ADS），Docker 一站式部署。

## 技术栈

| 层 | 技术 |
|---|---|
| 数据存储 & 计算 | Hadoop HDFS + Hive + Spark |
| 容器编排 | Docker Compose（单节点集群） |
| 后端 API | Spring Boot 2.7 / JDBC Template → MySQL |
| 前端可视化 | ECharts 5 + Axios |

## 架构

```
KuaiRec CSV 原始数据 (~1GB)
    │
    ▼
┌─── ODS 层（原始数据，CSV 格式）──────────────┐
│  ods_raw_interaction / item_category / ...   │
└──────────────────┬────────────────────────────┘
                   │ Hive ETL：过滤异常、去重、衍生字段
                   ▼
┌─── DWD 层（清洗明细，ORC + Snappy）──────────┐
│  dwd_interaction_detail                      │
└──────────────────┬────────────────────────────┘
                   │ 轻度聚合
                   ▼
┌─── DWS 层（聚合数据）────────────────────────┐
│  dws_user_daily / video_daily / ...          │
└──────────────────┬────────────────────────────┘
                   │ KPI 指标计算
                   ▼
┌─── ADS 层（应用指标结果）─────────────────────┐
│  completion_rate / retention / hot_ranking   │
│  influencer / time_period_analysis           │
└────────┬──────────────────────────┬───────────┘
         │ 导出 CSV                 │ 导入 MySQL
         ▼                          ▼
   GitHub Pages             Spring Boot + ECharts
  (docs/index.html)            (localhost:8080)
```

## 可视化前端

| 方案 | 启动方式 | 数据来源 |
|---|---|---|
| **GitHub Pages** | CI 自动部署（push main） | `结果数据/*.csv` → `docs/data.json` |
| **Spring Boot 仪表盘** | `mvn spring-boot:run` | MySQL（`localhost:3306/short_video`） |

## KPI 指标

| KPI | 公式 | ADS 表 |
|---|---|---|
| **完播率（按类别）** | `SUM(completion_flag) / COUNT(*)` | `ads_completion_rate_by_category` |
| **完播率（按创作者）** | `AVG(completion_flag)` | `ads_completion_rate_by_author` |
| **用户留存率** | 次日/7日/30日留存用户 / 当日活跃用户 | `ads_user_retention` |
| **内容热度排行 Top 50** | `completion_flag×0.30 + watch_ratio×0.20 + LOG(play_count+1)×0.15 + like_flag×0.15 + comment_flag×0.10 + share_flag×0.10` | `ads_content_hot_ranking` |
| **创作者影响力 Top 20** | `completion_flag×0.25 + like_flag×0.15 + comment_flag×0.15 + share_flag×0.10 + LOG(play_count+1)×0.35` | `ads_influencer_index` |
| **时段播放分析** | 按 6 个时段（凌晨/上午/中午/下午/晚间/深夜）聚合播放量 | `ads_time_period_analysis` |

## 全流程运行（Docker）

```bash
cd docker
chmod +x run.sh
./run.sh
```

一键执行：启动 9 个容器 → 上传数据到 HDFS → Hive 建表 & ETL（ODS → DWD → DWS → ADS）→ 6 个 KPI 计算 → 导出 CSV → 导入 MySQL → 启动可视化面板。

## 本地开发（无需 Docker）

```bash
# 前置条件：JDK 21+，Maven 3.9+
# 结果数据/ 目录下需有 6 个 KPI CSV 文件

cd 可视化源码/dashboard
mvn spring-boot:run
# 访问 http://localhost:8080
```

## 项目结构

```
├── docker/
│   ├── docker-compose.yml      # 9 个容器（Hadoop/Hive/Spark/MySQL）
│   ├── run.sh                  # 一键全流程脚本
│   ├── core-site.xml           # Hadoop core-site 配置
│   └── postgresql-42.5.1.jar  # Hive Metastore JDBC 驱动
├── 脚本/
│   ├── 1_clean_data.hql        # ODS→DWD 清洗 + DWS 聚合（364 行）
│   ├── 2_create_tables.hql     # 四层表 DDL（312 行）
│   ├── 3_kpi_completion_rate.hql
│   ├── 4_kpi_retention.hql
│   ├── 5_kpi_hot_ranking.hql
│   ├── 6_kpi_influencer.hql
│   ├── csv_to_json.py          # CSV → JSON（CI GitHub Pages 用）
│   └── test_local.sh           # VM 本地全流程（无 Docker）
├── 可视化源码/
│   ├── preview.html            # 纯前端预览（mock 数据）
│   └── dashboard/              # Spring Boot 后端 + ECharts 前端
│       └── src/main/
│           ├── java/.../controller/   # REST API（6 个端点）
│           ├── java/.../service/      # JDBC Template 查询
│           ├── java/.../model/        # 6 个 POJO
│           └── resources/static/      # ECharts 仪表盘页面
├── 结果数据/                   # 6 个 KPI 结果 CSV
├── 数据样例/                   # KuaiRec 2.0 样本（前 1000 行）
├── docs/                       # GitHub Pages 部署目录
│   ├── index.html              # ECharts 仪表盘（CI 部署）
│   ├── data.json               # 6 个 KPI 合并 JSON
│   └── .nojekyll
├── 数据/                       # 额外数据（标签映射等）
├── KuaiRec/                    # 全量数据集（本地，不上传）
├── 文档/                       # 项目计划 & 数据字典
└── .github/workflows/ci.yml   # CI 流水线（全量数据 → Pages）
```

## CI / CD

push 到 `main` 分支触发 GitHub Actions：

1. 从 Zenodo 下载 KuaiRec 2.0 全量数据集（~1GB）
2. 启动 Docker 集群，上传数据到 HDFS
3. 执行 Hive ETL + 6 个 KPI 计算
4. 导出 CSVs，生成 `docs/data.json`
5. 部署 `docs/` 到 GitHub Pages

手动触发（跳过 KPI 计算，使用已有结果）：GitHub → Actions → workflow_dispatch → `skip-kpi: true`

## 数据来源

[KuaiRec 2.0](https://kuairec.com/) — 快手真实用户行为数据集，收录 2020 年 7 月至 9 月的用户-视频交互数据。
