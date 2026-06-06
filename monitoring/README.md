# 监控配置目录

## 服务器信息

| 项目 | 信息 |
|------|------|
| 服务器 | `svr-1.mc.nankai.club`（SSH 端口 1919） |
| 用户 | `collaborator` |
| Minikube IP | 172.17.0.7 |
| K8s 版本 | v1.30.0 |

## 当前部署状态（已完成）

| 组件 | 命名空间 | 内部端口 | NodePort | 状态 |
|------|----------|----------|----------|------|
| Prometheus | monitoring | 9090 | 32090 | Running |
| Grafana | monitoring | 3000 | 32000 | Running |
| node-exporter | monitoring | 9100 | - | Running |
| kube-state-metrics | monitoring | 8080 | - | Running |
| ChaosMesh | chaos-mesh | - | - | Running |
| Online Boutique | default | - | - | 全部 11 服务 Running |
| Review Service | default | - | - | Running |

---

## 日常操作指南

### 1. 登录服务器

```powershell
ssh -p 1919 collaborator@svr-1.mc.nankai.club
```

### 2. 访问 Grafana

**方式一：SSH 隧道（推荐，本机即可访问）**
```powershell
ssh -p 1919 -L 3000:172.17.0.7:32000 collaborator@svr-1.mc.nankai.club
```
然后浏览器打开 `http://localhost:3000`

**方式二：直接访问服务器**
浏览器打开 `http://svr-1.mc.nankai.club:32000`（如果防火墙允许）

> 用户名：`admin`，密码在服务器上获取

### 3. 获取 Grafana 密码

```bash
kubectl get secret -n monitoring grafana-secret -o jsonpath='{.data.admin-password}' | base64 -d
```

### 4. 访问 Prometheus

```powershell
# SSH 隧道
ssh -p 1919 -L 9090:172.17.0.7:32090 collaborator@svr-1.mc.nankai.club
```
浏览器打开 `http://localhost:9090`

### 5. 检查服务状态

```bash
# 检查所有 Pod
kubectl get pods -A

# 检查监控 Pod
kubectl get pods -n monitoring

# 检查 Online Boutique
kubectl get pods -n default
```

### 6. 查看 Prometheus 采集目标

```bash
# SSH 到服务器后
kubectl exec -n monitoring prometheus-564f4bb9bb-4xfdk -- wget -qO- 'http://localhost:9090/api/v1/targets' | python3 -m json.tool | grep -E '"job"|"health"|"instance"'
```

---

## Grafana API 地址（供 Agent 模块使用）

Agent 模块在服务器上本地运行时：
```
GRAFANA_URL=http://172.17.0.7:32000
```

Agent 模块在本机运行时（需先建立 SSH 隧道）：
```
GRAFANA_URL=http://localhost:3000
```

---

## Prometheus API 地址（供 Agent 模块和数据导出使用）

```
PROMETHEUS_URL=http://172.17.0.7:32090
```

### 常用 PromQL 查询

```promql
# CPU 使用率
rate(container_cpu_usage_seconds_total[5m])

# 内存使用
container_memory_usage_bytes

# Pod 重启次数
kube_pod_container_status_restarts_total

# 网络流量
rate(container_network_receive_bytes_total[5m])

# 文件系统使用
container_fs_usage_bytes
```

### 数据导出示例

```bash
# 在服务器上执行，导出为 CSV
curl -s 'http://172.17.0.7:32090/api/v1/query_range?query=rate(container_cpu_usage_seconds_total[5m])&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data['data']['result']:
    print(r['metric'].get('pod','unknown'), r['values'][-1][1])
"
```

---

## 交付要求

- [x] Prometheus 配置完成（已部署）
- [x] Grafana 部署完成（已部署）
- [ ] Grafana Dashboard 配置（需要配置展示面板）
- [ ] 正常场景数据采集
- [ ] 故障场景数据采集（配合 Day 6 谭张锐）
- [ ] Agent 模块开发（Day 7）
- [ ] 监控与 Agent 报告内容和 PPT 页面
