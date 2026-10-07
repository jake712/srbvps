#!/bin/bash
# SRBMiner 開機自啟動 - Alpine OpenRC 版 V3
set -e

if [ "$(id -u)" -ne 0 ]; then echo "請用 sudo / root 執行"; exit 1; fi

# === Alpine 依賴 ===
if [ -f /etc/alpine-release ]; then
  apk update
  apk add bash gcompat libstdc++ hwloc curl jq cpulimit
fi

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"

# === 尋找礦工目錄 ===
if [ -f "/root/SRBMiner-Multi-3-6-9/SRBMiner-MULTI" ]; then
  MINER_DIR="/root/SRBMiner-Multi-3-6-9"
  MINER_BIN="/root/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"
elif [ -f "./SRBMiner-Multi-3-6-9/SRBMiner-MULTI" ]; then
  MINER_DIR="$(pwd)/SRBMiner-Multi-3-6-9"
  MINER_BIN="$(pwd)/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"
else
  echo "❌ 找不到 SRBMiner-MULTI"
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
  read -p "Worker 名稱: " WORKER < /dev/tty 2>/dev/null || read -p "Worker 名稱: " WORKER 2>/dev/null || true
  if [ -z "$WORKER" ]; then
    WORKER=$(hostname | cut -c1-20)
  fi
fi

WORKER=$(echo "$WORKER" | tr -cd 'a-zA-Z0-9_-' )
[ -z "$WORKER" ] && WORKER=$(hostname | cut -c1-20 | tr -cd 'a-zA-Z0-9_-')
FULL_WALLET="POL:${BASE_WALLET}.${WORKER}#${REF_CODE}"

echo "✅ Worker: $WORKER"
echo "✅ Wallet: $FULL_WALLET"

# === 建立 OpenRC 服務 ===
cat > /etc/init.d/srbminer <<EOF
#!/sbin/openrc-run
name="srbminer"
description="SRBMiner XelisHashv3 - Worker $WORKER"
directory=$MINER_DIR
command=$MINER_BIN
command_args="--algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --cpu-threads 1 --disable-gpu --disable-huge-pages --disable-cpu-optimisations --api-port $API_PORT"
command_background=true
pidfile="/run/srbminer.pid"
output_log="/var/log/srbminer.log"
error_log="/var/log/srbminer.log"

depend() {
  need net
  after firewall
}

start_pre() {
  modprobe msr 2>/dev/null || true
  checkpath --file --mode 0644 /var/log/srbminer.log
}
EOF

chmod +x /etc/init.d/srbminer
rc-update add srbminer default
rc-service srbminer restart

sleep 2
rc-service srbminer status
echo ""
echo "========== 完成，重開機自動啟動已設定 =========="
echo "查看日誌: tail -f /var/log/srbminer.log"
echo "查看算力: curl -s http://127.0.0.1:${API_PORT} | jq"
echo "限制CPU 79% (Alpine沒有CPUQuota，用cpulimit): cpulimit -p \$(cat /run/srbminer.pid) -l 79 -b"
