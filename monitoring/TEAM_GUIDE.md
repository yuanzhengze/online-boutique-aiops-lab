# 监控与 Agent 模块使用指南

陈文涛负责模块：Prometheus 监控、Grafana Dashboard、数据采集、Agent 邮件通知。

## 1. 登录服务器

首先需要将你的 SSH 公钥添加到服务器，联系陈文涛或服务器管理员。

```powershell
ssh -p 1919 collaborator@svr-1.mc.nankai.club
```

## 2. 访问 Grafana（监控面板）

**方式一：SSH 隧道（推荐）**
```powershell
ssh -p 1919 -L 3000:172.17.0.7:30960 collaborator@svr-1.mc.nankai.club
```
浏览器打开 `http://localhost:3000`，用户名 `admin`，密码 `admin`

**方式二：Prometheus 直接查询**
```powershell
ssh -p 1919 -L 9090:172.17.0.7:32090 collaborator@svr-1.mc.nankai.club
```
浏览器打开 `http://localhost:9090`，可执行 PromQL 查询

## 3. 运行数据采集（供算法实验用）

SSH 登录服务器后：
```bash
# 即时采集一次
python3 ~/collect_metrics.py --label normal_20260606

# 持续采集 60 分钟
python3 ~/collect_metrics.py --duration 60

# 采集指定时间范围
python3 ~/collect_metrics.py --start "2026-06-06T10:00:00Z" --end "2026-06-06T12:00:00Z"
```
数据保存在 `results/metrics/` 目录。

## 4. 运行 Agent（智能分析 + 邮件通知）

SSH 登录服务器后：
```bash
# 控制台输出分析报告
python3 ~/agent.py

# 分析 + 保存 JSON 报告
python3 ~/agent.py --output report.json

# 分析 + 发送邮件（需在 ~/.env 中配置 SMTP）
python3 ~/agent.py --send-email
```

## 5. 下载数据到本地

```powershell
# 下载所有监控数据
scp -P 1919 collaborator@svr-1.mc.nankai.club:results/metrics/*.csv "你的本地目录\"

# 下载 Agent 报告
scp -P 1919 collaborator@svr-1.mc.nankai.club:~/agent_report.json "你的本地目录\"
```

## 6. 服务地址汇总

| 服务 | 内部地址 | 本地隧道 |
|------|----------|----------|
| Grafana | 172.17.0.7:30960 | ssh -L 3000:172.17.0.7:30960 |
| Prometheus | 172.17.0.7:32090 | ssh -L 9090:172.17.0.7:32090 |
| Prometheus API | http://172.17.0.7:32090/api/v1/query | — |

## 7. Agent 模块文件位置

| 文件 | 服务器路径 | 说明 |
|------|-----------|------|
| agent.py | `~/agent.py` | Agent 主脚本 |
| collect_metrics.py | `~/collect_metrics.py` | 数据采集脚本 |
| .env | `~/.env` | Agent 邮件配置（含授权码，勿外泄） |
| 数据文件 | `~/results/metrics/` | 采集的监控数据 |
