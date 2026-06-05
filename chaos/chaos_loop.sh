#!/bin/bash
# ChaosMesh 自动化循环故障注入脚本 v2
# 每10分钟注入一种故障，24小时不间断
# 支持单一故障、复合故障、渐进式参数实验
# 用法: nohup bash /tmp/chaos_loop.sh > /tmp/chaos_loop.log 2>&1 &

YAML_DIR="/tmp/chaos-yamls"
LOG_FILE="/tmp/chaos_loop.log"
INTERVAL=600  # 10分钟 = 600秒

# 实验列表
# 格式: "文件1,文件2,..." 多文件表示复合故障（同时注入）
EXPERIMENTS=(
  # === 单一故障：Pod Kill ===
  "pod-kill-cartservice.yaml"
  "pod-kill-frontend.yaml"
  "pod-kill-checkoutservice.yaml"
  "pod-kill-emailservice.yaml"
  "pod-kill-redis-cart.yaml"

  # === 单一故障：Network Delay ===
  "network-delay-recommendation.yaml"
  "network-delay-cartservice.yaml"
  "network-delay-productcatalog.yaml"
  "network-delay-shippingservice.yaml"

  # === 单一故障：Network Loss ===
  "network-loss-frontend.yaml"
  "network-loss-recommendation.yaml"
  "network-loss-checkoutservice.yaml"
  "network-loss-paymentservice.yaml"

  # === 单一故障：CPU Stress ===
  "cpu-stress-productcatalog.yaml"
  "cpu-stress-adservice.yaml"

  # === 单一故障：Memory Stress ===
  "memory-stress-currency.yaml"
  "memory-stress-checkoutservice.yaml"

  # === 复合故障：同时注入多种故障 ===
  "compound-delay-cpu-delay.yaml,compound-delay-cpu-stress.yaml"
  "compound-cart-kill.yaml,compound-checkout-delay.yaml"
  "compound-mem-loss-stress.yaml,compound-mem-loss-loss.yaml"

  # === 渐进式参数：不同强度的同类故障 ===
  "progressive-loss-frontend-10.yaml"
  "progressive-loss-frontend-50.yaml"
  "progressive-delay-recommendation-200.yaml"
  "progressive-delay-recommendation-1000.yaml"
)

# 清理所有残留实验
cleanup_all() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理残留实验..." >> $LOG_FILE
  kubectl delete podchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete networkchaos --all -n chaos-mesh --timeout=30s 2>/dev/null
  kubectl delete stresschaos --all -n chaos-mesh --timeout=30s 2>/dev/null

  # 处理卡住的 finalizer
  for resource in podchaos networkchaos stresschaos; do
    for name in $(kubectl get $resource -n chaos-mesh -o name 2>/dev/null); do
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 强制清理 $name" >> $LOG_FILE
      kubectl patch $name -n chaos-mesh --type=json -p='[{"op": "replace", "path": "/metadata/finalizers", "value":[]}]' 2>/dev/null
      kubectl delete $name -n chaos-mesh --force --grace-period=0 2>/dev/null
    done
  done
  sleep 5
}

# 注入实验（支持多文件复合注入）
inject_chaos() {
  local entry="$1"
  local label="$2"

  echo "" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始注入: $label" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE

  # 先清理之前的实验
  cleanup_all

  # 注入所有文件（逗号分隔表示复合故障）
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

  if [ "$all_ok" = false ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 部分注入失败" >> $LOG_FILE
  fi

  # 等待实验生效
  if echo "$label" | grep -q "pod-kill"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PodKill实验，等待60秒..." >> $LOG_FILE
    sleep 60
  elif echo "$label" | grep -q "compound"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 复合故障实验，等待180秒..." >> $LOG_FILE
    sleep 180
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 网络/压力实验，等待150秒..." >> $LOG_FILE
    sleep 150
  fi

  # 清理当前实验
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理实验: $label" >> $LOG_FILE
  cleanup_all

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 实验完成: $label" >> $LOG_FILE
}

# 主循环
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ChaosMesh 自动化故障注入 v2 启动 =====" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 共 ${#EXPERIMENTS[@]} 个实验，每 ${INTERVAL} 秒注入一次" >> $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 预计完整一轮: $(( ${#EXPERIMENTS[@]} * INTERVAL / 3600 )) 小时" >> $LOG_FILE

# 初始清理
cleanup_all

CYCLE=0
while true; do
  CYCLE=$((CYCLE + 1))
  echo "" >> $LOG_FILE
  echo "########## 第 $CYCLE 轮 ##########" >> $LOG_FILE

  for i in "${!EXPERIMENTS[@]}"; do
    entry="${EXPERIMENTS[$i]}"
    # 生成标签（去掉.yaml后缀，复合故障用+连接）
    label=$(echo "$entry" | sed 's/\.yaml//g' | sed 's/,/+/g')

    inject_chaos "$entry" "$label"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${INTERVAL} 秒后注入下一个实验..." >> $LOG_FILE
    sleep $INTERVAL
  done
done
