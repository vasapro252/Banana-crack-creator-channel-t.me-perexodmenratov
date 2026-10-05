#!/system/bin/sh
# MagicPro 模块状态更新
#
# 信源优先级（按 Zygisk Next 官方文档）：
#   1. znctl status  — ZN 1.2.0+ 官方 CLI（原 zygisk-ctl，见 Release v1.2.0 / v1.2.0-Preview3）
#   2. zygisksu module.prop 中 [...] 段 — ZN monitor bind-mount 写入的实时状态（同 ZN 模块卡片）
#   3. MagicPro zygote.status — 本模块 stub 经 Zygisk API companion 上报
#   4. inject.status — 游戏进程 payload 是否 dlopen 成功
#
# 原则：能读就显示读到的值，读不到就写「不可读」，不做猜测。

MODDIR="${1:-${0%/*}}"
PROP="$MODDIR/module.prop"
STATUS="$MODDIR/zygote.status"
DEBUG="$MODDIR/debug.status"

[ -f "$PROP" ] || exit 0

kv() {
  grep -m1 "^$1=" "$2" 2>/dev/null | cut -d= -f2-
}

boot_time=$(awk '/btime/{print $2; exit}' /proc/stat 2>/dev/null)
boot_time=${boot_time:-0}

# ---------- 查找 Zygisk Next 模块（官方模块 id: zygisksu）----------
ZN_MOD=""
if [ -d /data/adb/modules/zygisksu ]; then
  ZN_MOD="/data/adb/modules/zygisksu"
