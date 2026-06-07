# 监控数据集字段说明

负责人：陈文涛 | 供陈宇轩算法实验使用

## 数据集概览

本目录 `results/metrics/` 包含三类数据：

| 数据类型 | 文件名模式 | 场景 |
|----------|-----------|------|
| 正常场景 | `normal_*_2026*.csv` | 系统正常运行，无故障注入 |
| 故障场景 | `fault_*_2026*.csv` | ChaosMesh Pod Kill 故障期间 |
| Agent 报告 | `*_report_*.json` | Agent 模块自动生成的分析报告 |

---

## CSV 字段说明

### 1. cpu_usage.csv — CPU 使用率

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | string | 采集时间标签 |
| pod | string | Pod 名称 |
| namespace | string | 命名空间（default） |
| container | string | 容器名 |
| value | float | CPU 使用率（cores/s） |

**PromQL 来源**：`rate(container_cpu_usage_seconds_total{namespace="default"}[5m])`

---

### 2. memory_usage.csv — 内存使用量

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | string | 采集时间标签 |
| pod | string | Pod 名称 |
| namespace | string | 命名空间（default） |
| container | string | 容器名 |
| value | float | 内存使用量（bytes） |

**PromQL 来源**：`container_memory_usage_bytes{namespace="default"}`

---

### 3. pod_restarts.csv — Pod 重启次数

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | string | 采集时间标签 |
| pod | string | Pod 名称 |
| namespace | string | 命名空间（default） |
| container | string | 容器名 |
| value | int | 累计重启次数 |

**PromQL 来源**：`kube_pod_container_status_restarts_total{namespace="default"}`

---

### 4. container_status.csv — 容器运行状态

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | string | 采集时间标签 |
| pod | string | Pod 名称 |
| namespace | string | 命名空间（default） |
| container | string | 容器名 |
| value | int | 1=Running, 0=Not Running |

**PromQL 来源**：`kube_pod_container_status_running{namespace="default"}`

---

## 文件清单

```
results/metrics/
├── normal_20260604_container_status.csv    # 6.4 正常场景-容器状态
├── normal_20260604_cpu_usage.csv           # 6.4 正常场景-CPU
├── normal_20260604_memory_usage.csv        # 6.4 正常场景-内存
├── normal_20260604_pod_restarts.csv        # 6.4 正常场景-重启
├── normal_baseline_20260607_container_status.csv  # 6.7 正常基准
├── normal_baseline_20260607_cpu_usage.csv
├── normal_baseline_20260607_memory_usage.csv
├── normal_baseline_20260607_pod_restarts.csv
├── fault_podkill_20260607_container_status.csv    # 6.7 故障场景(Pod Kill)
├── fault_podkill_20260607_cpu_usage.csv
├── fault_podkill_20260607_memory_usage.csv
├── fault_podkill_20260607_pod_restarts.csv
├── test_0604_container_status.csv          # 6.4 测试运行
├── test_0604_cpu_usage.csv
├── test_0604_memory_usage.csv
├── test_0604_pod_restarts.csv
├── agent_report_20260606.json             # 6.6 Agent 分析报告
├── report_20260606.json                    # 6.6 Agent 运行报告
```

---

## 数据采集工具

使用 `monitoring/collect_metrics.py` 脚本，部署在服务器 `~/collect_metrics.py`：

```bash
# 即时采集
python3 ~/collect_metrics.py --label <标签>

# 持续采集 N 分钟
python3 ~/collect_metrics.py --duration 60

# 按时间范围导出
python3 ~/collect_metrics.py --start "2026-06-06T10:00:00Z" --end "2026-06-06T12:00:00Z"
```

---

## 异常检测建议指标

基于本项目数据，推荐以下异常检测方向：

1. **Pod 状态异常**：`container_status.csv` 中 value=0 的 Pod
2. **频繁重启**：`pod_restarts.csv` 中 value 显著升高的 Pod
3. **资源飙升**：对比正常/故障场景的 `cpu_usage.csv` 和 `memory_usage.csv`
4. **故障关联**：将故障注入时间点与指标变化做时间对齐分析
