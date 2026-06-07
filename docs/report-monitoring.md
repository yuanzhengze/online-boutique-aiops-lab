# 监控系统搭建与数据采集（报告内容）

负责人：陈文涛

## 1. 监控架构

本项目在 Minikube 集群中部署了 Prometheus + Grafana 监控栈，对 Online Boutique 全部 12 个微服务（含新增 Review Service）进行指标采集和可视化展示。

**部署方式**：使用 Kubernetes 原生部署，Prometheus 和 Grafana 均以 Pod 形式运行在 `monitoring` 命名空间。

**监控组件**：

| 组件 | 端口 | 用途 |
|------|------|------|
| Prometheus | 32090 (NodePort) | 时序指标采集与存储 |
| Grafana | 30960 (NodePort) | 可视化 Dashboard |
| node-exporter | — | 节点级指标（CPU、内存、磁盘） |
| kube-state-metrics | — | K8s 对象状态指标 |

## 2. Prometheus 配置

Prometheus 通过 Kubernetes Endpoint 自动发现机制，抓取 `default` 命名空间中所有 Online Boutique 服务的容器指标。核心采集指标包括：

- `container_cpu_usage_seconds_total`：容器 CPU 累计使用时间
- `container_memory_usage_bytes`：容器内存使用量
- `kube_pod_container_status_restarts_total`：Pod 重启次数
- `kube_pod_container_status_running`：容器运行状态

配置文件：`monitoring/prometheus/prometheus-config.yaml`

## 3. Grafana Dashboard

Grafana 配置了 Kubernetes 集群监控 Dashboard，展示以下面板：

- CPU 使用率 Top 5
- 内存使用 Top 5
- Pod 运行状态概览
- 重启次数统计

访问方式：通过 SSH 隧道 `ssh -L 3000:172.17.0.7:30960` 连接后，浏览器访问 `http://localhost:3000`（admin/admin）。

配置文件：`monitoring/grafana/datasource.yaml`

## 4. 数据采集流程

编写了自动化数据采集脚本 `monitoring/collect_metrics.py`，支持：

- **即时单次采集**：采集当前时刻所有指标快照
- **持续采集**：按指定时间间隔重复采集
- **时间范围导出**：导出历史时间段数据

采集脚本通过 Prometheus HTTP API 查询指标，输出为 CSV 格式，直接可用于后续算法实验。

## 5. 采集数据集

| 场景 | 时间 | 文件数 | 说明 |
|------|------|--------|------|
| 正常基准 | 6.4 / 6.7 | 8 个 CSV | 系统无故障正常运行 |
| 故障场景 | 6.7 | 4 个 CSV | ChaosMesh Pod Kill（cartservice） |
| Agent 报告 | 6.6 | 2 个 JSON | AI 分析报告 |

数据集详细字段说明见 `docs/data-fields.md`。

## 6. 关键截图

- Grafana Dashboard 全景（`results/screenshots/`）
- Prometheus Targets 采集目标（`results/screenshots/`）
