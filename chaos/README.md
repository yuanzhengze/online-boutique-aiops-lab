# 故障注入目录

本目录用于存放 ChaosMesh 故障注入实验配置和记录。

## 子目录

- `experiments/`：Pod Kill、Network Delay、Network Loss、CPU Stress、Memory Stress 等实验配置。

## 实验覆盖

共 5 大类 16 种故障注入实验，覆盖 Online Boutique 原始 11 个微服务及新增 Review Service：

| 类别 | 实验数 | 目标服务 |
|------|--------|---------|
| Pod Kill | 6 | cartservice, frontend, checkoutservice, emailservice, redis-cart, **review-service** |
| Network Delay | 4 | recommendationservice, cartservice, productcatalogservice, **review-service** |
| Network Loss | 3 | frontend, recommendationservice, checkoutservice |
| CPU Stress | 3 | productcatalogservice, adservice, **review-service** |
| Memory Stress | 2 | currencyservice, checkoutservice |

此外还有渐进式、复合、HTTP 层、时钟故障等扩展实验。

## 自动化脚本

- `chaos_loop.sh`：24 小时自动化循环注入，核心故障各 3 次/轮，配合 Prometheus 快照采集

## 记录要求

每次实验需要记录：

- 故障类型。
- 注入对象。
- 开始时间和结束时间。
- 对系统的影响。
- 对应 Grafana 截图或 Prometheus 数据。
- 是否被算法或 Agent 模块识别。

