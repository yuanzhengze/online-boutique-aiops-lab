# 故障注入目录

本目录用于存放 ChaosMesh 故障注入实验配置和记录。

## 子目录

- `experiments/`：Pod Kill、Network Delay、Network Loss、CPU Stress、Memory Stress 等实验配置。

## 当前运行方案（v4 最终版）

5 种核心故障，每种随机 3-5 次/轮，串行注入（同一时间只有一个实验），间隔 20 分钟，24 小时循环。

| 序号 | 故障类型 | YAML 文件 | 目标服务 | 持续时间 |
|------|---------|-----------|---------|---------|
| 1 | PodKill | `pod-kill-cartservice.yaml` | cartservice | 30s |
| 2 | NetworkDelay 500ms | `network-delay-recommendation.yaml` | recommendationservice | 120s |
| 3 | NetworkLoss 30% | `network-loss-frontend.yaml` | frontend | 120s |
| 4 | CPUStress | `cpu-stress-productcatalog.yaml` | productcatalogservice | 120s |
| 5 | MemoryStress | `memory-stress-currency.yaml` | currencyservice | 120s |

### 服务器端文件位置

| 文件 | 服务器路径 | 说明 |
|------|-----------|------|
| 实验YAML | `/tmp/chaos-yamls/` | 所有故障注入配置 |
| v4脚本 | `/tmp/chaos_loop_v4.sh` | 当前运行的自动化脚本 |
| 时间线CSV | `/tmp/chaos_timeline_v4.csv` | 每次注入的精确起止时间 |
| 运行日志 | `/tmp/chaos_loop_v4.log` | 详细运行日志 |

### 时间线 CSV 格式

```csv
experiment,start_time,end_time,start_epoch,end_epoch,status
pod-kill-cartservice,2026-06-06T23:15:37+08:00,2026-06-06T23:17:15+08:00,1780758937,1780759035,success
```

- `start_epoch` / `end_epoch`：Unix 时间戳（秒），用于与 Prometheus 数据对齐
- 算法组同学可用此文件精确匹配故障时段的监控数据

### 操作命令

```bash
# 查看运行状态
ps aux | grep chaos_loop | grep -v grep

# 查看时间线
cat /tmp/chaos_timeline_v4.csv

# 查看日志
tail -20 /tmp/chaos_loop_v4.log

# 查看当前活跃实验
kubectl get podchaos,networkchaos,stresschaos -A

# 停止脚本
pkill -f chaos_loop_v4

# 重新启动
nohup bash /tmp/chaos_loop_v4.sh > /tmp/chaos_loop_v4.log 2>&1 &
```

## 扩展实验（已配置但未在 v4 中使用）

`experiments/` 目录下还包含以下扩展实验配置，如需使用可手动 `kubectl apply`：

- 渐进式：Loss 10%/50%、Delay 200ms/1000ms
- 复合故障：Delay+CPU、PodKill+Delay、Mem+Loss
- HTTP层：Abort、Delay、Error503
- 时钟故障：TimeSkew ±5s/10s
- Review Service：PodKill、NetworkDelay、CPUStress

## 记录要求

每次实验需要记录：

- 故障类型。
- 注入对象。
- 开始时间和结束时间。
- 对系统的影响。
- 对应 Grafana 截图或 Prometheus 数据。
- 是否被算法或 Agent 模块识别。

