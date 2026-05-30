# Agent 协作指南

## 1. 目的

本文档用于帮助 AI Agent 和项目成员快速理解本仓库的目标、目录、任务边界和协作方式。任何 Agent 进入本仓库后，应先阅读本文档，再阅读 `plan.md` 和 `项目协作文档.md`。

本仓库服务于“软件测试与维护”大作业，核心目标是在 10 天内完成一个可展示、可提交、可复现的微服务测试与维护项目。

## 2. 项目核心目标

本项目需要完成：

- 部署 Online Boutique 微服务系统。
- 新增 Review Service 商品评价服务，满足第三档微服务开发要求。
- 配置 Prometheus 和 Grafana，实现指标采集与可视化。
- 使用 ChaosMesh 进行故障注入。
- 使用 Selenium 和 JMeter 进行功能测试与性能测试。
- 实现 Grafana 智能分析与邮件通知 Agent 模块。
- 复现并对比至少 4 种异常检测或故障诊断论文方法。
- 形成 GitHub 仓库、PDF 报告、展示 PPT 和成员贡献说明。

## 3. 优先阅读顺序

Agent 开始工作前，按以下顺序阅读文档：

1. `agent.md`：理解仓库协作规则和 Agent 工作方式。
2. `plan.md`：理解 10 天排期、每日目标、负责人和验收标准。
3. `项目协作文档.md`：理解成员分工、提交规范、命名规范和材料要求。
4. `第三档加分项一任务规划与分工.md`：理解完整任务背景和评分目标。
5. `软件测试与维护（2026年春）大作业要求.md`：核对课程要求和提交标准。

## 4. 成员与模块边界

- 袁正泽：项目选题、环境搭建、Online Boutique 初始部署、项目规则制定、项目统筹。
- 黄开轩：Review Service 微服务开发、复杂系统集成、Agent 工程实现协助。
- 陈宇轩：论文复现、算法实验框架、数据预处理、多算法对比。
- 陈文涛：Prometheus、Grafana、数据采集、Grafana 邮件通知 Agent 模块。
- 谭张锐：ChaosMesh 故障注入、JMeter 性能测试、故障场景设计。
- 傅昱翔：Selenium 功能测试、新增服务功能验证、轻量论文复现辅助。

Agent 修改内容时，应尽量遵守模块边界，不要把一个成员负责的内容随意转移给其他成员，除非用户明确要求重新分工。

## 5. 推荐仓库结构

后续代码和材料建议按以下结构组织：

```text
project-root/
├── README.md
├── agent.md
├── plan.md
├── docs/
│   ├── deployment.md
│   ├── collaboration.md
│   ├── member-contribution.md
│   └── report-draft.md
├── k8s/
│   ├── online-boutique/
│   └── review-service/
├── services/
│   └── review-service/
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── dashboards/
├── chaos/
│   └── experiments/
├── tests/
│   ├── selenium/
│   └── jmeter/
├── agent/
│   └── grafana-email-agent/
├── algorithms/
│   ├── preprocessing/
│   ├── paper-baseline/
│   └── comparison/
├── results/
│   ├── screenshots/
│   ├── metrics/
│   ├── test-results/
│   └── figures/
└── slides/
```

如果当前仓库尚未创建这些目录，Agent 可以在具体实现任务需要时再创建，避免提前生成空目录。

## 6. Agent 工作原则

### 保持任务闭环

每次修改应尽量形成明确闭环：

- 修改了什么。
- 为什么修改。
- 影响哪些文件。
- 是否需要后续人工补充。
- 是否已经检查格式或可运行性。

### 优先最小可用版本

本项目周期较短，Agent 应优先帮助完成可展示的最小闭环：

- Review Service 能运行和调用。
- Prometheus/Grafana 能展示指标。
- ChaosMesh 能制造故障。
- Selenium/JMeter 有可运行脚本。
- Agent 模块能完成“获取数据 -> 分析 -> 发邮件”。
- 算法复现能产出对比结果。

