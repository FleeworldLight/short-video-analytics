# 短视频平台内容分析系统

基于 **KuaiRec 2.0**（快手真实用户行为数据）的数据仓库 + 可视化分析系统。

## 技术栈

| 层 | 技术 |
|---|---|
| 数据存储 & 计算 | Hadoop HDFS + Hive + Spark |
| 容器编排 | Docker Compose（单节点集群） |
| 后端 API | Spring Boot 2.7（CSV 直读，无需数据库） |
| 前端可视化 | ECharts 5 + Axios |

## 架构

```
KuaiRec CSV 原始数据
    │
    ▼
┌─── ODS 层（原始数据，CSV 格式）──────────────┐
│  ods_raw_interaction / item_category / ...   │
└──────────────────┬────────────────────────────┘
                   │ 数据清洗：过滤异常、去重、衍生字段
                   ▼
┌─── DWD 层（清洗明细，ORC+Snappy）────────────┐
│  dwd_interaction_detail                      │
└──────────────────┬────────────────────────────┘
                   │ 轻度聚合
                   ▼
┌─── DWS 层（聚合数据）────────────────────────┐
│  dws_user_daily / video_daily / ...          │
└──────────────────┬────────────────────────────┘
                   │ KPI 计算
                   ▼
┌─── ADS 层（指标结果）────────────────────────┐
│  completion_rate / retention / hot_ranking   │
│  influencer / time_period_analysis           │
└──────────────────┬────────────────────────────┘
                   │ 导出 CSV → 可视化
                   ▼
           Spring Boot + ECharts 仪表盘
```

## 快速开始（无需 Docker）

### 前置条件

- JDK 21+
- Maven 3.9+

### 步骤

```bash
# 1. 进入 dashboard 模块
cd 可视化源码/dashboard

# 2. 启动（IDEA 中直接运行 DashboardApplication.main() 亦可）
mvn spring-boot:run

# 3. 打开浏览器
open http://localhost:8080
```

仪表盘直接从 `结果数据/*.csv` 加载数据，无需安装任何数据库。

> 如果 CSV 文件路径不对，修改 `application.yml` 中的 `app.data-path` 为正确路径。

## 全流程运行（需要 Docker）

完整的数据清洗 → 维度建模 → KPI 计算 → 导出流程：

```bash
cd docker
chmod +x run.sh
./run.sh
```

该脚本会自动：
1. 启动 Hadoop / Hive / Spark / MySQL 集群
2. 上传数据到 HDFS
3. 执行 HiveQL 建表 & ETL（ODS → DWD → DWS → ADS）
4. 计算 4 个 KPI + 1 个附加分析
5. 导出结果到 `结果数据/*.csv`
6. 导入到 MySQL

## KPI 说明

| KPI | 公式 | ADS 表 |
|-----|------|--------|
| **完播率**（按类别） | `SUM(completion_flag) / COUNT(*)` | `ads_completion_rate_by_category` |
| **完播率**（按创作者） | `AVG(completion_flag)` | `ads_completion_rate_by_author` |
| **用户留存率**（日/7日/30日） | `留存用户 / 当日活跃用户` | `ads_user_retention` |
| **内容热度排行** | `completion_flag×0.35 + watch_ratio×0.25 + LOG(play_count+1)×0.20 + like_flag×0.20` | `ads_content_hot_ranking` |
| **创作者影响力指数** | `avg_completion×0.3 + avg_like×0.3 + LOG(play_count+1)×0.4` | `ads_influencer_index` |
| **时段播放分析** | 按 6 个时段聚合播放量 | `ads_time_period_analysis` |

## 项目结构

```
├── docker/
│   ├── docker-compose.yml      # 9 个容器 + 4 个卷
│   └── run.sh                  # 一键全流程
├── 脚本/
│   └── *.hql / *.sh            # HiveQL ETL + KPI 脚本
├── 可视化源码/
│   ├── preview.html            # 纯前端预览（mock 数据）
│   └── dashboard/              # Spring Boot 后端 + ECharts 前端
│       └── src/main/
│           ├── java/.../controller/   # REST API（6 个端点）
│           ├── java/.../service/      # CSV 数据加载
│           ├── java/.../model/        # 6 个 POJO
│           └── resources/static/      # ECharts 仪表盘页面
├── 结果数据/                   # KPI 计算结果 CSV
├── 数据样例/                   # KuaiRec 2.0 样本（前 100 行）
└── 文档/
    └── 项目计划.md             # 完整实施计划 & 数据字典
```

## 数据来源

[KuaiRec 2.0](https://kuairec.com/) — 快手真实用户行为数据集，收录 2020 年 7 月至 9 月的用户-视频交互数据。

## 许可证

MIT
