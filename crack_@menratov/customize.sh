#!/system/bin/sh
MODDIR=${MODPATH:-${0%/*}}
ui_print "- credit lock check"
case "$(cat "$MODDIR/module.prop" 2>/dev/null)" in
  *perexodmenratov*) ui_print "- author OK @perexodmenratov" ;;
  *) ui_print "! author lock failed"; exit 1 ;;
esac
find "$MODDIR" -type d -exec chmod 755 {} \;
[ -f "$MODDIR/post-fs-data.sh" ] && chmod 755 "$MODDIR/post-fs-data.sh"
[ -f "$MODDIR/service.sh" ] && chmod 755 "$MODDIR/service.sh"
[ -f "$MODDIR/service_key_bypass.sh" ] && chmod 755 "$MODDIR/service_key_bypass.sh"
[ -f "$MODDIR/clock_sync.sh" ] && chmod 755 "$MODDIR/clock_sync.sh"
[ -f "$MODDIR/update_module_desc.sh" ] && chmod 755 "$MODDIR/update_module_desc.sh"
find "$MODDIR/zygisk" -type f 2>/dev/null | while read -r f; do chmod 755 "$f"; done
find "$MODDIR/payload" -type f 2>/dev/null | while read -r f; do chmod 644 "$f"; done
PAYLOAD="$MODDIR/payload/libPUBGM.so"
[ -f "$PAYLOAD" ] || { ui_print "! payload missing"; exit 1; }
ui_print "- payload OK"
STUB="$MODDIR/zygisk/arm64-v8a.so"
[ -f "$STUB" ] || { ui_print "! zygisk stub missing"; exit 1; }
ui_print "- zygisk OK"
chcon -R u:object_r:system_file:s0 "$MODDIR" 2>/dev/null
ui_print "- locked by @perexodmenratov"
