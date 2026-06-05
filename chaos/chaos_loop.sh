#!/bin/bash
# ChaosMesh 自动化循环故障注入脚本
# 每10分钟注入一种故障，13种故障轮流，24小时不间断
# 用法: nohup bash /tmp/chaos_loop.sh > /tmp/chaos_loop.log 2>&1 &

YAML_DIR="/tmp/chaos-yamls"
LOG_FILE="/tmp/chaos_loop.log"
INTERVAL=600  # 10分钟 = 600秒

# 实验列表（按顺序轮流）
EXPERIMENTS=(
  "pod-kill-cartservice.yaml"
  "pod-kill-frontend.yaml"
  "pod-kill-checkoutservice.yaml"
  "network-delay-recommendation.yaml"
  "network-delay-cartservice.yaml"
  "network-delay-productcatalog.yaml"
  "network-loss-frontend.yaml"
  "network-loss-recommendation.yaml"
  "network-loss-checkoutservice.yaml"
  "cpu-stress-productcatalog.yaml"
  "cpu-stress-adservice.yaml"
  "memory-stress-currency.yaml"
  "memory-stress-checkoutservice.yaml"
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

# 注入单个实验
inject_chaos() {
  local yaml_file="$1"
  local name=$(basename "$yaml_file" .yaml)
  
  echo "" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始注入: $name" >> $LOG_FILE
  echo "========================================" >> $LOG_FILE
  
  # 先清理之前的实验
  cleanup_all
  
  # 注入新实验
  kubectl apply -f "$yaml_file" >> $LOG_FILE 2>&1
  if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入成功: $name" >> $LOG_FILE
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 注入失败: $name" >> $LOG_FILE
    return 1
  fi

  # 等待实验生效（根据类型不同等待不同时间）
  # PodKill: 30s, 其他: 120s
  if echo "$name" | grep -q "pod-kill"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PodKill实验，等待60秒..." >> $LOG_FILE
    sleep 60
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 网络/压力实验，等待150秒..." >> $LOG_FILE
    sleep 150
  fi

  # 清理当前实验
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理实验: $name" >> $LOG_FILE
  cleanup_all
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 实验完成: $name" >> $LOG_FILE
}

# 主循环
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ===== ChaosMesh 自动化故障注入启动 =====" >> $LOG_FILE
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
    yaml="$YAML_DIR/${EXPERIMENTS[$i]}"
    
    if [ ! -f "$yaml" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 文件不存在: $yaml，跳过" >> $LOG_FILE
      continue
    fi
    
    inject_chaos "$yaml"
    
    # 等待到下一个30分钟间隔
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 等待 ${INTERVAL} 秒后注入下一个实验..." >> $LOG_FILE
    sleep $INTERVAL
  done
done
