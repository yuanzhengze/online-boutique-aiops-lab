#!/usr/bin/env python3
"""
Grafana 智能分析与邮件通知 Agent 模块
========================================
功能闭环：获取监控数据 -> 规则分析 -> 生成摘要 -> 邮件通知
依赖：仅使用 Python 3 标准库，无需额外安装

使用方式：
  python3 agent.py                          # 即时分析 + 控制台输出
  python3 agent.py --send-email             # 即时分析 + 发送邮件
  python3 agent.py --range 60               # 分析最近 60 分钟数据
  python3 agent.py --output report.json     # 输出 JSON 报告
"""

import os
import sys
import json
import smtplib
import urllib.request
import urllib.error
import urllib.parse
import argparse
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timezone, timedelta

# ============================================
# 配置（可通过 .env 文件覆盖）
# ============================================

CONFIG = {
    "PROMETHEUS_URL": "http://172.17.0.7:32090",
    "SMTP_HOST": "smtp.example.com",
    "SMTP_PORT": 587,
    "SMTP_USER": "",
    "SMTP_PASSWORD": "",
    "MAIL_FROM": "",
    "MAIL_TO": "",
    "QUERY_RANGE_MINUTES": 30,
    "ERROR_RATE_THRESHOLD": 0.05,
    "LATENCY_THRESHOLD_MS": 1000,
    "CPU_THRESHOLD_PERCENT": 80,
    "MEMORY_THRESHOLD_PERCENT": 80,
}


def load_env():
    """从 .env 文件加载配置（如果存在）"""
    env_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if os.path.exists(env_file):
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    if key in CONFIG:
                        CONFIG[key] = value


# ============================================
# Prometheus 数据获取
# ============================================


def prometheus_query(query_str):
    """执行 Prometheus 即时查询"""
    url = f"{CONFIG['PROMETHEUS_URL']}/api/v1/query?query={urllib.parse.quote(query_str)}"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        if data["status"] != "success":
            return None
        return data["data"]["result"]
    except Exception as e:
        print(f"[错误] Prometheus 查询失败: {e}")
        return None


# ============================================
# 指标提取
# ============================================


def get_cpu_usage():
    """获取容器 CPU 使用率（cores/s）"""
    query = 'rate(container_cpu_usage_seconds_total{namespace="default"}[5m])'
    results = prometheus_query(query)
    if not results:
        return []
    cpu_list = []
    for r in results:
        pod = r["metric"].get("pod", "unknown")
        val = float(r["value"][1])
        cpu_list.append({"pod": pod, "cpu_cores_per_sec": round(val, 4)})
    return cpu_list


def get_memory_usage():
    """获取容器内存使用（bytes）"""
    query = 'container_memory_usage_bytes{namespace="default"}'
    results = prometheus_query(query)
    if not results:
        return []
    mem_list = []
    for r in results:
        pod = r["metric"].get("pod", "unknown")
        val = int(float(r["value"][1]))
        mem_list.append({"pod": pod, "memory_bytes": val, "memory_mb": round(val / 1024 / 1024, 2)})
    return mem_list


def get_pod_restarts():
    """获取 Pod 重启次数"""
    query = 'kube_pod_container_status_restarts_total{namespace="default"}'
    results = prometheus_query(query)
    if not results:
        return []
    restarts = []
    for r in results:
        pod = r["metric"].get("pod", "unknown")
        val = int(float(r["value"][1]))
        restarts.append({"pod": pod, "restart_count": val})
    return restarts


def get_container_status():
    """获取容器运行状态"""
    query = 'kube_pod_container_status_running{namespace="default"}'
    results = prometheus_query(query)
    if not results:
        return []
    status = []
    for r in results:
        pod = r["metric"].get("pod", "unknown")
        val = int(float(r["value"][1]))
        status.append({"pod": pod, "running": val == 1})
    return status


def get_error_rate():
    """获取 HTTP 错误率（5xx 占全部请求的比例）"""
    # 尝试通过容器级别指标间接推断（如果应用级指标未暴露）
    query = 'rate(container_network_transmit_bytes_total{namespace="default"}[5m])'
    results = prometheus_query(query)
    if not results:
        return [], "network_tx"
    net_list = []
    for r in results:
        pod = r["metric"].get("pod", "unknown")
        val = float(r["value"][1])
        net_list.append({"pod": pod, "network_tx_bytes_per_sec": round(val, 2)})
    return net_list, "network_tx"


def get_latency():
    """获取请求延迟指标（通过网络流量变化间接估计）"""
    query = 'rate(container_network_receive_bytes_total{namespace="default"}[5m])'
    results = prometheus_query(query)
    if not results:
        return [], "network_rx"
    net_list = []
    for r in results:
        pod = r["metric"].get("pod", "unknown")
        val = float(r["value"][1])
        net_list.append({"pod": pod, "network_rx_bytes_per_sec": round(val, 2)})
    return net_list, "network_rx"


