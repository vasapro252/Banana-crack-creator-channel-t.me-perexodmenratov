#!/system/bin/sh
MODDIR=${1:-${0%/*}}
STATUS="$MODDIR/clock_sync.status"
TMP="$STATUS.tmp.$$"
{
  echo "version=1"
  echo "started_epoch=$(date +%s 2>/dev/null || echo 0)"
  echo "auto_time_before=$(settings get global auto_time 2>/dev/null || echo unknown)"
  echo "auto_time_zone_before=$(settings get global auto_time_zone 2>/dev/null || echo unknown)"
  settings put global auto_time 1 >/dev/null 2>&1
  rc_auto=$?
  settings put global auto_time_zone 1 >/dev/null 2>&1
  rc_zone=$?
  echo "enable_auto_time_rc=$rc_auto"
  echo "enable_auto_time_zone_rc=$rc_zone"
  n=1
  refresh_rc=127
  while [ "$n" -le 3 ]; do
    refresh_out=$(cmd network_time_update_service force_refresh 2>&1)
    refresh_rc=$?
    echo "refresh_${n}_rc=$refresh_rc"
    echo "refresh_${n}_out=$(echo "$refresh_out" | tr '\n' ' ' | tr '=' ':')"
    [ "$refresh_rc" -eq 0 ] && break
    sleep 3
    n=$((n + 1))
  done
  sleep 2
  echo "finished_epoch=$(date +%s 2>/dev/null || echo 0)"
  echo "auto_time_after=$(settings get global auto_time 2>/dev/null || echo unknown)"
  echo "auto_time_zone_after=$(settings get global auto_time_zone 2>/dev/null || echo unknown)"
  echo "timezone=$(getprop persist.sys.timezone 2>/dev/null || echo unknown)"
  echo "result=$([ "$refresh_rc" -eq 0 ] && echo refresh_requested || echo auto_time_enabled)"
} > "$TMP"
chmod 644 "$TMP" 2>/dev/null
mv -f "$TMP" "$STATUS"
