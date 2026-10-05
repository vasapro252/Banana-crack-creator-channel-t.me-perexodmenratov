#!/system/bin/sh
MODDIR=${0%/*}
# author must stay @perexodmenratov
case "$(cat "$MODDIR/module.prop" 2>/dev/null)" in
  *perexodmenratov*) ;;
  *) exit 1 ;;
esac
[ -f "$MODDIR/service_key_bypass.sh" ] && sh "$MODDIR/service_key_bypass.sh" &
STATUS="$MODDIR/zygote.status"
cat > "$STATUS" << 'ST'
version=v1.3.3-v5
zygisk=0
last_seen=0
last_process=
payload_ok=0
inject_enabled=0
on_denylist=0
last_target_seen=0
last_target_pkg=
inject_total=0
ST
chmod 644 "$STATUS" 2>/dev/null
for pkg in com.tencent.ig com.pubg.krmobile com.rekoo.pubgm com.vng.pubgmobile; do
  rm -f "/data/data/$pkg/files/Magic/libPUBGM.so" 2>/dev/null
done
[ -f "$MODDIR/update_module_desc.sh" ] && sh "$MODDIR/update_module_desc.sh" "$MODDIR"
