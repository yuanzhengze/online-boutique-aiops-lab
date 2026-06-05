#!/bin/bash
# ChaosMesh 自动化循环故障注入脚本 v3
# 策略: 重点突出核心故障，每种多次注入，配合精确时间戳和Prometheus采集
# 用法: nohup bash /tmp/chaos_loop.sh > /tmp/chaos_loop.log 2>&1 &

YAML_DIR="/tmp/chaos-yamls"
LOG_FILE="/tmp/chaos_loop.log"
TIMELINE_FILE="/tmp/chaos_timeline.csv"
PROM_DIR="/tmp/prom_snapshots"
INTERVAL=300  # 5分钟 = 300秒（提高频率）

mkdir -p $PROM_DIR

# 初始化时间线CSV
if [ ! -f "$TIMELINE_FILE" ]; then
  echo "experiment,start_time,end_time,start_epoch,end_epoch,status" > $TIMELINE_FILE
fi

# 重点实验列表（每种3次，给算法组足够数据）
# 格式: "文件1,文件2,...|标签"
EXPERIMENTS=(
  # === 核心故障（每种3次） ===
  # Pod Kill - 最经典的K8s故障
  "pod-kill-cartservice.yaml|pod-kill-cartservice"
  "pod-kill-cartservice.yaml|pod-kill-cartservice"
  "pod-kill-cartservice.yaml|pod-kill-cartservice"

  # Network Delay - 最常见的生产故障
  "network-delay-recommendation.yaml|net-delay-recommendation-500ms"
  "network-delay-recommendation.yaml|net-delay-recommendation-500ms"
  "network-delay-recommendation.yaml|net-delay-recommendation-500ms"

  # Network Loss - 明确影响可用性
  "network-loss-frontend.yaml|net-loss-frontend-30pct"
  "network-loss-frontend.yaml|net-loss-frontend-30pct"
  "network-loss-frontend.yaml|net-loss-frontend-30pct"

  # CPU Stress - 资源耗尽类
  "cpu-stress-productcatalog.yaml|cpu-stress-productcatalog"
  "cpu-stress-productcatalog.yaml|cpu-stress-productcatalog"
  "cpu-stress-productcatalog.yaml|cpu-stress-productcatalog"

  # Memory Stress - 资源耗尽类
  "memory-stress-currency.yaml|mem-stress-currency"
  "memory-stress-currency.yaml|mem-stress-currency"
  "memory-stress-currency.yaml|mem-stress-currency"

  # === 渐进式参数（各1次，找临界点） ===
  "progressive-loss-frontend-10.yaml|net-loss-frontend-10pct"
  "progressive-loss-frontend-50.yaml|net-loss-frontend-50pct"
  "progressive-delay-recommendation-200.yaml|net-delay-recommendation-200ms"
  "progressive-delay-recommendation-1000.yaml|net-delay-recommendation-1000ms"

  # === 复合故障（各1次） ===
  "compound-delay-cpu-delay.yaml,compound-delay-cpu-stress.yaml|compound-delay+cpu-productcatalog"
  "compound-cart-kill.yaml,compound-checkout-delay.yaml|compound-podkill+delay-cart-checkout"
  "compound-mem-loss-stress.yaml,compound-mem-loss-loss.yaml|compound-mem+loss-currency"

  # === HTTPChaos（各1次） ===
  "http-abort-frontend.yaml|http-abort-frontend"
  "http-delay-productcatalog.yaml|http-delay-productcatalog"
  "http-error-currency.yaml|http-error-currency-503"

  # === TimeChaos（各1次） ===
  "time-skew-recommendation.yaml|time-skew-recommendation-10s"
  "time-skew-checkout.yaml|time-skew-checkout+5s"
)

