# 每日进度记录

项目周期：5.31 - 6.9

每位成员每天至少更新一次，记录已完成内容、阻塞问题和可提交材料。

## Day 1（5.31）

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 袁正泽 | 更新 `agent.md`，要求后续 Agent 在每次 git 提交前维护每日进度和成员贡献记录，减少人工手动记录成本 | 继续推进项目规则落地并检查组员提交材料是否按规范记录 | 暂无 | 各模块负责人后续提交时需同步补充本模块材料路径 | `agent.md`、`docs/daily-progress.md`、`docs/member-contribution.md` |
| 黄开轩 |  |  |  |  |  |
| 陈宇轩 |  |  |  |  |  |
| 陈文涛 |  |  |  |  |  |
| 谭张锐 |  |  |  |  |  |
| 陈文涛 | 了解项目分工，阅读项目文档熟悉监控与 Agent 模块职责 | 确认服务器环境，准备 Prometheus + Grafana 部署 | 暂无 | 暂无 | — |

## Day 2（6.1）

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 袁正泽 |  |  |  |  |  |
| 黄开轩 |  |  |  |  |  |
| 陈宇轩 |  |  |  |  |  |
| 陈文涛 | 确认项目采用服务器部署方案，获取服务器 SSH 信息（svr-1.mc.nankai.club:1919） | 连接服务器检查监控环境 | 服务器仅支持公钥认证，需手动添加公钥 | 无 | — |
| 谭张锐 |  |  |  |  |  |
| 傅昱翔 |  |  |  |  |  |

## Day 3（6.2）

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 袁正泽 |  |  |  |  |  |
| 黄开轩 |  |  |  |  |  |
| 陈宇轩 |  |  |  |  |  |
| 陈文涛 | 配置 SSH 公钥登录服务器，确认 Prometheus + Grafana + Online Boutique 已全部部署运行 | 访问 Grafana 验证 Dashboard，开始正常场景数据采集 | 首次连接 SSH 端口信息有误，已纠正 | 无 | `monitoring/prometheus/prometheus-config.yaml`、`monitoring/grafana/datasource.yaml`、`monitoring/README.md`、`agent/grafana-email-agent/.env.example` |
| 谭张锐 |  |  |  |  |  |
| 傅昱翔 |  |  |  |  |  |

## Day 4（6.3）— 已合并至 6.4

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 陈文涛 | 延续 Day 3 工作：完善监控配置文档，创建数据采集脚本 `monitoring/collect_metrics.py`（支持即时采集和范围查询两种模式，覆盖 CPU、内存、网络、Pod 状态等 8 类指标），创建 `results/metrics/` 和 `results/screenshots/` 目录 | 执行正常场景数据采集，配置 Grafana Dashboard，截图保存 | 暂无 | 确认服务器 32000 端口外部可访问（用于 Grafana） | `monitoring/collect_metrics.py`、`monitoring/README.md`（已更新为服务器环境） |

## Day 5（6.4）— 今天

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 陈文涛 | 待执行：正常场景数据采集、Grafana Dashboard 截图、邮件 Agent 开发准备 | Day 6 配合谭张锐故障注入采集异常数据 | 暂无 | 需要确认 SMTP 邮箱配置（用于 Agent 邮件发送） | — |

## Day 6（6.5）— 故障注入配合

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 陈文涛 | 配合谭张锐 ChaosMesh 故障注入实验，执行正常场景数据采集（`collect_metrics.py --label normal_20260604`），Grafana Dashboard 截图已保存 | Day 7 Agent 模块开发 | 暂无 | 无 | `results/metrics/normal_20260604_*.csv`、`results/screenshots/` Grafana 截图 |

## Day 7（6.6）— Agent 模块开发（今天）

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 陈文涛 | 完成 Agent 模块开发与测试：`agent/grafana-email-agent/agent.py`（纯标准库，无需 pip 安装）。功能闭环已验证：获取 Prometheus 13 项指标 -> 规则分析（重启/CPU/内存异常） -> 生成分析摘要 -> 输出 JSON 报告。在服务器正常运行输出报告，检测到 Pod 重启历史异常并给出建议 | Day 8 交付数据集给陈宇轩，准备报告和 PPT 内容 | SMTP 邮件发送需用户自行填入邮箱授权码 | 需确认 SMTP 邮箱配置 | `agent/grafana-email-agent/agent.py`、`results/metrics/agent_report_20260606.json` |

## Day 8（6.7）— 数据交付与报告撰写（今天）

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 陈文涛 | 创建 `docs/data-fields.md` 数据集字段说明文档（含 4 类 CSV 字段定义 + PromQL 来源 + 异常检测建议），撰写 `docs/report-monitoring.md` 监控部分报告和 `docs/report-agent.md` Agent 模块报告（含 AI 分析、功能闭环、技术实现、模块亮点），完成故障场景数据采集与仓库提交 | Day 9-10 配合袁正泽汇总报告 PPT | 暂无 | 无 | `docs/data-fields.md`、`docs/report-monitoring.md`、`docs/report-agent.md`、故障数据集 |

## Day 8 - Day 10

后续日期按同样格式追加。每天结束前，袁正泽检查是否存在阻塞项，并在群里同步第二天重点。

## Day 7（6.6）

| 成员 | 今日完成 | 明日计划 | 遇到问题 | 需要协助 | 已提交材料 |
| --- | --- | --- | --- | --- | --- |
| 谭张锐 | 1. 评论区前端视觉美化（评分统计卡片、筛选按钮、情感标签、提交表单）2. 修复 Grafana 32000 端口冲突 3. 修复 Chaos Dashboard 30960 selector 不匹配 4. 修复 Prometheus cadvisor 采集中断 5. 部署 chaos_loop v4 最终版（5种核心故障，随机3-5次，20分钟间隔）6. 更新 chaos/README.md、docs/deployment.md 等文档 | 继续监控故障注入运行状态，配合算法组数据需求 | Prometheus 历史数据因 emptyDir 重启丢失 | 算法组同学需要故障时间线数据可查看 `/tmp/chaos_timeline_v4.csv` | `chaos/README.md`、`docs/deployment.md` |