def get_throughput():
    """获取服务吞吐量（通过网络总流量和 Pod 重启次数综合推断）"""
    # 使用 Pod 运行状态 + 网络活动作为吞吐量的间接指标
    query = 'kube_pod_container_status_running{namespace="default"}'
    results = prometheus_query(query)
    if not results:
        return [], 0
    running_count = sum(1 for r in results if int(float(r["value"][1])) == 1)
    total_count = len(results)
    return results, running_count


# ============================================
# 规则分析
# ============================================


def analyze_metrics(cpu_data, memory_data, restart_data, status_data, error_data, latency_data, throughput_data):
    """基于预设规则分析指标，检测异常"""
    anomalies = []
    severity = "normal"
    suggestions = []

    # 1. 检查容器运行状态
    down_pods = [s for s in status_data if not s["running"]]
    if down_pods:
        pods_str = ", ".join(s["pod"] for s in down_pods)
        anomalies.append({
            "type": "pod_down",
            "severity": "critical",
            "detail": f"Pod 未运行: {pods_str}",
        })
        severity = "critical"
        suggestions.append(f"立即检查 Pod 状态: kubectl describe pod <pod_name> -n default")

    # 2. 检查 Pod 重启
    restart_pods = [r for r in restart_data if r["restart_count"] > 0]
    if restart_pods:
        pods_str = ", ".join(f"{r['pod']}({r['restart_count']}次)" for r in restart_pods)
        anomalies.append({
            "type": "pod_restart",
            "severity": "warning",
            "detail": f"Pod 发生重启: {pods_str}",
        })
        if severity != "critical":
            severity = "warning"
        suggestions.append("检查 Pod 日志: kubectl logs <pod_name> -n default")

    # 3. 检查 CPU 使用率
    high_cpu = [c for c in cpu_data if c["cpu_cores_per_sec"] > 1.0]
    if high_cpu:
        pods_str = ", ".join(f"{c['pod']}({c['cpu_cores_per_sec']:.2f} cores/s)" for c in high_cpu)
        anomalies.append({
            "type": "high_cpu",
            "severity": "warning",
            "detail": f"CPU 使用率偏高: {pods_str}",
            "threshold": "1.0 cores/s",
        })
        if severity == "normal":
            severity = "warning"
        suggestions.append("考虑扩容或检查高负载服务")

    # 4. 检查内存使用
    high_mem = [m for m in memory_data if m["memory_mb"] > 512]
    if high_mem:
        pods_str = ", ".join(f"{m['pod']}({m['memory_mb']:.0f} MB)" for m in high_mem)
        anomalies.append({
            "type": "high_memory",
            "severity": "warning",
            "detail": f"内存使用偏高: {pods_str}",
            "threshold": "512 MB",
        })
        if severity == "normal":
            severity = "warning"
        suggestions.append("检查内存泄漏或增加内存限制")

    # 5. 检查错误率（网络发送速率异常推断）
    if error_data:
        avg_tx = sum(e["network_tx_bytes_per_sec"] for e in error_data) / len(error_data)
        if avg_tx > 50000:
            anomalies.append({
                "type": "error_rate",
                "severity": "warning",
                "detail": f"网络发送速率偏高({avg_tx:.0f} bytes/s)，可能伴随错误响应增加",
                "threshold": "50000 bytes/s",
            })
            if severity == "normal":
                severity = "warning"
            suggestions.append("检查服务日志中的 5xx 错误")

    # 6. 检查请求延迟（网络接收速率异常推断）
    if latency_data:
        avg_rx = sum(l["network_rx_bytes_per_sec"] for l in latency_data) / len(latency_data)
        if avg_rx > 100000:
            anomalies.append({
                "type": "latency",
                "severity": "warning",
                "detail": f"网络接收速率偏高({avg_rx:.0f} bytes/s)，可能请求延迟升高",
                "threshold": "100000 bytes/s",
            })
            if severity == "normal":
                severity = "warning"
            suggestions.append("排查慢查询或下游服务瓶颈")

    # 7. 检查吞吐量（可用服务数量）
    _, running_count = throughput_data
    total = len(status_data)
    if running_count < total * 0.5:
        anomalies.append({
            "type": "throughput",
            "severity": "critical",
            "detail": f"可用服务不足: {running_count}/{total} Pod 运行，吞吐量严重下降",
        })
        if severity != "critical":
            severity = "critical"
        suggestions.append("立即恢复已停止的服务")

    # 8. 综合判断
    if not anomalies:
        anomalies.append({
            "type": "all_clear",
            "severity": "info",
            "detail": "所有服务运行正常，未检测到异常指标",
        })
        suggestions.append("系统状态正常，继续例行监控")

    return anomalies, severity, suggestions


