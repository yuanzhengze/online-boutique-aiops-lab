#!/bin/bash
# ChaosMesh 自动化循环故障注入脚本 v5 (自动修复版)
# 策略: 5种核心故障，每种随机3-5次，串行注入，间隔20分钟
# 新增: 注入失败时自动重启 controller-manager 并重试
# 用法: nohup bash /tmp/chaos_loop_v5.sh > /tmp/chaos_loop_v5.log 2>&1 &

YAML_DIR="/tmp/chaos-yamls"
LOG_FILE="/tmp/chaos_loop_v5.log"
TIMELINE_FILE="/tmp/chaos_timeline_v4.csv"  # 保持同一个时间线文件
INTERVAL=1200  # 20分钟 = 1200秒
MAX_RETRIES=3  # 最大重试次数

mkdir -p /tmp/prom_snapshots_v5

# 初始化时间线CSV（如果不存在）
if [ ! -f "$TIMELINE_FILE" ]; then
  echo "experiment,start_time,end_time,start_epoch,end_epoch,status" > $TIMELINE_FILE
fi

# 5种核心故障
EXPERIMENTS=(
  "pod-kill-cartservice.yaml|pod-kill-cartservice"
  "network-delay-recommendation.yaml|network-delay-recommendation-500ms"
  "network-loss-frontend.yaml|network-loss-frontend-30pct"
  "cpu-stress-productcatalog.yaml|cpu-stress-productcatalog"
  "memory-stress-currency.yaml|memory-stress-currency"
)

# 随机3-5次
random_count() {
  echo $(( RANDOM % 3 + 3 ))
}

# 重启 controller-manager（修复 webhook）
restart_controller() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] !!! Webhook 故障，重启 controller-manager !!!" >> $LOG_FILE
  kubectl rollout restart deployment/chaos-controller-manager -n chaos-mesh 2>&1 >> $LOG_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 controller 重建 (60秒)..." >> $LOG_FILE
  sleep 60

  # 等待 Pod 就绪
  local wait=0
  while [ $wait -lt 120 ]; do
    local ready=$(kubectl get pods -n chaos-mesh -l app.kubernetes.io/component=controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    if [ "$ready" = "true" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] controller-manager 已就绪" >> $LOG_FILE
      sleep 10  # 额外等10秒让 webhook 注册完成
      return 0
    fi
    sleep 5
    wait=$((wait + 5))
  done
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] controller-manager 等待超时" >> $LOG_FILE
  return 1
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

# 注入单个实验（带自动重试）
inject_chaos() {
  local yaml_file="$1"
  local label="$2"
  local attempt=0

  while [ $attempt -lt $MAX_RETRIES ]; do
    attempt=$((attempt + 1))
    local start_time=$(date -Iseconds)
    local start_epoch=$(date +%s)

    echo "" >> $LOG_FILE
    echo "========================================" >> $LOG_FILE
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始注入: $label (尝试 $attempt/$MAX_RETRIES)" >> $LOG_FILE
    echo "========================================" >> $LOG_FILE

    # 先清理
    cleanup_all

    # 检查文件
    local full_path="$YAML_DIR/$yaml_file"
    if [ ! -f "$full_path" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 文件不存在: $full_path，跳过" >> $LOG_FILE
      echo "$label,$start_time,$(date -Iseconds),$start_epoch,$(date +%s),skip-file-not-found" >> $TIMELINE_FILE
      return 1
    fi

    # 注入
    local apply_output=$(kubectl apply -f "$full_path" 2>&1)
    local apply_exit=$?
    echo "$apply_output" >> $LOG_FILE

    if [ $apply_exit -ne 0 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入失败 (尝试 $attempt/$MAX_RETRIES): $label" >> $LOG_FILE

      # 检查是否是 webhook 错误
      if echo "$apply_output" | grep -qi "webhook\|connection refused\|Internal error"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检测到 webhook 错误，尝试修复..." >> $LOG_FILE
        restart_controller
        if [ $attempt -lt $MAX_RETRIES ]; then
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] 重试中..." >> $LOG_FILE
          continue
        fi
      fi

      # 非 webhook 错误或重试耗尽
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
  done

  # 所有重试都失败
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $label: $MAX_RETRIES 次重试全部失败" >> $LOG_FILE
  return 1
}

# 主循环
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ChaosMesh 自动化故障注入 v5 (自动修复版) 启动 =====" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 5种核心故障，每种随机3-5次，间隔 ${INTERVAL} 秒" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自动修复: webhook 失败时重启 controller，最多重试 ${MAX_RETRIES} 次" >> $LOG_FILE
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
