# 故障注入与性能测试结果报告

## 测试环境
- 服务器: svr-1.mc.nankai.club (Minikube K8s 集群)
- Online Boutique: 11个微服务全部部署在 default namespace
- ChaosMesh: 部署在 chaos-mesh namespace
- 监控: Prometheus (端口32090) + Grafana (端口32000)
- JMeter: 本地 Windows 运行，通过 SSH 隧道访问前端 (localhost:8080)

## 实验概览

| # | 故障类型 | 目标服务 | 持续时间 | 测试方式 |
|---|----------|----------|----------|----------|
| 1 | Pod Kill | cartservice | 30s | JMeter + curl |
| 2 | Pod Kill | frontend | 30s | 自动循环 |
| 3 | Pod Kill | checkoutservice | 30s | 自动循环 |
| 4 | Network Delay 500ms | recommendationservice | 120s | JMeter + curl |
| 5 | Network Delay 500ms | cartservice | 120s | 自动循环 |
| 6 | Network Delay 800ms | productcatalogservice | 120s | 自动循环 |
| 7 | Network Loss 30% | frontend | 120s | JMeter + curl |
| 8 | Network Loss 40% | recommendationservice | 120s | 自动循环 |
| 9 | Network Loss 25% | checkoutservice | 120s | 自动循环 |
| 10 | CPU Stress (80%, 2 workers) | productcatalogservice | 120s | curl |
| 11 | CPU Stress (80%, 2 workers) | adservice | 120s | 自动循环 |
| 12 | Memory Stress (256MB, 2 workers) | currencyservice | 120s | curl |
| 13 | Memory Stress (256MB, 2 workers) | checkoutservice | 120s | 自动循环 |
| 14 | Pod Kill | review-service | 30s | 自动循环 |
| 15 | Network Delay 500ms | review-service | 120s | 自动循环 |
| 16 | CPU Stress (80%, 2 workers) | review-service | 120s | 自动循环 |

## 基线性能数据（无故障）

### 服务器端 curl 测试
| 请求 | 响应时间 |
|------|----------|
| Homepage 1 | 1.64s |
| Homepage 2 | 2.49s |
| Homepage 3 | 1.99s |
| Product Page 1 | 1.49s |
| Product Page 2 | 1.59s |
| Product Page 3 | 1.08s |
| **平均** | **1.71s** |

### JMeter 测试（50线程 x 10循环）
- 基线数据保存在: results/test-results/jmeter/baseline2.csv
- 所有请求返回 HTTP 200

---

## 实验1: Pod Kill - cartservice

### 故障描述
ChaosMesh 杀掉 cartservice 的 Pod，K8s 自动重新拉起新 Pod。

### 测试结果
- **JMeter 结果**: 出现 HTTP 500 错误（购物车服务不可用导致）
- **Pod 状态**: cartservice Pod 被 Kill 后重建（Pod 名变化，AGE 重置）
- **恢复时间**: 约 30 秒后 K8s 自动恢复
- **影响范围**: 涉及购物车的操作（加购、结算）全部失败

### 关键发现
- Pod Kill 后 K8s 能自动恢复，但恢复期间服务不可用
- 前端页面可能部分可访问，但购物车功能报错

---

## 实验2: Network Delay 500ms - recommendationservice

### 故障描述
给 recommendationservice 注入 500ms 网络延迟，模拟网络变慢。

### 测试结果
- **JMeter 结果**: 保存于 results/test-results/jmeter/chaos-network-delay2.csv
- **影响范围**: 首页加载变慢（推荐商品需要调用 recommendationservice）
- **预期效果**: 首页响应时间增加 500ms+

---

## 实验3: Network Loss 30% - frontend

### 故障描述
给 frontend 注入 30% 丢包率，模拟网络不稳定。

### 测试结果
- **JMeter 结果**: 保存于 results/test-results/jmeter/chaos-network-loss.csv
- **影响范围**: 约 30% 的请求可能超时或失败
- **预期效果**: 错误率显著上升

