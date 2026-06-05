# 故障注入实验记录

负责人：谭张锐

---

## 实验1: Pod Kill - cartservice

- **实验名称**: Pod Kill - cartservice
- **实验类型**: PodChaos (Pod Kill)
- **负责人**: 谭张锐
- **实验日期**: 2026-06-05
- **关联模块**: ChaosMesh 故障注入
- **配置路径**: chaos/experiments/pod-kill-cartservice.yaml

### 实验目的

验证 K8s 在 Pod 被杀掉后的自动恢复能力，以及购物车服务不可用时对系统的影响。

### 实验参数

| 参数 | 取值 | 说明 |
|------|------|------|
| 故障类型 | Pod Kill | 杀掉 Pod |
| 目标服务 | cartservice | 购物车服务 |
| 持续时间 | 30s | 故障持续时间 |
| 模式 | one | 影响1个Pod |

### 实验结果

| 指标 | 结果 | 说明 |
|------|------|------|
| 响应时间 | N/A | 返回500错误 |
| 错误率 | >0% | 购物车相关请求失败 |
| 服务可用性 | 部分不可用 | 购物车功能报错 |
| 恢复时间 | ~30s | K8s自动拉起新Pod |

### 分析结论

- Pod Kill 后 K8s 能自动恢复，但恢复期间服务不可用
- 前端页面部分可访问，但购物车功能报错
- JMeter 测试出现 HTTP 500 错误

---

## 实验2: Network Delay 500ms - recommendationservice

- **实验名称**: Network Delay - recommendationservice
- **实验类型**: NetworkChaos (Delay)
- **负责人**: 谭张锐
- **实验日期**: 2026-06-05
- **关联模块**: ChaosMesh 故障注入
- **配置路径**: chaos/experiments/network-delay-recommendation.yaml

### 实验目的

模拟推荐服务网络延迟，观察对首页加载性能的影响。

### 实验参数

| 参数 | 取值 | 说明 |
|------|------|------|
| 故障类型 | Network Delay | 网络延迟 |
| 目标服务 | recommendationservice | 推荐服务 |
| 延迟 | 500ms | 额外延迟 |
| 抖动 | 100ms | 延迟抖动 |
| 相关性 | 50% | 延迟相关性 |
| 持续时间 | 120s | 故障持续时间 |

### 实验结果

| 指标 | 结果 | 说明 |
|------|------|------|
| 响应时间 | 增加500ms+ | 首页加载变慢 |
| 错误率 | 低 | 服务仍可用 |
| 服务可用性 | 100% | 延迟但不中断 |

### 分析结论

- 推荐服务延迟导致首页加载变慢
- 服务仍可用，但用户体验下降
- JMeter 测试结果保存于 results/test-results/jmeter/chaos-network-delay2.csv

---

## 实验3: Network Loss 30% - frontend

- **实验名称**: Network Loss - frontend
- **实验类型**: NetworkChaos (Loss)
- **负责人**: 谭张锐
- **实验日期**: 2026-06-05
- **关联模块**: ChaosMesh 故障注入
- **配置路径**: chaos/experiments/network-loss-frontend.yaml

### 实验目的

模拟前端服务网络丢包，观察对系统可用性的影响。

### 实验参数

| 参数 | 取值 | 说明 |
|------|------|------|
| 故障类型 | Network Loss | 网络丢包 |
| 目标服务 | frontend | 前端服务 |
| 丢包率 | 30% | 30%请求丢失 |
| 相关性 | 50% | 丢包相关性 |
| 持续时间 | 120s | 故障持续时间 |

### 实验结果

| 指标 | 结果 | 说明 |
|------|------|------|
| 错误率 | ~30% | 约30%请求超时或失败 |
| 服务可用性 | 降低 | 部分用户无法访问 |
| 响应时间 | 不稳定 | 成功的请求响应正常 |

### 分析结论

