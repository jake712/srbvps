#!/bin/bash
# SRBMiner 開機自啟動 - 防OOM穩定版 V4
set -e

if [ "$EUID" -ne 0 ]; then echo "請用 sudo / root 執行"; exit 1; fi

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79%"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"
SWAP_SIZE="4G"

# === 自動補 Swap 防 OOM ===
ensure_swap() {
  local have_swap=$(free -m | awk '/Swap:/ {print $2}')
  if [ "$have_swap" -lt 500 ]; then
    echo "⚠️ 偵測到 Swap 不足 (<500MB)，建立 ${SWAP_SIZE} Swap..."
    if [! -f /swapfile ]; then
      fallocate -l $SWAP_SIZE /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
      chmod 600 /swapfile
      mkswap /swapfile
    fi
    swapon /swapfile || true
    grep -q "/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "✅ Swap 已建立: $(free -h | grep Swap)"
  else
    echo "✅ Swap 已存在: $(free -h | grep Swap)"
  fi
}
ensure_swap

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

# === 建立 systemd 服務 - 防 OOM 版 ===
cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner XelisHashv3 Anti-OOM - Worker $WORKER
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=$MINER_DIR
ExecStartPre=-/sbin/modprobe msr
# 關鍵: threads 0 改 1, 去掉大頁面參數，極限省 RAM
ExecStart=$MINER_BIN --algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --cpu-threads 1 --disable-gpu --disable-worker-watchdog --api-port $API_PORT

# === 防 OOM 重啟核心 ===
Restart=always
RestartSec=15
TimeoutStopSec=30
CPUQuota=$CPU_QUOTA
MemoryHigh=1500M
MemoryMax=2200M
MemorySwapMax=4G
OOMScoreAdjust=-300

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable srbminer
systemctl restart srbminer

sleep 3
systemctl status srbminer --no-pager -l | head -n 40
echo ""
echo "========== V4 防 OOM 版完成 =========="
free -h
echo "查看日誌: journalctl -u srbminer -f -n 100"
echo "查看算力: curl -s http://127.0.0.1:${API_PORT} | jq"
echo "檢查 OOM: dmesg | grep -i oom"
