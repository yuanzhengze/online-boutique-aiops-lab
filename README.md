# 软件测试与维护大作业

本仓库用于完成软件测试与维护课程大作业。项目周期为 10 天，开发时间为 **5.31 - 6.9**。

## 项目目标

- 部署 Online Boutique 微服务系统。
- 新增 Review Service 商品评价服务，满足第三档微服务开发要求。
- 配置 Prometheus、Grafana、ChaosMesh，完成监控、可视化和故障注入。
- 使用 Selenium 和 JMeter 完成功能测试与性能测试。
- 实现 Grafana 智能分析与邮件通知 Agent 模块。
- 复现并对比至少 4 种异常检测或故障诊断论文方法。
- 完成报告、PPT、GitHub 仓库和成员贡献说明。

## 快速阅读顺序

1. `plan.md`：10 天开发计划。
2. `项目协作文档.md`：给全体成员看的协作规则。
3. `agent.md`：给 AI Agent 和后续维护者看的仓库协作指南。
4. `docs/README.md`：所有项目文档和模板索引。
5. `第三档加分项一任务规划与分工.md`：完整任务规划和成员分工。

## 成员分工

- 袁正泽：项目选题、环境搭建、Online Boutique 初始部署、项目规则制定、项目统筹。
- 黄开轩：Review Service 微服务开发、复杂系统集成、Agent 工程实现协助。
- 陈宇轩：论文复现、算法实验框架、数据预处理、多算法对比。
- 陈文涛：Prometheus、Grafana、数据采集、Grafana 邮件通知 Agent 模块。
- 谭张锐：ChaosMesh 故障注入、JMeter 性能测试、故障场景设计。
- 傅昱翔：Selenium 功能测试、新增服务功能验证、轻量论文复现辅助。

## 仓库目录

```text
docs/                 项目文档、模板、报告和 PPT 大纲
k8s/                  Kubernetes 部署文件
services/             新增微服务源码
monitoring/           Prometheus、Grafana 配置
chaos/                ChaosMesh 故障注入实验
tests/                Selenium 和 JMeter 测试
agent/                Grafana 邮件通知 Agent 模块
algorithms/           论文复现、预处理和算法对比
results/              截图、指标、测试结果和图表
slides/               展示 PPT 材料
```

## 最低可交付版本

如果时间紧张，优先保证：

- Online Boutique 可运行。
- Review Service 可部署并可通过 API 展示。
- Prometheus 和 Grafana 可展示核心指标。
- ChaosMesh 至少完成 3 类故障注入。
- Selenium 和 JMeter 至少各有一套可运行脚本。
- Agent 完成“获取数据、生成摘要、发送邮件”闭环。
- 至少 4 种论文方法或算法思路有对比结果。
- 报告和 PPT 能完整说明过程、结果、分工和加分项。

