# Grafana 智能分析与邮件通知 Agent（报告内容）

负责人：陈文涛

## 1. 模块定位

实现一个轻量级智能运维 Agent，自动从 Prometheus 获取监控指标，通过 DeepSeek AI 大模型进行智能分析，并邮件通知运维人员，形成完整的"监控→分析→通知"闭环。

## 2. 功能闭环

```
获取 Prometheus 指标 → DeepSeek AI 智能分析 → 生成报告 → 邮件通知
```

- **Step 1**：通过 HTTP API 从 Prometheus 拉取 CPU、内存、Pod 状态、重启次数等 7 类指标
- **Step 2**：将监控数据发送至 DeepSeek `deepseek-v4-flash` 模型，由 AI 进行专业 SRE 分析
- **Step 3**：生成结构化分析报告（控制台文本 + JSON）
- **Step 4**：通过 QQ 邮箱 SMTP 自动发送报告邮件

## 3. 技术实现

| 技术点 | 方案 |
|--------|------|
| 编程语言 | Python 3（仅使用标准库，零外部依赖） |
| 数据获取 | `urllib` 调用 Prometheus HTTP API |
| AI 分析 | DeepSeek API（`deepseek-v4-flash` 模型） |
| 邮件发送 | `smtplib` + QQ SMTP（STARTTLS） |
| 回退机制 | AI 不可用时自动切换本地规则分析 |
| 定时运行 | `--interval` 参数，支持后台持续巡检 |

源码文件：`agent/grafana-email-agent/agent.py`

## 4. AI 分析能力

相比固定规则，DeepSeek AI 能提供：

- **上下文理解**：不仅列出异常，还分析关联关系（如重启与 OOMKilled 的因果）
- **专业建议**：给出具体的排查步骤和修复方向（如"区分 CrashLoopBackOff 和 OOMKilled"）
- **多维度综合判断**：同时考虑 CPU、内存、Pod 状态、重启次数进行综合评级

实测 AI 分析示例输出：
> [严重] Pod 未运行 1 个，影响系统完整性
> [严重] 累计重启 758 次，其中 paymentservice 279 次、adservice 222 次，建议检查资源限制和应用日志

## 5. 邮件通知

邮件标题按严重等级分级：`[CRITICAL]` / `[WARNING]` / `[NORMAL]`

邮件正文包含：
- 系统概览（Pod 数、运行状态、资源使用量）
- CPU/内存 Top 5 排行
- 异常检测结果（异常类型 + 严重等级 + 详细描述）
- 运维建议处理方向

## 6. 运行部署

Agent 部署在项目服务器上，以 8 小时为间隔后台运行：

```bash
# 单次运行
python3 ~/agent.py

# 定时运行（每 480 分钟）
nohup python3 ~/agent.py --interval 480 --send-email --quiet > ~/agent.log 2>&1 &
```

配置文件 `~/.env` 管理敏感信息（API Key、邮箱授权码），已通过 `.gitignore` 排除。

## 7. 关键技术证据

| 证据类型 | 路径 |
|----------|------|
| Agent 源码 | `agent/grafana-email-agent/agent.py` |
| 配置模板 | `agent/grafana-email-agent/.env.example` |
| 分析报告 JSON | `results/metrics/agent_report_20260606.json` |
| 邮件截图 | `results/screenshots/` |
| 团队使用指南 | `monitoring/TEAM_GUIDE.md` |

## 8. 模块亮点

- **零依赖**：仅用 Python 3 标准库，无需 pip install
- **AI 驱动**：集成 DeepSeek 大模型，分析质量远超固定规则
- **高可用**：AI 不可用时自动回退本地规则，不影响基本功能
- **隐私保护**：敏感配置（API Key、邮箱密码）通过 .env 和 .gitignore 管理
- **定时调度**：支持后台持续巡检和自动邮件通知
