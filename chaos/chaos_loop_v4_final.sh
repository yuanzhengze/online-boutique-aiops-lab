#!/bin/bash
# ChaosMesh 自动化循环故障注入脚本 v4-final
# 基于v4改造，满足队友需求:
#   - 6种故障: CPU占用, 占内存, 杀服务, IO压力, 丢包, 网络延迟
#   - 5小时限时
#   - 日志格式: start_time,end_time,fault_type,severity
#   - 组间随机恢复间隔
#   - 不要把集群打死
# 用法: nohup bash /tmp/chaos_loop_v4_final.sh > /tmp/chaos_loop_v4_final.log 2>&1 &

YAML_DIR="/tmp/chaos-yamls"
LOG_FILE="/tmp/chaos_loop_v4_final.log"
TIMELINE_FILE="/tmp/chaos_timeline_v4_final.csv"
HOURS=5
START_TS=$(date +%s)
END_TS=$((START_TS + HOURS * 3600))

# 初始化时间线CSV
echo "start_time,end_time,fault_type,severity" > $TIMELINE_FILE

# 6种故障 (yaml文件|类型名|severity|注入等待秒数)
EXPERIMENTS=(
  "cpu-stress-productcatalog.yaml|cpu-stress|high|120"
  "memory-stress-currency.yaml|memory-stress|high|120"
  "pod-kill-cartservice.yaml|pod-kill|high|60"
  "network-loss-frontend.yaml|network-loss|medium|120"
  "network-delay-recommendation.yaml|network-delay|medium|120"
  "io-stress|io-stress|low|120"
)

# 随机恢复间隔: 5-15分钟 (300-900秒)
random_interval() {
  echo $(( RANDOM % 600 + 300 ))
}

# 清理所有残留实验
cleanup_all() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理残留实验..." >> $LOG_FILE
  kubectl delete podchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete networkchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete stresschaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  sleep 5

  # 处理卡住的 finalizer
  for resource in podchaos networkchaos stresschaos; do
    for name in $(kubectl get $resource -n chaos-mesh -o name 2>/dev/null); do
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 强制清理 $name" >> $LOG_FILE
      kubectl patch $name -n chaos-mesh --type=json -p='[{"op": "replace", "path": "/metadata/finalizers", "value":[]}]' 2>/dev/null
      kubectl delete $name -n chaos-mesh --force --grace-period=0 2>/dev/null
    done
  done
  sleep 3
}

# IO压力注入 (kubectl exec方式，Chaos Mesh不支持IO StressChaos)
inject_io_stress() {
  local pod=$(kubectl get pods -n default -l app=productcatalogservice -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$pod" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] IO: 找不到productcatalogservice pod" >> $LOG_FILE
    return 1
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] IO: 在 $pod 中执行dd写入压力" >> $LOG_FILE
  # 500MB direct IO写入，不会把机器打死
  kubectl exec -n default "$pod" -- timeout 110 dd if=/dev/zero of=/tmp/chaos-iotest bs=1M count=500 oflag=direct 2>/dev/null &
  local pid=$!
  sleep 110
  kill $pid 2>/dev/null
  kubectl exec -n default "$pod" -- rm -f /tmp/chaos-iotest 2>/dev/null
  return 0
}

# 注入单个实验
inject_chaos() {
  local yaml_file="$1"
  local fault_type="$2"
  local severity="$3"
  local wait_sec="$4"
  local start_time=$(date -Iseconds)

  echo "" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始注入: $fault_type (severity=$severity)" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE

  # 先清理
  cleanup_all

  # IO压力用kubectl exec
  if [ "$fault_type" = "io-stress" ]; then
    inject_io_stress >> $LOG_FILE 2>&1
    local rc=$?
    local end_time=$(date -Iseconds)
    if [ $rc -eq 0 ]; then
      echo "$start_time,$end_time,$fault_type,$severity" >> $TIMELINE_FILE
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] IO压力完成" >> $LOG_FILE
    else
      echo "$start_time,$end_time,$fault_type,$severity" >> $TIMELINE_FILE
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] IO压力可能失败" >> $LOG_FILE
    fi
    return $rc
  fi

  # Chaos Mesh YAML注入
  local full_path="$YAML_DIR/$yaml_file"
  if [ ! -f "$full_path" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 文件不存在: $full_path，跳过" >> $LOG_FILE
    local end_time=$(date -Iseconds)
    echo "$start_time,$end_time,$fault_type,$severity" >> $TIMELINE_FILE
    return 1
  fi

  kubectl apply -f "$full_path" >> $LOG_FILE 2>&1
  if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入失败: $fault_type" >> $LOG_FILE
    local end_time=$(date -Iseconds)
    echo "$start_time,$end_time,$fault_type,$severity" >> $TIMELINE_FILE
    return 1
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入成功: $fault_type" >> $LOG_FILE

  # 等待实验生效
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${wait_sec} 秒..." >> $LOG_FILE
  sleep "$wait_sec"

  # 清理
  local end_time=$(date -Iseconds)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理实验: $fault_type" >> $LOG_FILE
  cleanup_all

  # 记录时间线
  echo "$start_time,$end_time,$fault_type,$severity" >> $TIMELINE_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 实验完成: $fault_type" >> $LOG_FILE
  return 0
}

# 主循环
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ChaosMesh 自动化故障注入 v4-final =====" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 6种故障, 5小时限时, 组间随机恢复间隔" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 时间线记录: $TIMELINE_FILE" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 预计结束: $(date -d @$END_TS '+%Y-%m-%d %H:%M:%S')" >> $LOG_FILE

cleanup_all

ROUND=0
while [ $(date +%s) -lt $END_TS ]; do
  ROUND=$((ROUND + 1))
  remaining=$(( (END_TS - $(date +%s)) / 60 ))
  echo "" >> $LOG_FILE
  echo "########## 第 $ROUND 轮 (剩余${remaining}min) ##########" >> $LOG_FILE

  for entry in "${EXPERIMENTS[@]}"; do
    # 检查时间
    if [ $(date +%s) -ge $END_TS ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 到达5小时限制，停止" >> $LOG_FILE
      break 2
    fi

    yaml_file=$(echo "$entry" | cut -d'|' -f1)
    fault_type=$(echo "$entry" | cut -d'|' -f2)
    severity=$(echo "$entry" | cut -d'|' -f3)
    wait_sec=$(echo "$entry" | cut -d'|' -f4)

    inject_chaos "$yaml_file" "$fault_type" "$severity" "$wait_sec"

    # 组间随机恢复间隔 (5-15分钟)
    if [ $(date +%s) -lt $END_TS ]; then
      interval=$(random_interval)
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 恢复间隔: $((interval/60))分钟" >> $LOG_FILE
      sleep $interval
    fi
  done
done

echo "" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== v4-final 完成! 共 $ROUND 轮 =====" >> $LOG_FILE

# 最终清理
cleanup_all
