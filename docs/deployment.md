# 部署记录

用于记录 Online Boutique、Review Service、Prometheus、Grafana、ChaosMesh 等部署过程。

## 基本信息

- 负责人：谭张锐（故障注入 + Review Service）、陈文涛（监控）
- 部署环境：远程服务器 minikube（单节点）
- 服务器连接：`ssh -p 1919 collaborator@svr-1.mc.nankai.club`

## 端口映射

| 端口 | 服务 | 用途 |
|------|------|------|
| 32755 | Online Boutique 前端 | 商品页面 |
| 32180 | Review Service | 评价 API |
| 32000 | Grafana | 监控仪表盘 |
| 32090 | Prometheus | 指标采集 |
| 30960 | Chaos Mesh Dashboard | 故障注入控制台 |

## SSH 隧道命令

```bash
ssh -p 1919 -L 8080:172.17.0.7:32755 -L 32000:172.17.0.7:32000 -L 32090:172.17.0.7:32090 -L 30960:172.17.0.7:30960 -L 32180:172.17.0.7:32180 collaborator@svr-1.mc.nankai.club
```

## 关键部署信息

### Review Service
- 镜像：`review-service:0.1.0`（python:3.12-slim 基础）
- K8s Deployment：1 副本，CPU 200m / 内存 128Mi
- Service：NodePort 32180
- 健康检查：`/healthz`
- Prometheus 采集：Pod 注解 `prometheus.io/scrape=true`

### 前端集成
- 通过 ConfigMap 挂载 `product.html` 和 `review.css` 到 frontend Pod
- 评价区域包含：评分统计卡片、筛选标签、评价列表、提交表单
- 优雅降级：Review Service 不可用时显示提示，不影响商品页面

### Prometheus
- **注意**：数据目录使用 `emptyDir`（临时存储），Pod 重启后历史数据丢失
- 数据保留期：2 天（`--storage.tsdb.retention.time=2d`）
- 如需持久化，需添加 PVC

### ChaosMesh
- Namespace：`chaos-mesh`
- 当前运行脚本：`/tmp/chaos_loop_v4.sh`（v4 最终版）
- 详见 `chaos/README.md`

## 遇到的问题

| 问题 | 原因 | 解决方法 |
|------|------|---------|
| currencyservice 被 chaos_loop 杀掉未恢复 | PodKill 实验影响关键服务 | 暂停脚本，手动恢复 Pod |
| Chaos Dashboard 30960 无法访问 | Service selector 与 Pod label 不匹配 | patch Service selector |
| Grafana 32000 无法访问 | 端口被 chaos-dashboard 占用 | 重新分配端口 |
| Prometheus cadvisor 数据停止采集 | node proxy 连接断开 | rollout restart prometheus deployment |
| Prometheus 历史数据丢失 | 数据用 emptyDir 存储，Pod 重启清空 | 无法恢复，重新积累数据 |
| CSS 样式不生效 | header.html 无 link 标签引用 | 改为 style 标签内嵌到 product.html |

