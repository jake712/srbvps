#!/bin/bash
# SRBMiner 一鍵開機自啟 - 自定義錢包 + Worker
# 用法:
# ./reboot.sh                                    -> 互動輸入兩個
# ./reboot.sh 0x你的錢包 myworker               -> 帶參數直接跑
# curl ... | bash -s -- 0x錢包 myworker          -> GitHub 一鍵帶參數

set -e

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79%"
API_PORT="60131"
REF_CODE="t2xb-3vc4"
DEFAULT_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"

if [ -f "/root/SRBMiner-Multi-3-4-6/SRBMiner-MULTI" ]; then
  MINER_DIR="/root/SRBMiner-Multi-3-4-6"
  MINER_BIN="/root/SRBMiner-Multi-3-4-6/SRBMiner-MULTI"
elif [ -f "./SRBMiner-Multi-3-4-6/SRBMiner-MULTI" ]; then
  MINER_DIR="$(pwd)/SRBMiner-Multi-3-4-6"
  MINER_BIN="$(pwd)/SRBMiner-Multi-3-4-6/SRBMiner-MULTI"
else
  echo "❌ 找不到 SRBMiner-MULTI"
  exit 1
fi

# === 1. 輸入錢包 ===
if [ -n "$1" ]; then
  WALLET_RAW="$1"
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "請輸入 POL 錢包地址"
  echo "範例: 0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
  echo "直接按 Enter 使用預設: $DEFAULT_WALLET"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "錢包地址: " WALLET_RAW < /dev/tty || read -p "錢包地址: " WALLET_RAW
  if [ -z "$WALLET_RAW" ]; then
    WALLET_RAW="$DEFAULT_WALLET"
  fi
fi

CLEAN_WALLET=$(echo "$WALLET_RAW" | sed 's/^POL://i' | cut -d'.' -f1 | cut -d'#' -f1 | tr -d '[:space:]')

# === 2. 輸入 Worker ===
if [ -n "$2" ]; then
  WORKER_RAW="$2"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "請輸入 Worker 名稱 (礦池後台顯示)"
  echo "直接按 Enter 使用主機名: $(hostname)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Worker 名稱: " WORKER_RAW < /dev/tty || read -p "Worker 名稱: " WORKER_RAW
  if [ -z "$WORKER_RAW" ]; then
    WORKER_RAW=$(hostname | cut -c1-20)
  fi
fi

WORKER=$(echo "$WORKER_RAW" | tr -cd 'a-zA-Z0-9-_')
if [ -z "$WORKER" ]; then
  WORKER=$(hostname | cut -c1-20)
fi

FULL_WALLET="POL:${CLEAN_WALLET}.${WORKER}#${REF_CODE}"

echo ""
echo "✅ 最終設定:"
echo "   錢包: $CLEAN_WALLET"
echo "   Worker: $WORKER"
echo "   完整: $FULL_WALLET"
echo "   礦機: $MINER_BIN"
echo ""

cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner XelisHashv3 - $WORKER
After=network.target

[Service]
Type=exec
WorkingDirectory=$MINER_DIR
ExecStart=$MINER_BIN --algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --disable-worker-watchdog --cpu-threads 1 --extended-log --large-pages --msr enable --randomx-use-1gb-pages --api-port $API_PORT
Restart=always
RestartSec=10
CPUQuota=$CPU_QUOTA

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable srbminer
systemctl restart srbminer

echo "🎉 完成！錢包 $CLEAN_WALLET | Worker $WORKER"
systemctl status srbminer --no-pager -l | head -n 15
echo ""
echo "日誌: journalctl -u srbminer -f"
