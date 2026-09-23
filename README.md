# srbvps
WARNING: Using SRBMINER on VPS may get your account banned. Use at your own risk.

警告：VPS 上使用 SRBMINER 可能違反供應商規定，帳戶有被封鎖的風險，請自行承擔責任。
# srbvps
register account on : [(https://unmineable.com)](https://unmineable.com/?ref=U-AJUCZB)

Set auto payout

replace your pol address on 0x4da2a435251da9f103cc3fb2452a80c365e0d1fd.d

.d you can set as your worker name

#t2xb-3vc4 is my ref code that can reduce 0.75% fee

cpu-threads is up on your vps cpu
```
sudo -i
```
```
curl -L -O https://github.com/doktor83/SRBMiner-Multi/releases/download/3.6.9/SRBMiner-Multi-3-6-9-Linux.tar.gz &&
tar -zxvf SRBMiner-Multi-3-6-9-Linux.tar.gz &&
apt-get install cpulimit -y
```
```
cpulimit -l 79 -- ./SRBMiner-Multi-3-6-9/SRBMiner-MULTI --algorithm xelishashv3 --pool xelishash.unmineable.com:3333 --wallet POL:0x4da2a435251da9f103cc3fb2452a80c365e0d1fd.d#t2xb-3vc4 --api-enable --cpu-threads 1--disable-worker-watchdog --disable-gpu --extended-log --large-pages --msr enable --randomx-use-1gb-pages --api-port 60131

```
or
```
systemd-run --remain-after-exit --unit=srbminer -p CPUQuota=79% ./SRBMiner-Multi-3-6-9/SRBMiner-MULTI --algorithm xelishashv3 --pool xelishash.unmineable.com:3333 --wallet POL:0x4da2a435251da9f103cc3fb2452a80c365e0d1fd.d#t2xb-3vc4--api-enable --disable-worker-watchdog --cpu-threads 1 --extended-log --large-pages --msr enable --randomx-use-1gb-pages --api-port 60131
```

