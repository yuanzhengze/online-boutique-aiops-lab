# 监控数据采集脚本
# 用途：从 Prometheus 采集 Online Boutique 指标数据，供 Agent 模块和算法实验使用
# 使用方式：
#   正常场景：python3 collect_metrics.py --duration 60
#   指定时间范围：python3 collect_metrics.py --start "2026-06-04T10:00:00Z" --end "2026-06-04T11:00:00Z"

import urllib.request
import urllib.error
import urllib.parse
import json
import csv
import argparse
import os
from datetime import datetime, timezone, timedelta

# ============================================
# 配置
# ============================================

# 服务器上运行：http://172.17.0.7:32090
# 本机运行（SSH 隧道后）：http://localhost:9090
PROMETHEUS_URL = os.environ.get("PROMETHEUS_URL", "http://172.17.0.7:32090")

OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "results/metrics")

# 需要采集的指标定义
QUERIES = {
    "cpu_usage": {
        "query": 'rate(container_cpu_usage_seconds_total{namespace="default"}[5m])',
        "description": "CPU 使用率 (cores/s)",
        "filename": "cpu_usage.csv",
    },
    "memory_usage": {
        "query": 'container_memory_usage_bytes{namespace="default"}',
        "description": "内存使用量 (bytes)",
        "filename": "memory_usage.csv",
    },
    "network_rx": {
        "query": 'rate(container_network_receive_bytes_total{namespace="default"}[5m])',
        "description": "网络接收速率 (bytes/s)",
        "filename": "network_rx.csv",
    },
    "network_tx": {
        "query": 'rate(container_network_transmit_bytes_total{namespace="default"}[5m])',
        "description": "网络发送速率 (bytes/s)",
        "filename": "network_tx.csv",
    },
    "pod_restarts": {
        "query": 'kube_pod_container_status_restarts_total{namespace="default"}',
        "description": "Pod 重启次数",
        "filename": "pod_restarts.csv",
    },
    "filesystem_usage": {
        "query": 'container_fs_usage_bytes{namespace="default"}',
        "description": "文件系统使用量 (bytes)",
        "filename": "filesystem_usage.csv",
    },
    "container_status": {
        "query": 'kube_pod_container_status_running{namespace="default"}',
        "description": "容器运行状态 (1=Running)",
        "filename": "container_status.csv",
    },
    "http_requests": {
        "query": 'http_requests_total{namespace="default"}',
        "description": "HTTP 请求总数（如有暴露）",
        "filename": "http_requests.csv",
    },
}

# ============================================
# 数据采集函数
# ============================================


def _prometheus_get(url, timeout=30):
    """向 Prometheus API 发送 GET 请求"""
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.URLError as e:
        raise Exception(f"连接失败: {e.reason}")
    except Exception as e:
        raise Exception(f"{e}")


def query_prometheus_instant(query_str):
    """执行 Prometheus 即时查询"""
    url = f"{PROMETHEUS_URL}/api/v1/query?query={urllib.parse.quote(query_str)}"
    try:
        data = _prometheus_get(url)
        if data["status"] != "success":
            print(f"  [错误] 查询失败: {data.get('error', 'unknown')}")
            return []
        return data["data"]["result"]
    except Exception as e:
        print(f"  [错误] 无法连接 Prometheus ({PROMETHEUS_URL}): {e}")
        return []


def query_prometheus_range(query_str, start, end, step="15s"):
    """执行 Prometheus 范围查询"""
    url = (
        f"{PROMETHEUS_URL}/api/v1/query_range"
        f"?query={urllib.parse.quote(query_str)}"
        f"&start={urllib.parse.quote(start)}"
        f"&end={urllib.parse.quote(end)}"
        f"&step={urllib.parse.quote(step)}"
    )
    try:
        data = _prometheus_get(url, timeout=60)
        if data["status"] != "success":
            print(f"  [错误] 范围查询失败: {data.get('error', 'unknown')}")
            return []
        return data["data"]["result"]
    except Exception as e:
        print(f"  [错误] 范围查询失败: {e}")
        return []


def collect_instant_metrics(output_dir, timestamp_label):
    """采集即时指标并保存为 CSV"""
    os.makedirs(output_dir, exist_ok=True)

    summary = {}
    for name, config in QUERIES.items():
        print(f"  采集 [{name}]: {config['description']}...")
        results = query_prometheus_instant(config["query"])

        if not results:
            print(f"    无数据（指标可能未暴露）")
            continue

        # 保存为 CSV
        filepath = os.path.join(output_dir, f"{timestamp_label}_{config['filename']}")
        with open(filepath, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["timestamp", "pod", "namespace", "container", "value"])
            for r in results:
                metric = r["metric"]
                pod = metric.get("pod", metric.get("exported_pod", "unknown"))
                ns = metric.get("namespace", "unknown")
                container = metric.get("container", "unknown")
                value = r["value"][1]
                writer.writerow([timestamp_label, pod, ns, container, value])

        record_count = len(results)
        print(f"    -> {filepath} ({record_count} 条记录)")
        summary[name] = record_count

    return summary