else
  for d in /data/adb/modules/*; do
    [ -d "$d" ] || continue
    [ -f "$d/bin/zygiskd64" ] || [ -f "$d/bin/zygiskd" ] || continue
    ZN_MOD="$d"
    break
  done
fi

# ---------- 1. 官方 znctl / zygiskd status ----------
zn_ctl_cmd=""
zn_ctl_exit=127
zn_ctl_raw=""

zn_output_usable() {
  [ -n "$1" ] || return 1
  echo "$1" | grep -qiE 'zygote|monitor|inject|root implementation' || return 1
  echo "$1" | grep -qi '^usage:' && return 1
  return 0
}

run_znctl_status() {
  zn_ctl_raw=""
  zn_ctl_exit=127
  zn_ctl_cmd=""

  for bin in \
    "$ZN_MOD/bin/zygiskd64" \
    "$ZN_MOD/bin/zygiskd" \
    /data/adb/ksu/bin/zygiskd64 \
    /data/adb/ksu/bin/zygiskd \
    "$ZN_MOD/bin/znctl" \
    "$ZN_MOD/bin/zygisk-ctl" \
    /data/adb/ksu/bin/znctl
  do
    [ -n "$bin" ] || continue
    [ -x "$bin" ] || [ -f "$bin" ] || continue

    for args in status "dump-zn -sa"; do
      # shellcheck disable=SC2086
      out=$("$bin" $args 2>&1) || true
      if zn_output_usable "$out"; then
        zn_ctl_raw="$out"
        zn_ctl_exit=$?
        zn_ctl_cmd="$bin $args"
        return 0
      fi
    done
  done

  return 1
}

zn_ctl_ok=0
run_znctl_status && zn_ctl_ok=1

# 解析官方 CLI 输出（两种常见格式）：
#   Zygote monitor. :running / Zygote monitor: Running
#   Zygote 64 : injected / zygote (64): Inject failed
#   Zygote secondary 32 : injected / zygote_secondary (32): ...
zn_monitor="unread"
zn_z64="unread"
zn_z32="unread"

parse_zn_inject_line() {
  line=$1
  [ -n "$line" ] || return 1
  if echo "$line" | grep -qiE 'fail|not inject|未注入|not_injected'; then
    printf 'not_injected'
    return 0
  fi
  if echo "$line" | grep -qiE 'inject|injected|已注入'; then
    printf 'injected'
    return 0
  fi
  return 1
}

if [ "$zn_ctl_ok" = "1" ]; then
  line=$(echo "$zn_ctl_raw" | grep -iE 'zygote monitor|monitor\.' | head -n 1)
  if [ -n "$line" ]; then
    echo "$line" | grep -qiE 'running|tracing' && zn_monitor="running"
    echo "$line" | grep -qiE 'stop|exit|crash|stopped|exited' && zn_monitor="stopped"
  fi

  line=$(echo "$zn_ctl_raw" | grep -iE 'zygote.*(64|primary)' | grep -viE '32|secondary' | head -n 1)
  parsed=$(parse_zn_inject_line "$line")
  [ -n "$parsed" ] && zn_z64=$parsed

  line=$(echo "$zn_ctl_raw" | grep -iE 'zygote.*(32|secondary)' | head -n 1)
  parsed=$(parse_zn_inject_line "$line")
  [ -n "$parsed" ] && zn_z32=$parsed
fi

# ---------- 2. ZN module.prop [...] 实时段（与 ZN 模块列表同源）----------
zn_prop_bracket=""
zn_prop_readable=0
if [ -n "$ZN_MOD" ] && [ -f "$ZN_MOD/module.prop" ]; then
  zn_desc=$(grep -m1 '^description=' "$ZN_MOD/module.prop" 2>/dev/null | cut -d= -f2-)
  if [ -n "$zn_desc" ]; then
    zn_prop_readable=1
    zn_prop_bracket=$(printf '%s' "$zn_desc" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
    if [ -n "$zn_prop_bracket" ]; then
      # 仅当 znctl 未给出结果时，用 prop 段补全
      [ "$zn_z64" = "unread" ] && echo "$zn_prop_bracket" | grep -qiE 'zygote64:.*injected|zygote 64:.*injected' && \
        ! echo "$zn_prop_bracket" | grep -qiE 'zygote64:.*not injected|not inject' && zn_z64="injected"
      [ "$zn_z64" = "unread" ] && echo "$zn_prop_bracket" | grep -qiE 'zygote64:.*not injected|not inject' && zn_z64="not_injected"
      [ "$zn_monitor" = "unread" ] && echo "$zn_prop_bracket" | grep -qiE 'monitor:.*tracing|monitor:.*running' && zn_monitor="running"
      [ "$zn_monitor" = "unread" ] && echo "$zn_prop_bracket" | grep -qiE 'monitor:.*stopped|monitor:.*exited' && zn_monitor="stopped"
    fi
  fi
fi

# ---------- 3. MagicPro stub（Zygisk API companion）----------
mp_zygisk=$(kv zygisk "$STATUS")
mp_process=$(kv last_process "$STATUS")
mp_payload=$(kv payload_ok "$STATUS")
mp_deny=$(kv on_denylist "$STATUS")
last_seen=$(kv last_seen "$STATUS")
last_seen=${last_seen:-0}
mp_this_boot=0
[ "$mp_zygisk" = "1" ] && [ "$last_seen" -ge "$boot_time" ] && mp_this_boot=1

# ---------- 4. 注入结果 ----------
inject_result=""
inject_pkg=""
inject_ts=0
for pkg in com.tencent.ig com.pubg.krmobile com.rekoo.pubgm com.vng.pubgmobile; do
  f="/data/data/$pkg/files/Magic/inject.status"
  [ -f "$f" ] || continue
  ts=$(kv ts "$f")
  case "$ts" in
    ''|*[!0-9]*) continue ;;
  esac
  if [ "$ts" -ge "$inject_ts" ]; then
    inject_ts=$ts
    inject_pkg=$(kv pkg "$f")
    [ -z "$inject_pkg" ] && inject_pkg=$pkg
    inject_result=$(kv result "$f")
  fi
done
inject_this_boot=0
[ "$inject_result" = "ok" ] && [ "$inject_ts" -ge "$boot_time" ] && inject_this_boot=1

# ---------- 汇总：Zygisk 框架（ZN 官方信源）----------
format_unread() {
  [ "$1" = "unread" ] && printf '不可读' || printf '%s' "$1"
}

zn_part="ZN:"
if [ "$zn_monitor" != "unread" ] || [ "$zn_z64" != "unread" ] || [ "$zn_z32" != "unread" ]; then
  zn_part="${zn_part}mon=$(format_unread "$zn_monitor"),z64=$(format_unread "$zn_z64")"
  [ "$zn_z32" != "unread" ] && zn_part="${zn_part},z32=$(format_unread "$zn_z32")"
elif [ -n "$zn_prop_bracket" ]; then
  zn_part="${zn_part}prop=[${zn_prop_bracket}]"
elif [ "$zn_ctl_ok" = "1" ]; then
  # CLI 有响应但格式未识别：不算「ZN 坏了」，引导看 debug.status
  zn_part="${zn_part}CLI已响应(见debug)"
elif [ -n "$ZN_MOD" ]; then
  # 越狱 KSU / 非标准 root 上 znctl 常不可用，不代表 Zygisk 未运行
  zn_pid=$(pidof zygiskd64 2>/dev/null || pidof zygiskd 2>/dev/null)
  if [ -n "$zn_pid" ]; then
    zn_part="${zn_part}daemon运行(pid),CLI不可读"
  else
    zn_part="${zn_part}CLI不可读,daemon未运行"
  fi
else
  zn_part="${zn_part}模块未安装"
fi

# MagicPro stub 行
if [ "$mp_this_boot" = "1" ]; then
  mp_part="MP-stub:已加载(${mp_process:-?})"
elif [ -f "$MODDIR/zygisk/arm64-v8a.so" ]; then
  mp_part="MP-stub:未确认(文件在)"
else
  mp_part="MP-stub:缺失"
fi
[ "$mp_deny" = "1" ] && mp_part="${mp_part},denylist"

# 注入行
if [ "$inject_result" = "ok" ]; then
  inj_part="注入:成功·${inject_pkg}"
elif [ "$inject_result" = "fail" ]; then
  inj_part="注入:失败·${inject_pkg}"
else
  inj_part="注入:无记录"
fi

desc="PUBGM | $zn_part | $mp_part | $inj_part"

# ---------- debug.status：完整原始数据，便于交接调试 ----------
{
  echo "# MagicPro debug.status"
  echo "updated=$(date '+%F %T' 2>/dev/null || date)"
  echo "boot_time=$boot_time"
  echo ""
  echo "[zygisk_next_official]"
  echo "module_dir=${ZN_MOD:-missing}"
  echo "znctl_ok=$zn_ctl_ok"
  echo "znctl_cmd=${zn_ctl_cmd:-none}"
  echo "znctl_exit=$zn_ctl_exit"
  echo "zn_monitor=$zn_monitor"
  echo "zn_z64=$zn_z64"
  echo "zn_z32=$zn_z32"
  echo "prop_readable=$zn_prop_readable"
  echo "prop_bracket=${zn_prop_bracket:-none}"
  echo "zn_daemon_pid=$(pidof zygiskd64 2>/dev/null || pidof zygiskd 2>/dev/null || echo none)"
  if [ -n "$zn_ctl_raw" ]; then
    echo "znctl_output<<EOF"
    echo "$zn_ctl_raw"
    echo "EOF"
  fi
  echo ""
  echo "[magicpro_stub]"
  echo "zygisk=$mp_zygisk"
  echo "last_seen=$last_seen"
  echo "last_process=$mp_process"
  echo "payload_ok=$mp_payload"
  echo "on_denylist=$mp_deny"
  echo "this_boot=$mp_this_boot"
  echo ""
  echo "[inject]"
  echo "result=$inject_result"
  echo "pkg=$inject_pkg"
  echo "ts=$inject_ts"
  echo "this_boot=$inject_this_boot"
  echo ""
  echo "[module_prop_line]"
  echo "description=$desc"
} > "$DEBUG" 2>/dev/null
chmod 644 "$DEBUG" 2>/dev/null

tmp="$MODDIR/module.prop.tmp.$$"
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    description=*) printf 'description=%s\n' "$desc" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$PROP" > "$tmp" && mv "$tmp" "$PROP"
chmod 644 "$PROP" 2>/dev/null