# ============================================
# 生成分析摘要
# ============================================


def generate_report(cpu_data, memory_data, restart_data, status_data, error_data, latency_data, throughput_data, anomalies, severity, suggestions):
    """生成分析报告"""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # 基本统计
    total_pods = len(status_data)
    running_pods = sum(1 for s in status_data if s["running"])
    total_restarts = sum(r["restart_count"] for r in restart_data)
    total_memory_mb = sum(m["memory_mb"] for m in memory_data)
    avg_cpu = sum(c["cpu_cores_per_sec"] for c in cpu_data) / len(cpu_data) if cpu_data else 0

    severity_map = {"critical": "严重", "warning": "警告", "normal": "正常", "info": "信息"}

    report = []
    report.append("=" * 60)
    report.append("   Online Boutique 智能运维分析报告")
    report.append("=" * 60)
    report.append(f"  生成时间:   {now}")
    report.append(f"  系统状态:   {severity_map.get(severity, severity)}")
    report.append("-" * 60)
    report.append("")
    report.append("【系统概览】")
    report.append(f"  总 Pod 数:       {total_pods}")
    report.append(f"  运行中:          {running_pods}")
    report.append(f"  未运行:          {total_pods - running_pods}")
    report.append(f"  累计重启次数:    {total_restarts}")
    report.append(f"  总内存使用:      {total_memory_mb:.0f} MB")
    report.append(f"  平均 CPU 使用:   {avg_cpu:.4f} cores/s")
    avg_tx = sum(e["network_tx_bytes_per_sec"] for e in error_data) / len(error_data) if error_data else 0
    avg_rx = sum(l["network_rx_bytes_per_sec"] for l in latency_data) / len(latency_data) if latency_data else 0
    _, running_count = throughput_data
    report.append(f"  网络发送速率:    {avg_tx:.0f} bytes/s")
    report.append(f"  网络接收速率:    {avg_rx:.0f} bytes/s")
    report.append(f"  可用服务比例:    {running_count}/{total_pods}")
    report.append("")

    if cpu_data:
        report.append("【CPU 使用 Top 5】")
        for c in sorted(cpu_data, key=lambda x: x["cpu_cores_per_sec"], reverse=True)[:5]:
            report.append(f"  {c['pod']:<40s}  {c['cpu_cores_per_sec']:.4f} cores/s")
        report.append("")

    if memory_data:
        report.append("【内存使用 Top 5】")
        for m in sorted(memory_data, key=lambda x: x["memory_mb"], reverse=True)[:5]:
            report.append(f"  {m['pod']:<40s}  {m['memory_mb']:.0f} MB")
        report.append("")

    if error_data:
        report.append("【网络发送速率（错误率参考） Top 5】")
        for e in sorted(error_data, key=lambda x: x["network_tx_bytes_per_sec"], reverse=True)[:5]:
            report.append(f"  {e['pod']:<40s}  {e['network_tx_bytes_per_sec']:.0f} bytes/s")
        report.append("")

    if latency_data:
        report.append("【网络接收速率（延迟参考） Top 5】")
        for l in sorted(latency_data, key=lambda x: x["network_rx_bytes_per_sec"], reverse=True)[:5]:
            report.append(f"  {l['pod']:<40s}  {l['network_rx_bytes_per_sec']:.0f} bytes/s")
        report.append("")

    report.append("【异常检测结果】")
    if not anomalies:
        report.append("  未检测到异常")
    else:
        for a in anomalies:
            flag = {"critical": "[严重]", "warning": "[警告]", "info": "[信息]"}.get(a["severity"], "")
            report.append(f"  {flag} {a['type']}: {a['detail']}")
    report.append("")

    if suggestions:
        report.append("【建议处理方向】")
        for i, s in enumerate(suggestions, 1):
            report.append(f"  {i}. {s}")
        report.append("")

    report.append("=" * 60)
    report.append("  报告结束 — 本报告由 Grafana 智能分析 Agent 自动生成")
    report.append("=" * 60)

    report_text = "\n".join(report)

    # 同时生成 JSON 格式
    report_json = {
        "timestamp": now,
        "severity": severity,
        "overview": {
            "total_pods": total_pods,
            "running_pods": running_pods,
            "total_restarts": total_restarts,
            "total_memory_mb": round(total_memory_mb, 2),
            "avg_cpu_cores_per_sec": round(avg_cpu, 4),
        },
        "anomalies": anomalies,
        "suggestions": suggestions,
        "cpu_top5": sorted(cpu_data, key=lambda x: x["cpu_cores_per_sec"], reverse=True)[:5],
        "memory_top5": sorted(memory_data, key=lambda x: x["memory_mb"], reverse=True)[:5],
    }

    return report_text, report_json


