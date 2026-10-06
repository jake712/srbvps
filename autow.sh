#!/bin/bash
# SRBMiner 開機自啟動 - 修正版

set -e

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79%"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"

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

if [ -n "$1" ]; then
  WORKER="$1"
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "請輸入 Worker 名稱 (只能英文數字 - _ )"
  echo "直接按 Enter 會使用主機名: $(hostname)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # 加 || true 避免 set -e 直接把腳本殺掉
  read -p "Worker 名稱: " WORKER < /dev/tty 2>/dev/null || read -p "Worker 名稱: " WORKER 2>/dev/null || true
  if [ -z "$WORKER" ]; then
    WORKER=$(hostname | cut -c1-20)
  fi
fi

WORKER=$(echo "$WORKER" | tr -cd 'a-zA-Z0-9-_')
[ -z "$WORKER" ] && WORKER=$(hostname | cut -c1-20)
FULL_WALLET="POL:${BASE_WALLET}.${WORKER}#${REF_CODE}"

echo "✅ Worker: $WORKER"

# === 建立 systemd 服務 - 修正版 ===
cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner XelisHashv3 - Worker $WORKER
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$MINER_DIR
ExecStartPre=-/sbin/modprobe msr
ExecStart=$MINER_BIN --algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --disable-worker-watchdog --cpu-threads 1 --extended-log --api-port $API_PORT
Restart=always
RestartSec=10
CPUQuota=$CPU_QUOTA
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable srbminer
systemctl restart srbminer

sleep 2
systemctl status srbminer --no-pager -l | head -n 20
echo ""
echo "查看日誌: journalctl -u srbminer -f -n 100"
