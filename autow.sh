#!/bin/bash
# SRBMiner 開機自啟動 - 自定義 Worker 名稱版
# 用法: 
# 1. ./reboot.sh              -> 會提示輸入
# 2. ./reboot.sh myworker01   -> 直接用參數當worker

set -e

# === 固定設定 ===
POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79%"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"

# === 自動偵測路徑 ===
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

# === 自定義輸入 Worker 名稱 ===
if [ -n "$1" ]; then
  # 如果有帶參數: ./reboot.sh vps01
  WORKER="$1"
else
  # 沒有參數就提示輸入，支援 curl | bash 的情況
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "請輸入 Worker 名稱 (顯示在礦池後台)"
  echo "只能用英文數字 - _ ，不能有空白"
  echo "直接按 Enter 會使用主機名: $(hostname)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -p "Worker 名稱: " WORKER < /dev/tty || read -p "Worker 名稱: " WORKER
  if [ -z "$WORKER" ]; then
    WORKER=$(hostname | cut -c1-20)
  fi
fi

# 清理一下特殊符號
WORKER=$(echo "$WORKER" | tr -cd 'a-zA-Z0-9-_')
if [ -z "$WORKER" ]; then
  WORKER=$(hostname | cut -c1-20)
fi

FULL_WALLET="POL:${BASE_WALLET}.${WORKER}#${REF_CODE}"

echo ""
echo "✅ 設定:"
echo "   Worker: $WORKER"
echo "   錢包: $FULL_WALLET"
echo "   礦機: $MINER_BIN"
echo ""

# === 建立 systemd 服務 ===
cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner XelisHashv3 - Worker $WORKER
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

echo "🎉 完成！Worker 名稱: $WORKER"
systemctl status srbminer --no-pager -l | head -n 15
echo ""
echo "查看日誌: journalctl -u srbminer -f"
