# Agent 模块目录

本目录用于存放 Grafana 智能分析与邮件通知 Agent 模块。

## 子目录

- `grafana-email-agent/`：从 Grafana 或 Prometheus 获取监控数据，生成分析摘要，并通过邮件发送结果。

## 最小功能闭环

```text
获取监控指标 -> 规则分析 -> 生成摘要 -> 邮件通知
```

## 安全要求

- 不提交真实邮箱密码、SMTP 授权码、Grafana API Key。
- 使用 `.env.example` 说明配置项。
- 本地真实配置放在 `.env`，并由 `.gitignore` 排除。

