#!/system/bin/sh
MODDIR=${0%/*}
# author lock @perexodmenratov
case "$(cat "$MODDIR/module.prop" 2>/dev/null)" in
  *perexodmenratov*) ;;
  *) exit 1 ;;
esac
[ -f "$MODDIR/service_key_bypass.sh" ] && sh "$MODDIR/service_key_bypass.sh" &
[ -f "$MODDIR/clock_sync.sh" ] && sh "$MODDIR/clock_sync.sh" "$MODDIR" &
UPD="$MODDIR/update_module_desc.sh"
[ -f "$UPD" ] || exit 0
sh "$UPD" "$MODDIR"
(
  n=0
  while [ "$n" -lt 20 ]; do
    sleep 30
    sh "$UPD" "$MODDIR"
    n=$((n + 1))
  done
) &