- 30%丢包率导致约30%请求失败
- 前端服务可用性显著下降
- JMeter 测试结果保存于 results/test-results/jmeter/chaos-network-loss.csv

---

## 实验4: CPU Stress - productcatalogservice

- **实验名称**: CPU Stress - productcatalogservice
- **实验类型**: StressChaos (CPU)
- **负责人**: 谭张锐
- **实验日期**: 2026-06-05
- **关联模块**: ChaosMesh 故障注入
- **配置路径**: chaos/experiments/cpu-stress-productcatalog.yaml

### 实验目的

模拟商品目录服务 CPU 压力，观察对服务响应时间的影响。

### 实验参数

| 参数 | 取值 | 说明 |
|------|------|------|
| 故障类型 | CPU Stress | CPU压力 |
| 目标服务 | productcatalogservice | 商品目录服务 |
| CPU负载 | 80% | CPU使用率 |
| Workers | 2 | 压力线程数 |
| 持续时间 | 120s | 故障持续时间 |

### 实验结果

| 指标 | 结果 | 说明 |
|------|------|------|
| 响应时间 | 1.34s | 与基线1.71s相近 |
| 错误率 | 0% | 无错误 |
| 服务可用性 | 100% | 服务正常 |

### 分析结论

- CPU Stress 下响应时间与基线相近
- 80% CPU 负载、2 workers 不足以造成明显影响
- 建议: 增加 workers 数量或负载百分比

---

## 实验5: Memory Stress - currencyservice

- **实验名称**: Memory Stress - currencyservice
- **实验类型**: StressChaos (Memory)
- **负责人**: 谭张锐
- **实验日期**: 2026-06-05
- **关联模块**: ChaosMesh 故障注入
- **配置路径**: chaos/experiments/memory-stress-currency.yaml

### 实验目的

模拟货币转换服务内存压力，观察对服务的影响。

### 实验参数

| 参数 | 取值 | 说明 |
|------|------|------|
| 故障类型 | Memory Stress | 内存压力 |
| 目标服务 | currencyservice | 货币转换服务 |
| 内存大小 | 256MB | 压力内存大小 |
| Workers | 2 | 压力线程数 |
| 持续时间 | 120s | 故障持续时间 |

### 实验结果

| 指标 | 结果 | 说明 |
|------|------|------|
| 响应时间 | 0.98s | 反而比基线快 |
| 错误率 | 0% | 无错误 |
| 服务可用性 | 100% | 服务正常 |

### 分析结论

- Memory Stress 下响应时间反而比基线快
- 256MB 内存压力不足以触发 OOM
- 建议: 增大内存压力参数

---

## 自动化循环注入

为持续产生故障数据供监控和算法模块使用，部署了自动化循环注入脚本。

- **脚本路径**: chaos/chaos_loop.sh
- **注入频率**: 每 10 分钟注入一种故障
- **实验数量**: 13 种故障轮流执行
- **运行模式**: 24 小时不间断循环
- **完整一轮**: 约 2.2 小时

### 13 种实验列表

| # | 类型 | 目标服务 | 持续时间 |
|---|------|---------|---------|
| 1 | Pod Kill | cartservice | 30s |
| 2 | Pod Kill | frontend | 30s |
| 3 | Pod Kill | checkoutservice | 30s |
| 4 | Network Delay 500ms | recommendationservice | 120s |
| 5 | Network Delay 500ms | cartservice | 120s |
| 6 | Network Delay 800ms | productcatalogservice | 120s |
| 7 | Network Loss 30% | frontend | 120s |
| 8 | Network Loss 40% | recommendationservice | 120s |
| 9 | Network Loss 25% | checkoutservice | 120s |
| 10 | CPU Stress 80% | productcatalogservice | 120s |
| 11 | CPU Stress 80% | adservice | 120s |
| 12 | Memory Stress 256MB | currencyservice | 120s |
| 13 | Memory Stress 256MB | checkoutservice | 120s |