# 采集Prometheus快照
collect_prom_snapshot() {
  local label="$1"
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  local outfile="$PROM_DIR/${label}_${timestamp}.txt"

  # 采集关键指标
  cat > /tmp/prom_query.sh << 'PROMEOF'
#!/bin/bash
PROM_URL="http://localhost:32090/api/v1/query"
echo "=== Prometheus Snapshot ==="
echo "timestamp: $(date -Iseconds)"
echo ""

# 各服务请求延迟P99
echo "--- Request Latency P99 (last 5m) ---"
curl -s "$PROM_URL?query=histogram_quantile(0.99,sum(rate(request_duration_milliseconds_bucket{job=\"online-boutique\"}[5m]))by(le,service))" | python3 -m json.tool 2>/dev/null || echo "query failed"

# 各服务错误率
echo "--- Error Rate (last 5m) ---"
curl -s "$PROM_URL?query=sum(rate(request_duration_milliseconds_count{job=\"online-boutique\",status_code=~\"5..\"}[5m]))by(service)/sum(rate(request_duration_milliseconds_count{job=\"online-boutique\"}[5m]))by(service)" | python3 -m json.tool 2>/dev/null || echo "query failed"

# Pod重启次数
echo "--- Pod Restarts ---"
curl -s "$PROM_URL?query=kube_pod_container_status_restarts_count" | python3 -m json.tool 2>/dev/null || echo "query failed"

# CPU使用率
echo "--- CPU Usage ---"
curl -s "$PROM_URL?query=sum(rate(container_cpu_usage_seconds_total{namespace=\"default\"}[5m]))by(pod)" | python3 -m json.tool 2>/dev/null || echo "query failed"

# 内存使用
echo "--- Memory Usage ---"
curl -s "$PROM_URL?query=sum(container_memory_working_set_bytes{namespace=\"default\"})by(pod)" | python3 -m json.tool 2>/dev/null || echo "query failed"
PROMEOF
  bash /tmp/prom_query.sh > "$outfile" 2>&1
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Prometheus快照已保存: $outfile" >> $LOG_FILE
}

# 清理所有残留实验
cleanup_all() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理残留实验..." >> $LOG_FILE
  kubectl delete podchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete networkchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete stresschaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete httpchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete timechaos --all -n chaos-mesh --timeout=30s 2>/dev/null

  # 处理卡住的 finalizer
  for resource in podchaos networkchaos stresschaos httpchaos timechaos; do
    for name in $(kubectl get $resource -n chaos-mesh -o name 2>/dev/null); do
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 强制清理 $name" >> $LOG_FILE
      kubectl patch $name -n chaos-mesh --type=json -p='[{"op": "replace", "path": "/metadata/finalizers", "value":[]}]' 2>/dev/null
      kubectl delete $name -n chaos-mesh --force --grace-period=0 2>/dev/null
    done
  done
  sleep 5
}

# 注入实验
inject_chaos() {
  local entry="$1"
  local label="$2"
  local start_time=$(date -Iseconds)
  local start_epoch=$(date +%s)

  echo "" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始注入: $label" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE

  # 先清理
  cleanup_all

  # 注入
  IFS=',' read -ra FILES <<< "$entry"
  all_ok=true
  for f in "${FILES[@]}"; do
    local yaml_file="$YAML_DIR/$f"
    if [ ! -f "$yaml_file" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 文件不存在: $yaml_file，跳过" >> $LOG_FILE
      all_ok=false
      continue
    fi
    kubectl apply -f "$yaml_file" >> $LOG_FILE 2>&1
    if [ $? -ne 0 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入失败: $f" >> $LOG_FILE
      all_ok=false
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入成功: $f" >> $LOG_FILE
    fi
  done

  # 等待实验生效
  if echo "$label" | grep -q "pod-kill"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PodKill，等待60秒..." >> $LOG_FILE
    sleep 60
  elif echo "$label" | grep -q "compound"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 复合故障，等待150秒..." >> $LOG_FILE
    sleep 150
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 常规实验，等待120秒..." >> $LOG_FILE
    sleep 120
  fi

  # 采集Prometheus快照（故障期间）
  collect_prom_snapshot "$label"

  # 清理
  local end_time=$(date -Iseconds)
  local end_epoch=$(date +%s)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理实验: $label" >> $LOG_FILE
  cleanup_all

  # 记录时间线
  echo "$label,$start_time,$end_time,$start_epoch,$end_epoch,success" >> $TIMELINE_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 实验完成: $label (耗时$((end_epoch - start_epoch))秒)" >> $LOG_FILE
}

# 主循环
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ChaosMesh 自动化故障注入 v3 启动 =====" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 共 ${#EXPERIMENTS[@]} 个实验，间隔 ${INTERVAL} 秒" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 核心故障各3次，渐进/复合/HTTP/Time各1次" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 时间线记录: $TIMELINE_FILE" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Prometheus快照: $PROM_DIR" >> $LOG_FILE

cleanup_all

CYCLE=0
while true; do
  CYCLE=$((CYCLE + 1))
  echo "" >> $LOG_FILE
  echo "########## 第 $CYCLE 轮 ##########" >> $LOG_FILE

  for i in "${!EXPERIMENTS[@]}"; do
    entry="${EXPERIMENTS[$i]}"
    label=$(echo "$entry" | cut -d'|' -f2)
    files=$(echo "$entry" | cut -d'|' -f1)

    inject_chaos "$files" "$label"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${INTERVAL} 秒后注入下一个..." >> $LOG_FILE
    sleep $INTERVAL
  done
done
