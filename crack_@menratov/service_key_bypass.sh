#!/system/bin/sh
# fixed JSON server — listen 80+8080, clean response
MODDIR=${0%/*}
W=/data/local/tmp/.banan_ks
mkdir -p "$W"

B1="@perexodmenratov"
C1="t.me/perexodmenratov"
case "$B1" in *perexodmenratov*) ;; *) exit 1 ;; esac

pkill -9 -f "$W/server.py" 2>/dev/null
pkill -9 -f "server.py" 2>/dev/null
sleep 1

# write clean server (no shell expansion inside JSON)
cat > "$W/server.py" << 'PY'
# -*- coding: utf-8 -*-
import http.server, socketserver, json, threading, sys

BODY = json.dumps({
    "valid": True,
    "status": "ok",
    "success": True,
    "code": 0,
    "msg": "ok",
    "message": "ok",
    "key": "BANAN-30D-23E9A60D824G2FF1",
    "kami": "BANAN-30D-23E9A60D824G2FF1",
    "days": 9999,
    "expire": "2099-12-31",
    "expire_time": 4102444800,
    "vip": True,
    "ban": False,
    "data": {
        "valid": True,
        "expire": "2099-12-31",
        "days": 9999,
        "vip": True
    },
    "credit": "@perexodmenratov",
    "channel": "t.me/perexodmenratov"
}, ensure_ascii=False).encode("utf-8")

class H(http.server.BaseHTTPRequestHandler):
    def _s(self):
        try:
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(BODY)))
            self.end_headers()
            self.wfile.write(BODY)
        except Exception:
            pass
    def do_GET(self): self._s()
    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length", 0))
            if n > 0:
                self.rfile.read(n)
        except Exception:
            pass
        self._s()
    def do_OPTIONS(self): self._s()
    def log_message(self, *a): pass

def serve(port):
    try:
        socketserver.ThreadingTCPServer.allow_reuse_address = True
        with socketserver.ThreadingTCPServer(("0.0.0.0", port), H) as s:
            s.serve_forever()
    except Exception as e:
        sys.stderr.write("port %s fail: %s\n" % (port, e))

for p in (80, 8080, 443, 8888):
    t = threading.Thread(target=serve, args=(p,), daemon=True)
    t.start()

# keep main thread alive
import time
while True:
    time.sleep(3600)
PY

if command -v python3 >/dev/null 2>&1; then
  python3 "$W/server.py" >/dev/null 2>&1 &
elif command -v python >/dev/null 2>&1; then
  python "$W/server.py" >/dev/null 2>&1 &
else
  echo "no python" > "$W/fail"
fi
sleep 2

# hosts
HFILE="$W/hosts"
cp /system/etc/hosts "$HFILE" 2>/dev/null || printf "127.0.0.1 localhost\n::1 localhost\n" > "$HFILE"
for d in banan-cheat.com api.banan-cheat.com www.banan-cheat.com \
         filyatrayder.com api.filyatrayder.com www.filyatrayder.com \
         filyatrayder.tg api.filya.com; do
  sed -i "/$d/d" "$HFILE" 2>/dev/null
  echo "127.0.0.1 $d" >> "$HFILE"
done
umount /system/etc/hosts 2>/dev/null
mount --bind "$HFILE" /system/etc/hosts 2>/dev/null || true

# optional: redirect only when dest is already 127.0.0.1 is not needed
# if client uses HTTPS to 127.0.0.1:443, plain server may still fail TLS handshake
# try iptables redirect 443->80 only for local — skip global to not break net

KEY="$B1"
echo "$KEY" > "$W/key.txt"
echo "$KEY" > /data/local/tmp/key.txt
for pkg in com.tencent.ig com.pubg.krmobile com.rekoo.pubgm com.vng.pubgmobile; do
  mkdir -p "/data/data/$pkg/files" 2>/dev/null
  echo "$KEY" > "/data/data/$pkg/key.txt" 2>/dev/null
  echo "$KEY" > "/data/data/$pkg/files/key.txt" 2>/dev/null
done
echo "crack by $B1 | $C1" > "$W/credit.txt"
