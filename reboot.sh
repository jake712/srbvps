#!/bin/bash
# SRBMiner 開機自啟動 一鍵包 - root專用
# 適用: root@...:~# 環境

set -e

# === 設定區，可自行修改 ===
WALLET="POL:0x4da2a435251da9f103cc3fb2452a80c365e0d1fd.rm#t2xb-3vc4"
POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79%"
API_PORT="60131"

# 自動偵測路徑
if [ -f "/root/SRBMiner-Multi-3-4-6/SRBMiner-MULTI" ]; then
  MINER_DIR="/root/SRBMiner-Multi-3-4-6"
  MINER_BIN="/root/SRBMiner-Multi-3-4-6/SRBMiner-MULTI"
elif [ -f "./SRBMiner-Multi-3-4-6/SRBMiner-MULTI" ]; then
  MINER_DIR="$(pwd)/SRBMiner-Multi-3-4-6"
  MINER_BIN="$(pwd)/SRBMiner-Multi-3-4-6/SRBMiner-MULTI"
else
  echo "❌ 找不到 SRBMiner-MULTI"
  echo "請先確認 /root/SRBMiner-Multi-3-4-6/SRBMiner-MULTI 存在"
  ls -lh /root/ | grep SRB || true
  exit 1
fi

echo "✅ 找到礦機: $MINER_BIN"
echo "📁 工作目錄: $MINER_DIR"

# 建立 systemd 服務
cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner XelisHashv3 - OneClick
After=network.target

[Service]
Type=exec
WorkingDirectory=$MINER_DIR
ExecStart=$MINER_BIN --algorithm $ALGO --pool $POOL --wallet $WALLET --api-enable --disable-worker-watchdog --cpu-threads 1 --extended-log --large-pages --msr enable --randomx-use-1gb-pages --api-port $API_PORT
Restart=always
RestartSec=10
CPUQuota=$CPU_QUOTA

[Install]
WantedBy=multi-user.target
EOF

echo "🔧 重載 systemd..."
systemctl daemon-reload
systemctl enable srbminer
systemctl restart srbminer

echo ""
echo "🎉 安裝完成！已設為開機自啟動"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl status srbminer --no-pager -l | head -n 20
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "常用指令："
echo "  查看日誌: journalctl -u srbminer -f"
echo "  查看狀態: systemctl status srbminer"
echo "  停止:     systemctl stop srbminer"
echo "  卸載:     systemctl disable --now srbminer && rm /etc/systemd/system/srbminer.service"
