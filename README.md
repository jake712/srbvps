# srbvps
SRBMiner run on Linux vps
# srbvps
register account on : [(https://unmineable.com)](https://unmineable.com/?ref=U-AJUCZB)

Set auto payout

replace your pol address on 0x4da2a435251da9f103cc3fb2452a80c365e0d1fd.g

.g you can set as your worker name

#t2xb-3vc4 is my ref code that can reduce 0.75% fee

cpu-threads is up on your vps cpu
```
sudo -i
curl -L -O https://github.com/doktor83/SRBMiner-Multi/releases/download/3.6.9/SRBMiner-Multi-3-6-9-Linux.tar.gz &&
tar -zxvf SRBMiner-Multi-3-6-9-Linux.tar.gz &&
apt-get install cpulimit -y
cpulimit -l 79 -- ./SRBMiner-Multi-3-6-9/SRBMiner-MULTI --algorithm xelishashv3 --pool xelishash.unmineable.com:3333 --wallet POL:0x4da2a435251da9f103cc3fb2452a80c365e0d1fd.g#t2xb-3vc4 --api-enable --cpu-threads 1--disable-worker-watchdog --disable-gpu --extended-log --large-pages --msr enable --randomx-use-1gb-pages --api-port 60131

```