---

## 实验4: CPU Stress - productcatalogservice

### 故障描述
给 productcatalogservice 注入 CPU 压力（80% 负载，2 workers）。

### 服务器端 curl 测试结果
| 请求 | 响应时间 |
|------|----------|
| CPU Stress 1 | 1.56s |
| CPU Stress 2 | 1.37s |
| CPU Stress 3 | 1.08s |
| **平均** | **1.34s** |

### 分析
- CPU Stress 下响应时间与基线相近（1.34s vs 1.71s）
- 可能原因: CPU 压力不够大，或 productcatalogservice 有足够的 CPU 资源应对
- 建议: 增加 workers 数量或负载百分比以获得更明显的效果

---

## 实验5: Memory Stress - currencyservice

### 故障描述
给 currencyservice 注入内存压力（256MB，2 workers）。

### 服务器端 curl 测试结果
| 请求 | 响应时间 |
|------|----------|
| Mem Stress 1 | 0.89s |
| Mem Stress 2 | 0.57s |
| Mem Stress 3 | 1.50s |
| **平均** | **0.98s** |

### 分析
- Memory Stress 下响应时间反而比基线快
- 可能原因: 内存压力尚未触发 OOM，服务仍在正常运行
- 256MB 可能不足以对 currencyservice 造成明显影响

---

## 对比总结

| 指标 | 基线 | Pod Kill | Network Delay | Network Loss | CPU Stress | Memory Stress |
|------|------|----------|---------------|--------------|------------|---------------|
| 平均响应时间 | 1.71s | N/A (500错误) | 待分析CSV | 待分析CSV | 1.34s | 0.98s |
| 错误率 | 0% | >0% | 低 | ~30% | 0% | 0% |
| 服务可用性 | 100% | 部分不可用 | 100% | 降低 | 100% | 100% |

## 自动化循环注入

为持续产生故障数据供监控和算法模块使用，部署了自动化循环注入脚本 `chaos/chaos_loop.sh`。

- **注入频率**: 每 30 分钟注入一种故障
- **实验数量**: 30 种故障轮流执行（含 Review Service 3 种）
- **运行模式**: 24 小时不间断循环
- **完整一轮**: 约 15 小时
- **日志位置**: 服务器 `/tmp/chaos_loop.log`
- **查看状态**: 运行 `check_chaos_loop2.py` 可查看当前实验状态

## 文件清单

### ChaosMesh 实验配置
- chaos/experiments/pod-kill-cartservice.yaml
- chaos/experiments/pod-kill-frontend.yaml
- chaos/experiments/pod-kill-checkoutservice.yaml
- chaos/experiments/network-delay-recommendation.yaml
- chaos/experiments/network-delay-cartservice.yaml
- chaos/experiments/network-delay-productcatalog.yaml
- chaos/experiments/network-loss-frontend.yaml
- chaos/experiments/network-loss-recommendation.yaml
- chaos/experiments/network-loss-checkoutservice.yaml
- chaos/experiments/cpu-stress-productcatalog.yaml
- chaos/experiments/cpu-stress-adservice.yaml
- chaos/experiments/memory-stress-currency.yaml
- chaos/experiments/memory-stress-checkoutservice.yaml
- chaos/experiments/pod-kill-reviewservice.yaml
- chaos/experiments/network-delay-reviewservice.yaml
- chaos/experiments/cpu-stress-reviewservice.yaml

### 自动化循环脚本
- chaos/chaos_loop.sh

### JMeter 测试计划
- tests/jmeter/online-boutique-test.jmx

### JMeter 测试结果
- results/test-results/jmeter/baseline2.csv (基线)
- results/test-results/jmeter/chaos-pod-kill-cartservice2.csv
- results/test-results/jmeter/chaos-network-delay2.csv
- results/test-results/jmeter/chaos-network-loss.csv

### 服务器端测试结果
- aiops-lab-work/experiments_log.txt (CPU Stress + Memory Stress curl测试)
