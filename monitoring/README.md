# 监控配置目录

本目录用于存放 Prometheus、Grafana 和 Dashboard 相关配置。

## 子目录

- `prometheus/`：Prometheus 配置、ServiceMonitor 或查询说明。
- `grafana/`：Grafana 配置。
- `grafana/dashboards/`：Dashboard JSON 或截图说明。

## 交付要求

- Prometheus 能采集核心服务指标。
- Grafana 能展示 CPU、内存、请求延迟、错误率、吞吐量等指标。
- 记录 Grafana API 或 Prometheus 查询接口，供 Agent 模块调用。