### 不做无关重构

除非用户明确要求，不要进行与当前任务无关的大规模重构、目录搬迁或文风重写。

### 保留可复现证据

涉及部署、测试、实验、算法、Agent 邮件通知的任务，都应提醒或帮助保留：

- 命令记录。
- 配置文件。
- 截图。
- 日志。
- 输出结果。
- 实验参数。

## 7. 文档规范

Markdown 文档应遵守：

- 标题层级清晰。
- 使用中文说明。
- 文件名和路径用反引号包裹。
- 任务、交付物、验收标准分开写。
- 避免空泛描述，尽量写可检查结果。

推荐文档结构：

```markdown
# 标题

## 背景

## 目标

## 分工

## 步骤

## 交付物

## 验收标准

## 风险与应对
```

## 8. 代码与脚本规范

如果后续添加代码或脚本，应遵守：

- 每个模块有简短 README 或运行说明。
- 脚本参数、环境变量和依赖要写清楚。
- 不硬编码个人邮箱密码、Token、Cookie、API Key 等敏感信息。
- 敏感配置使用环境变量或 `.env.example` 示例文件。
- 不提交真实密码、真实邮箱授权码、私钥或个人凭据。
- 生成结果应输出到 `results/` 对应目录。

## 9. Agent 模块实现约定

Grafana 智能分析与邮件通知 Agent 模块放在：

```text
agent/grafana-email-agent/
```

建议实现最小闭环：

```text
读取 Grafana/Prometheus 指标
-> 提取关键指标
-> 按规则分析异常
-> 生成摘要
-> 发送邮件
```

建议输入：

- Grafana API 地址或 Prometheus API 地址。
- 查询时间范围。
- 指标名称。
- 邮件收件人。
- SMTP 配置。

建议输出：

- 控制台日志。
- 邮件发送结果。
- 分析摘要文本。
- 可选 JSON 结果文件。

邮件内容建议包含：

- 系统当前状态。
- 异常指标。
- 异常时间段。
- 可能影响。
- 建议处理方向。

如果 Grafana API 不稳定，可改用 Prometheus API 或已导出的 CSV/JSON 数据。

## 10. 测试与实验规范

每个实验建议记录：

```text
实验名称：
负责人：
实验时间：
实验环境：
输入数据：
操作步骤：
关键结果：
截图或日志路径：
遇到的问题：
```

实验结果优先保存到：

```text
results/metrics/
results/test-results/
results/figures/
results/screenshots/
```

## 11. Git 协作建议

如果用户要求提交代码，提交信息建议使用：

```text
类型: 简短说明
```

常用类型：

- `deploy`：部署相关。
- `service`：微服务开发相关。
- `monitor`：监控与数据采集相关。
- `agent`：Grafana 邮件通知 Agent 相关。
- `test`：Selenium、JMeter 测试相关。
- `chaos`：ChaosMesh 故障注入相关。
- `algo`：论文复现和算法实验相关。
- `docs`：文档、报告、PPT 相关。

示例：

```text
agent: add grafana email analysis workflow
docs: update 10 day project plan
monitor: document prometheus query endpoints
```

## 12. Agent 回复用户时的要求

Agent 应使用中文回复用户。

完成任务后，应简要说明：

- 新增或修改了哪些文件。
- 主要内容是什么。
- 是否做了检查。
- 还剩哪些需要用户或组员补充。

如果任务涉及实现代码，尽量说明如何运行或验证。

## 13. 当前关键文件

- `plan.md`：10 天开发计划。
- `项目协作文档.md`：给组员看的协作规则。
- `第三档加分项一任务规划与分工.md`：完整任务规划和分工。
- `软件测试与维护（2026年春）大作业要求.md`：课程原始要求。
- `agent.md`：Agent 协作入口文档。

