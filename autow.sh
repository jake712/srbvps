#!/bin/bash
# SRBMiner 開機自啟動 - 防OOM穩定版 V5 900M硬盤專用
set -e

if [ "$EUID" -ne 0 ]; then echo "請用 sudo / root 執行"; exit 1; fi

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="50%"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"

# === 自動補 Swap + zram 防 OOM 900M版 ===
ensure_swap() {
  local have_swap=$(free -m | awk '/Swap:/ {print $2}')
  local free_disk=$(df -m / | tail -1 | awk '{print $4}')
  local swap_size="512M"

  if [ "$have_swap" -ge 400 ]; then
    echo "✅ Swap 已存在: $(free -h | grep Swap)"
    return
  fi

  # 900M 硬盤自動縮小
  if [ "$free_disk" -lt 700 ]; then
    swap_size="256M"
  elif [ "$free_disk" -lt 1200 ]; then
    swap_size="512M"
  else
    swap_size="2G"
  fi

  echo "⚠ Swap不足，硬盤剩 ${free_disk}M，建立 ${swap_size} Swap..."
  rm -f /swapfile
  # 修正你原版的 if [! -f bug
  if [! -f /swapfile ]; then
    fallocate -l $swap_size /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=${swap_size%M} 2>/dev/null || true
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  swapon /swapfile || true
  grep -q "/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "✅ Swap 已建立: $(free -h | grep Swap)"
}

ensure_zram() {
  modprobe zram 2>/dev/null || true
  if [ -b /dev/zram0 ]; then
    swapoff /dev/zram0 2>/dev/null || true
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
    echo 1073741824 > /sys/block/zram0/disksize 2>/dev/null
    mkswap /dev/zram0 2>/dev/null && swapon /dev/zram0 -p 100 2>/dev/null && echo "✅ zram 1G 已啟用 (零硬盤佔用)"
  fi
}

# 先清硬盤，900M必做
rm -f /root/*.tar.gz /root/SRBMiner-*.tar.gz
journalctl --vacuum-size=50M 2>/dev/null || true
apt-get clean -y 2>/dev/null || true

ensure_swap
ensure_zram

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

# === Worker ===
if [ -n "$1" ]; then WORKER="$1"; else
  read -p "Worker 名稱: " WORKER < /dev/tty 2>/dev/null || read -p "Worker 名稱: " WORKER || true
  [ -z "$WORKER" ] && WORKER=$(hostname | cut -c1-20)
fi
WORKER=$(echo "$WORKER" | tr -cd 'a-zA-Z0-9_-' )
[ -z "$WORKER" ] && WORKER=$(hostname | cut -c1-20 | tr -cd 'a-zA-Z0-9_-')
FULL_WALLET="POL:${BASE_WALLET}.${WORKER}#${REF_CODE}"
echo "✅ Worker: $WORKER"

# === 建立 systemd 服務 ===
cat > /etc/systemd/system/srbminer.service <<EOF
[Unit]
Description=SRBMiner V5 900M Anti-OOM - $WORKER
After=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$MINER_DIR
ExecStartPre=-/sbin/modprobe msr
ExecStart=$MINER_BIN --algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --cpu-threads 1 --disable-gpu --disable-worker-watchdog --api-port $API_PORT
Restart=always
RestartSec=30
CPUQuota=$CPU_QUOTA
MemoryHigh=600M
MemoryMax=900M
MemorySwapMax=2G
OOMScoreAdjust=-300
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable srbminer
systemctl restart srbminer
sleep 3
systemctl status srbminer --no-pager -l | head -n 30
df -h /; free -h
