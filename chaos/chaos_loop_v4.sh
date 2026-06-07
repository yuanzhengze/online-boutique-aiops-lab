#!/bin/bash
# ChaosMesh 自动化循环故障注入脚本 v4 (最终版)
# 策略: 5种核心故障，每种随机3-5次，串行注入，间隔20分钟
# 用法: nohup bash /tmp/chaos_loop_v4.sh > /tmp/chaos_loop_v4.log 2>&1 &

YAML_DIR="/tmp/chaos-yamls"
LOG_FILE="/tmp/chaos_loop_v4.log"
TIMELINE_FILE="/tmp/chaos_timeline_v4.csv"
INTERVAL=1200  # 20分钟 = 1200秒

mkdir -p /tmp/prom_snapshots_v4

# 初始化时间线CSV
if [ ! -f "$TIMELINE_FILE" ]; then
  echo "experiment,start_time,end_time,start_epoch,end_epoch,status" > $TIMELINE_FILE
fi

# 5种核心故障，按类型排列
EXPERIMENTS=(
  "pod-kill-cartservice.yaml|pod-kill-cartservice"
  "network-delay-recommendation.yaml|network-delay-recommendation-500ms"
  "network-loss-frontend.yaml|network-loss-frontend-30pct"
  "cpu-stress-productcatalog.yaml|cpu-stress-productcatalog"
  "memory-stress-currency.yaml|memory-stress-currency"
)

# 随机3-5次
random_count() {
  echo $(( RANDOM % 3 + 3 ))  # 3, 4, 或 5
}

# 清理所有残留实验
cleanup_all() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理残留实验..." >> $LOG_FILE
  kubectl delete podchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete networkchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete stresschaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete httpchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete timechaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  sleep 5

  # 处理卡住的 finalizer
  for resource in podchaos networkchaos stresschaos httpchaos timechaos; do
    for name in $(kubectl get $resource -n chaos-mesh -o name 2>/dev/null); do
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 强制清理 $name" >> $LOG_FILE
      kubectl patch $name -n chaos-mesh --type=json -p='[{"op": "replace", "path": "/metadata/finalizers", "value":[]}]' 2>/dev/null
      kubectl delete $name -n chaos-mesh --force --grace-period=0 2>/dev/null
    done
  done
  sleep 3
}

# 注入单个实验
inject_chaos() {
  local yaml_file="$1"
  local label="$2"
  local start_time=$(date -Iseconds)
  local start_epoch=$(date +%s)

  echo "" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始注入: $label" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE

  # 先清理（确保同一时间只有一个实验）
  cleanup_all

  # 注入
  local full_path="$YAML_DIR/$yaml_file"
  if [ ! -f "$full_path" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 文件不存在: $full_path，跳过" >> $LOG_FILE
    echo "$label,$start_time,$(date -Iseconds),$start_epoch,$(date +%s),skip-file-not-found" >> $TIMELINE_FILE
    return 1
  fi

  kubectl apply -f "$full_path" >> $LOG_FILE 2>&1
  if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入失败: $label" >> $LOG_FILE
    echo "$label,$start_time,$(date -Iseconds),$start_epoch,$(date +%s),fail" >> $TIMELINE_FILE
    return 1
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入成功: $label" >> $LOG_FILE

  # 等待实验生效
  if echo "$label" | grep -q "pod-kill"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PodKill，等待90秒..." >> $LOG_FILE
    sleep 90
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 常规实验，等待120秒..." >> $LOG_FILE
    sleep 120
  fi

  # 清理
  local end_time=$(date -Iseconds)
  local end_epoch=$(date +%s)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理实验: $label" >> $LOG_FILE
  cleanup_all

  # 记录时间线
  echo "$label,$start_time,$end_time,$start_epoch,$end_epoch,success" >> $TIMELINE_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 实验完成: $label (耗时$((end_epoch - start_epoch))秒)" >> $LOG_FILE
  return 0
}

# 主循环
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ChaosMesh 自动化故障注入 v4 (最终版) 启动 =====" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 5种核心故障，每种随机3-5次，间隔 ${INTERVAL} 秒" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 时间线记录: $TIMELINE_FILE" >> $LOG_FILE

cleanup_all

CYCLE=0
while true; do
  CYCLE=$((CYCLE + 1))
  echo "" >> $LOG_FILE
  echo "########## 第 $CYCLE 轮 ##########" >> $LOG_FILE

  for entry in "${EXPERIMENTS[@]}"; do
    yaml_file=$(echo "$entry" | cut -d'|' -f1)
    label=$(echo "$entry" | cut -d'|' -f2)

    # 随机3-5次
    count=$(random_count)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] --- $label: 本轮注入 ${count} 次 ---" >> $LOG_FILE

    for i in $(seq 1 $count); do
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 第 ${i}/${count} 次注入: $label" >> $LOG_FILE
      inject_chaos "$yaml_file" "$label"

      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${INTERVAL} 秒后注入下一个..." >> $LOG_FILE
      sleep $INTERVAL
    done
  done

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== 第 $CYCLE 轮完成 =====" >> $LOG_FILE
done