def collect_range_metrics(output_dir, start, end, step="15s"):
    """采集时间范围内的指标（供算法实验用）"""
    os.makedirs(output_dir, exist_ok=True)
    label = f"{start.replace(':', '')}_{end.replace(':', '')}"

    summary = {}
    range_queries = {
        "cpu_usage_range": {
            "query": 'rate(container_cpu_usage_seconds_total{namespace="default"}[5m])',
            "description": "CPU 使用率时序",
            "filename": f"{label}_cpu_timeseries.json",
        },
        "memory_usage_range": {
            "query": 'container_memory_usage_bytes{namespace="default"}',
            "description": "内存使用量时序",
            "filename": f"{label}_memory_timeseries.json",
        },
    }

    for name, config in range_queries.items():
        print(f"  采集 [{name}]: {config['description']}...")
        results = query_prometheus_range(config["query"], start, end, step)

        if not results:
            print(f"    无数据")
            continue

        filepath = os.path.join(output_dir, config["filename"])
        with open(filepath, "w") as f:
            json.dump(results, f, indent=2)

        record_count = sum(len(r.get("values", [])) for r in results)
        print(f"    -> {filepath} ({record_count} 个数据点)")
        summary[name] = record_count

    return summary


# ============================================
# 主函数
# ============================================


def main():
    parser = argparse.ArgumentParser(description="Online Boutique 监控数据采集工具")
    parser.add_argument(
        "--duration",
        type=int,
        default=0,
        help="采集持续时间（分钟），0 表示即时单次采集",
    )
    parser.add_argument(
        "--start",
        type=str,
        default=None,
        help="范围查询起始时间 (ISO 8601 格式，如 2026-06-04T10:00:00Z)",
    )
    parser.add_argument(
        "--end",
        type=str,
        default=None,
        help="范围查询结束时间 (ISO 8601 格式)",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=OUTPUT_DIR,
        help=f"输出目录 (默认: {OUTPUT_DIR})",
    )
    parser.add_argument(
        "--label",
        type=str,
        default=None,
        help="采集标签 (默认使用时间戳)",
    )
    parser.add_argument(
        "--prometheus",
        type=str,
        default=PROMETHEUS_URL,
        help=f"Prometheus URL (默认: {PROMETHEUS_URL})",
    )

    args = parser.parse_args()

    prom_url = args.prometheus
    out_dir = args.output

    now = datetime.now(timezone.utc)
    label = args.label or now.strftime("normal_%Y%m%d_%H%M%S")

    print("=" * 60)
    print("Online Boutique 监控数据采集")
    print(f"Prometheus: {prom_url}")
    print(f"输出目录:   {out_dir}")
    print(f"时间:       {now.isoformat()}")
    print("=" * 60)

    # 检查 Prometheus 连接
    print("\n[1/3] 检查 Prometheus 连接...")
    try:
        data = _prometheus_get(f"{prom_url}/api/v1/status/buildinfo", timeout=5)
        print(f"  Prometheus {data['data']['version']} 连接正常")
    except Exception as e:
        print(f"  [错误] 无法连接 Prometheus: {e}")
        print(f"  请检查: PROMETHEUS_URL={prom_url}")
        return

    # 范围查询模式
    if args.start and args.end:
        print(f"\n[2/3] 时间范围查询: {args.start} -> {args.end}")
        summary = collect_range_metrics(out_dir, args.start, args.end)
        print(f"\n[3/3] 采集完成!")
        for name, count in summary.items():
            print(f"  {name}: {count} 个数据点")
        return

    # 即时采集模式（可能持续采集）
    if args.duration > 0:
        end_time = now + timedelta(minutes=args.duration)
        cycle = 0
        print(f"\n[2/3] 持续采集 {args.duration} 分钟...")
        while datetime.now(timezone.utc) < end_time:
            cycle += 1
            ts = datetime.now(timezone.utc).strftime(f"{label}_cycle{cycle:03d}")
            print(f"\n  第 {cycle} 轮采集 ({ts})")
            collect_instant_metrics(out_dir, ts)
            print(f"  等待 60 秒...")
            import time

            time.sleep(60)
    else:
        print(f"\n[2/3] 即时数据采集...")
        summary = collect_instant_metrics(out_dir, label)

    print(f"\n[3/3] 采集完成!")
    print(f"数据保存在: {out_dir}/")


if __name__ == "__main__":
    main()
