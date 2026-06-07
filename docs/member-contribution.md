# 成员贡献记录

用于最终报告和展示中的成员贡献说明。每位成员在完成任务后补充证据路径。

| 成员 | 负责模块 | 主要工作 | 交付物 | 证据路径 |
| --- | --- | --- | --- | --- |
| 袁正泽 | 选题、部署、规则、统筹 | 项目选题、环境搭建、Online Boutique 初始部署、协作规则和进度管理；补充 Agent 提交前自动维护每日进度和成员贡献的协作规则 | 选型说明、部署文档、协作规则、进度记录、Agent 协作指南 | `agent.md`、`docs/daily-progress.md`、`docs/member-contribution.md` |
| 黄开轩 | 微服务开发 | Review Service 设计、实现、部署和系统集成 | 服务源码、API 文档、K8s 配置、运行截图 |  |
| 陈宇轩 | 论文复现 | 算法框架、论文复现、数据预处理和多算法对比 | 算法代码、实验图表、对比分析 |  |
| 陈文涛 | 监控与 Agent | Prometheus、Grafana 部署验证、Dashboard 配置、数据采集脚本、DeepSeek AI 邮件通知 Agent | Prometheus 配置（`monitoring/prometheus/prometheus-config.yaml`）、Grafana 数据源配置（`monitoring/grafana/datasource.yaml`）、数据采集脚本（`monitoring/collect_metrics.py`）、监控操作指南（`monitoring/README.md`）、Agent 源码（`agent/grafana-email-agent/agent.py`）、配置模板（`agent/grafana-email-agent/.env.example`）、正常/故障场景数据集 | `monitoring/` 目录、`agent/grafana-email-agent/` 目录、`results/screenshots/`、`results/metrics/`、`docs/daily-progress.md` |
| 谭张锐 | 故障注入与性能测试 + Review Service | ChaosMesh 实验（5种核心故障×随机3-5次循环注入）、JMeter 性能测试、故障场景设计、自动化循环注入脚本（v1-v4迭代）；Review Service 前端集成（评价展示、筛选标签、情感标签、提交表单、优雅降级）、前端视觉美化；运维排障（Grafana/Chaos Dashboard端口冲突、Prometheus采集中断、CSS不生效等6项） | 故障配置、测试计划、性能结果、自动化注入脚本v4、Review Service前端集成、运维排障记录 | `chaos/experiments/`、`chaos/chaos_loop_v4.sh`、`tests/jmeter/`、`services/review-service/`、`docs/deployment.md` |
| 傅昱翔 | 功能测试 | Selenium 测试、新增服务验证、轻量论文复现辅助 | 测试脚本、测试截图、测试记录 |  |

## 贡献说明写法

每位成员最终可按以下格式补充：

```text
我主要负责 XXX 模块，完成了 XXX、XXX 和 XXX。相关成果包括 XXX 文件、XXX 截图和 XXX 实验结果。在项目展示中，我负责介绍 XXX 部分。
```

