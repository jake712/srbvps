#!/bin/bash
# SRBMiner 開機自啟動 - 修正穩定版 V3
set -e

if [ "$EUID" -ne 0 ]; then echo "請用 sudo / root 執行"; exit 1; fi

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79%"
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

# === 建立 systemd 服務 ===
cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner XelisHashv3 - Worker $WORKER
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=$MINER_DIR
ExecStartPre=-/sbin/modprobe msr
ExecStart=$MINER_BIN --algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --cpu-threads 0 --extended-log --api-port $API_PORT
Restart=always
RestartSec=10
CPUQuota=$CPU_QUOTA
TimeoutStopSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable srbminer
systemctl restart srbminer

sleep 2
systemctl status srbminer --no-pager -l | head -n 30
echo ""
echo "========== 完成，重開機自動啟動已設定 =========="
echo "查看日誌: journalctl -u srbminer -f -n 100"
echo "查看算力: curl -s http://127.0.0.1:${API_PORT} | jq"