# ============================================
# 邮件发送
# ============================================


def send_email(report_text, report_json):
    """通过 SMTP 发送分析报告邮件"""
    smtp_host = CONFIG["SMTP_HOST"]
    smtp_port = int(CONFIG["SMTP_PORT"])
    smtp_user = CONFIG["SMTP_USER"]
    smtp_pass = CONFIG["SMTP_PASSWORD"]
    mail_from = CONFIG["MAIL_FROM"]
    mail_to = CONFIG["MAIL_TO"]

    if not smtp_host or smtp_host == "smtp.example.com":
        print("[提示] 未配置 SMTP，跳过邮件发送")
        print("       请在 .env 文件中配置 SMTP_HOST、SMTP_USER、SMTP_PASSWORD 等")
        return False

    if not mail_to:
        print("[提示] 未配置收件人 MAIL_TO，跳过邮件发送")
        return False

    severity = report_json["severity"]
    subject = f"[{severity.upper()}] Online Boutique 运维分析报告 - {datetime.now().strftime('%Y-%m-%d %H:%M')}"

    msg = MIMEMultipart()
    msg["From"] = mail_from
    msg["To"] = mail_to
    msg["Subject"] = subject
    msg.attach(MIMEText(report_text, "plain", "utf-8"))

    try:
        if smtp_port == 465:
            server = smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=30)
        else:
            server = smtplib.SMTP(smtp_host, smtp_port, timeout=30)
            server.starttls()
        server.login(smtp_user, smtp_pass)
        server.sendmail(mail_from, mail_to.split(","), msg.as_string())
        server.quit()
        print(f"[成功] 邮件已发送至: {mail_to}")
        return True
    except Exception as e:
        print(f"[错误] 邮件发送失败: {e}")
        return False


# ============================================
# 主函数
# ============================================


def main():
    load_env()

    parser = argparse.ArgumentParser(description="Grafana 智能分析与邮件通知 Agent")
    parser.add_argument("--send-email", action="store_true", help="发送邮件报告")
    parser.add_argument("--output", type=str, default=None, help="输出 JSON 报告文件路径")
    parser.add_argument("--quiet", action="store_true", help="安静模式，不打印控制台输出")
    args = parser.parse_args()

    if not args.quiet:
        print("=" * 60)
        print("  Grafana 智能分析与邮件通知 Agent")
        print(f"  Prometheus: {CONFIG['PROMETHEUS_URL']}")
        print("=" * 60)

    # Step 1: 获取监控数据
    if not args.quiet:
        print("\n[1/4] 获取监控指标...")
    cpu_data = get_cpu_usage()
    memory_data = get_memory_usage()
    restart_data = get_pod_restarts()
    status_data = get_container_status()
    error_data, _ = get_error_rate()
    latency_data, _ = get_latency()
    throughput_data = get_throughput()

    if not args.quiet:
        print(f"  CPU 指标:    {len(cpu_data)} 条")
        print(f"  内存指标:    {len(memory_data)} 条")
        print(f"  重启记录:    {len(restart_data)} 条")
        print(f"  容器状态:    {len(status_data)} 条")
        print(f"  错误率参考:  {len(error_data)} 条")
        print(f"  延迟参考:    {len(latency_data)} 条")
        print(f"  吞吐量参考:  {throughput_data[1]} Pod 运行")

    # Step 2: 规则分析
    if not args.quiet:
        print("\n[2/4] 规则分析...")
    anomalies, severity, suggestions = analyze_metrics(
        cpu_data, memory_data, restart_data, status_data,
        error_data, latency_data, throughput_data
    )

    if not args.quiet:
        for a in anomalies:
            flag = {"critical": "[严重]", "warning": "[警告]", "info": "[信息]"}.get(a["severity"], "")
            print(f"  {flag} {a['detail']}")

    # Step 3: 生成分析报告
    if not args.quiet:
        print("\n[3/4] 生成分析报告...")
    report_text, report_json = generate_report(
        cpu_data, memory_data, restart_data, status_data,
        error_data, latency_data, throughput_data,
        anomalies, severity, suggestions
    )

    print(report_text)

    # 保存 JSON 报告
    if args.output:
        os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report_json, f, ensure_ascii=False, indent=2)
        print(f"\n[JSON 报告] 已保存至: {args.output}")

    # Step 4: 发送邮件
    if args.send_email:
        if not args.quiet:
            print("\n[4/4] 发送邮件...")
        send_email(report_text, report_json)
    else:
        if not args.quiet:
            print("\n[4/4] 跳过邮件发送（使用 --send-email 启用）")


if __name__ == "__main__":
    main()
