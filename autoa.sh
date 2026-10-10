#!/bin/sh
# SRBMiner Alpine 低記憶體版 - 修復 Killed 問題
set -e
if [ "$(id -u)" -ne 0 ]; then echo "請用 root"; exit 1; fi

POOL="xelishash.unmineable.com:3333"
ALGO="xelishashv3"
CPU_QUOTA="79"
API_PORT="60131"
BASE_WALLET="0x4da2a435251da9f103cc3fb2452a80c365e0d1fd"
REF_CODE="t2xb-3vc4"

# 1. 先檢查記憶體，不夠就建 swap
free -h
if [ ! -f /swapfile ]; then
  echo "建立 512M swap 防止再被 Kill..."
  fallocate -l 512M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=512
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile 2>/dev/null || echo "LXC容器不允許swapon，請到面板把記憶體調到512M以上"
fi

# 2. 精簡安裝，一個一個裝，用 --no-cache --no-progress 省RAM
echo "安裝相依..."
apk add --no-cache --no-progress gcompat libstdc++ 2>&1 || apk add --no-cache gcompat libstdc++
apk add --no-cache --no-progress libgcc curl 2>&1 || true
apk add --no-cache --no-progress jq cpulimit 2>&1 || true

# 3. 找礦工
if [ -f "/root/SRBMiner-Multi-3-6-9/SRBMiner-MULTI" ]; then
  MINER_DIR="/root/SRBMiner-Multi-3-6-9"; MINER_BIN="/root/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"
elif [ -f "./SRBMiner-Multi-3-6-9/SRBMiner-MULTI" ]; then
  MINER_DIR="$(pwd)/SRBMiner-Multi-3-6-9"; MINER_BIN="$(pwd)/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"
else
  echo "❌ 找不到 SRBMiner-MULTI"; exit 1
fi
chmod +x "$MINER_BIN"

# Worker
WORKER=${1:-$(hostname | cut -c1-20 | tr -cd 'a-zA-Z0-9_-')}
FULL_WALLET="POL:${BASE_WALLET}.${WORKER}#${REF_CODE}"
echo "✅ Worker: $WORKER"

# OpenRC 服務
cat > /etc/init.d/srbminer <<EOF
#!/sbin/openrc-run
name="srbminer"
command="$MINER_BIN"
command_args="--algorithm $ALGO --pool $POOL --wallet $FULL_WALLET --api-enable --cpu-threads 1 --disable-gpu --disable-huge-pages --disable-cpu-optimisations --api-port $API_PORT"
command_background=true
pidfile="/run/srbminer.pid"
directory="$MINER_DIR"
output_log="/var/log/srbminer.log"
error_log="/var/log/srbminer.log"
depend(){ need net; }
start_pre(){ modprobe msr 2>/dev/null || true; checkpath -f -m 0644 /var/log/srbminer.log; }
start_post(){
 sleep 1
 PID=\$(cat \$pidfile 2>/dev/null); [ -z "\$PID" ] && PID=\$(pgrep -f SRBMiner-MULTI | head -n1)
 if [ -n "\$PID" ] && command -v cpulimit >/dev/null; then cpulimit -p \$PID -l $CPU_QUOTA -b -q 2>/dev/null &; fi
}
EOF
chmod +x /etc/init.d/srbminer
touch /var/log/srbminer.log
rc-update add srbminer default 2>/dev/null; rc-update add srbminer boot 2>/dev/null; true
rc-service srbminer stop 2>/dev/null; true
rc-service srbminer start
sleep 2; rc-service srbminer status; tail -n 30 /var/log/srbminer.log
