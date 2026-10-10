#!/bin/sh
# SRBMiner 開機自啟動 - Alpine / OpenRC 修正版 V3
# 用法: chmod +x autow-alpine.sh && ./autow-alpine.sh [worker名稱]
set -e

if [ "$(id -u)" -ne 0 ]; then echo "請用 sudo / root 執行"; exit 1; fi

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"

# === Alpine 相依 (SRBMiner 是 glibc 編譯，必須裝 gcompat) ===
apk update
apk add bash gcompat libstdc++ libgcc curl jq cpulimit hwloc musl-utils

# === 尋找礦工目錄 ===
if [ -f "/root/SRBMiner-Multi-3-6-9/SRBMiner-MULTI" ]; then
  MINER_DIR="/root/SRBMiner-Multi-3-6-9"
  MINER_BIN="/root/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"
elif [ -f "./SRBMiner-Multi-3-6-9/SRBMiner-MULTI" ]; then
  MINER_DIR="$(pwd)/SRBMiner-Multi-3-6-9"
  MINER_BIN="$(pwd)/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"
else
  echo "❌ 找不到 SRBMiner-MULTI，請先解壓到 /root/SRBMiner-Multi-3-6-9/"
  exit 1
fi

chmod +x "$MINER_BIN"

# === Worker 名稱 ===
if [ -n "$1" ]; then
  WORKER="$1"
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "請輸入 Worker 名稱 (只能英文數字 - _ )"
  echo "直接按 Enter 會使用主機名: $(hostname)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "Worker 名稱: "
  read WORKER < /dev/tty 2>/dev/null || read WORKER 2>/dev/null || true
  if [ -z "$WORKER" ]; then
    WORKER=$(hostname | cut -c1-20)
  fi
fi

WORKER=$(echo "$WORKER" | tr -cd 'a-zA-Z0-9_-' )
[ -z "$WORKER" ] && WORKER=$(hostname | cut -c1-20 | tr -cd 'a-zA-Z0-9_-')
FULL_WALLET="POL:${BASE_WALLET}.${WORKER}#${REF_CODE}"

echo "✅ Worker: $WORKER"
echo "✅ Wallet: $FULL_WALLET"
echo "✅ Miner: $MINER_BIN"

# === 建立 OpenRC 服務 (取代 systemd) ===
cat > /etc/init.d/srbminer <<EOF
#!/sbin/openrc-run
name="srbminer"
description="SRBMiner XelisHashv3 - Worker $WORKER"
command="$MINER_BIN"
command_args="--algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --cpu-threads 1 --disable-gpu --disable-huge-pages --disable-cpu-optimisations --api-port $API_PORT"
command_background=true
pidfile="/run/srbminer.pid"
directory="$MINER_DIR"
output_log="/var/log/srbminer.log"
error_log="/var/log/srbminer.log"

depend() {
  need net
  after firewall
}

start_pre() {
  modprobe msr 2>/dev/null || true
  checkpath --file --mode 0644 --owner root:root /var/log/srbminer.log
  checkpath --file --mode 0644 --owner root:root /run/srbminer.pid
}

start_post() {
  # 模擬 systemd 的 CPUQuota=79%
  sleep 1
  if command -v cpulimit >/dev/null 2>&1; then
    PID=\$(cat \$pidfile 2>/dev/null || pgrep -f "SRBMiner-MULTI.*$WORKER" | head -n1)
    if [ -n "\$PID" ]; then
      cpulimit -p \$PID -l $CPU_QUOTA -b -q 2>/dev/null &
      einfo "CPU limit ${CPU_QUOTA}% 已套用到 PID \$PID"
    fi
  fi
}

stop_post() {
  pkill -f cpulimit 2>/dev/null || true
}
EOF

chmod +x /etc/init.d/srbminer
touch /var/log/srbminer.log

# 開機自啟
rc-update add srbminer default 2>/dev/null || rc-update add srbminer boot 2>/dev/null || true

# 重啟服務
rc-service srbminer stop 2>/dev/null || true
sleep 1
rc-service srbminer start

sleep 3
rc-service srbminer status || true
echo ""
echo "========== 完成，重開機自動啟動已設定 (OpenRC) =========="
echo "查看日誌: tail -f /var/log/srbminer.log"
echo "查看算力: curl -s http://127.0.0.1:${API_PORT} | jq"
echo "重啟服務: rc-service srbminer restart"
echo "停止服務: rc-service srbminer stop"
echo "開機自啟: rc-update add srbminer default"
