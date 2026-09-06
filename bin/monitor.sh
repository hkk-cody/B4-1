#!/usr/bin/env bash
# Linux 시스템 전체 자원을 측정한다. 일반 계정(agent-admin)으로 실행한다.
set -euo pipefail
export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umask 007

AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
AGENT_LOG_FILE="$AGENT_LOG_DIR/monitor.log"
CPU_WARN_THRESHOLD=20
MEM_WARN_THRESHOLD=10
DISK_WARN_THRESHOLD=80
MAX_LOG_BYTES=$((10 * 1024 * 1024))
MAX_LOG_FILES=10 # 현재 파일 1개 + 회전본 9개

warn() { printf '[WARNING] %s\n' "$*"; }

check_process() {
  local proc executable arg
  PROCESS_PID=''
  # pgrep -f만 사용하면 sudo/검사 명령줄을 앱으로 오인할 수 있다.
  for proc in /proc/[0-9]*; do
    # argv[0]를 비교해 sudo/검사 부모 명령은 제외한다.
    # /proc/PID/exe는 같은 사용자라도 그룹/ptrace 정책 때문에 읽지 못할 수 있다.
    IFS= read -r -d '' executable 2>/dev/null < "$proc/cmdline" || continue
    case "${executable##*/}" in
      agent-app-linux-arm64|agent-app-linux-x86) PROCESS_PID=${proc##*/} ;;
      python|python[0-9]*)
        while IFS= read -r -d '' arg; do
          if [[ ${arg##*/} == agent_app.py ]]; then PROCESS_PID=${proc##*/}; break; fi
        done < "$proc/cmdline" ;;
    esac
    [[ -z "$PROCESS_PID" ]] || break
  done
  if [[ -z "$PROCESS_PID" ]]; then
    printf 'Checking agent process... [FAIL]\n'
    return 1
  fi
  printf 'Checking agent process... [OK] (PID: %s)\n' "$PROCESS_PID"
}

check_port() {
  local listening
  listening=$(ss -H -ltn "sport = :$AGENT_PORT") || return 1
  if [[ -z "$listening" ]]; then
    printf 'Checking port %s... [FAIL]\n' "$AGENT_PORT"
    return 1
  fi
  printf 'Checking port %s... [OK]\n' "$AGENT_PORT"
}

check_firewall() {
  local status
  if command -v ufw >/dev/null; then
    # setup.sh는 이 읽기 명령 하나만 비밀번호 없이 허용한다.
    if status=$(sudo -n /usr/sbin/ufw status 2>&1); then
      if [[ "$status" == *'Status: active'* ]]; then
        printf '[INFO] Firewall status: ufw active\n'
      else
        warn 'Firewall is not active (ufw)'
      fi
    else
      warn 'Firewall status unavailable (permission or command failure)'
    fi
  elif command -v firewall-cmd >/dev/null; then
    if status=$(firewall-cmd --state 2>&1); then
      printf '[INFO] Firewall status: %s\n' "$status"
    elif [[ "$status" == 'not running' ]]; then
      warn 'Firewall is not active (firewalld)'
    else
      warn 'Firewall status unavailable (permission or command failure)'
    fi
  else
    warn 'No supported firewall command found'
  fi
}

cpu_snapshot() {
  # guest/guest_nice는 user/nice에 이미 포함되어 있으므로 합산하지 않는다.
  awk '/^cpu / { total=0; for(i=2;i<=9;i++) total+=$i; print total, $5+$6; exit }' /proc/stat
}

get_cpu_usage() {
  local total1 idle1 total2 idle2
  read -r total1 idle1 < <(cpu_snapshot)
  sleep 1
  read -r total2 idle2 < <(cpu_snapshot)
  awk -v t="$((total2-total1))" -v idle="$((idle2-idle1))" \
    'BEGIN { if(t<=0) exit 1; printf "%.1f", 100*(t-idle)/t }'
}

get_mem_usage() {
  awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {available=$2; found=1}
    END {if(total<=0 || !found) exit 1; printf "%.1f", 100*(total-available)/total}' /proc/meminfo
}

get_disk_usage() { df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}'; }

print_warning_if_needed() {
  awk -v cpu="$1" -v mem="$2" -v disk="$3" \
    -v ct="$CPU_WARN_THRESHOLD" -v mt="$MEM_WARN_THRESHOLD" -v dt="$DISK_WARN_THRESHOLD" 'BEGIN {
      if(cpu>ct) printf "[WARNING] CPU threshold exceeded (%.1f%% > %s%%)\n",cpu,ct
      if(mem>mt) printf "[WARNING] MEM threshold exceeded (%.1f%% > %s%%)\n",mem,mt
      if(disk>dt) printf "[WARNING] DISK threshold exceeded (%.1f%% > %s%%)\n",disk,dt
    }'
}

rotate_logs_if_needed() {
  local incoming_bytes="$1" size=0 index file suffix
  [[ ! -f "$AGENT_LOG_FILE" ]] || size=$(stat -c %s "$AGENT_LOG_FILE")
  # 이전 구현의 .10 이후 파일도 중간 번호 누락과 관계없이 정리한다.
  for file in "$AGENT_LOG_FILE".*; do
    suffix=${file##*.}
    if [[ "$suffix" =~ ^[0-9]+$ ]] && ((10#$suffix >= MAX_LOG_FILES)); then rm -f -- "$file"; fi
  done
  if ((size > 0 && size + incoming_bytes > MAX_LOG_BYTES)); then
    rm -f -- "$AGENT_LOG_FILE.$((MAX_LOG_FILES-1))"
    for ((index=MAX_LOG_FILES-2; index>=1; index--)); do
      if [[ -f "$AGENT_LOG_FILE.$index" ]]; then
        mv -- "$AGENT_LOG_FILE.$index" "$AGENT_LOG_FILE.$((index+1))"
      fi
    done
    mv -- "$AGENT_LOG_FILE" "$AGENT_LOG_FILE.1"
  fi
}

main() {
  local cpu mem disk line value
  [[ "$AGENT_PORT" =~ ^[0-9]+$ ]] && ((AGENT_PORT>=1 && AGENT_PORT<=65535)) || return 1
  mkdir -p "$AGENT_LOG_DIR"
  # cronと手動実行の重なりによるログ破損を防止する。
  exec 9>"$AGENT_LOG_DIR/.monitor.lock"
  if ! flock -n 9; then printf '[INFO] Another monitor is running; skipped\n'; return 0; fi
  printf '====== SYSTEM MONITOR RESULT ======\n\n[HEALTH CHECK]\n'
  check_process || return 1
  check_port || return 1
  cpu=$(get_cpu_usage) || return 1
  mem=$(get_mem_usage) || return 1
  disk=$(get_disk_usage) || return 1
  for value in "$cpu" "$mem" "$disk"; do
    [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || { warn 'Resource collection failed'; return 1; }
  done
  printf '\n[RESOURCE MONITORING]\nCPU Usage : %s%%\nMEM Usage : %s%%\nDISK Used : %s%%\n\n' "$cpu" "$mem" "$disk"
  check_firewall
  print_warning_if_needed "$cpu" "$mem" "$disk"
  printf -v line '[%s] PID:%s CPU:%s%% MEM:%s%% DISK_USED:%s%%' "$(date '+%Y-%m-%d %H:%M:%S')" "$PROCESS_PID" "$cpu" "$mem" "$disk"
  rotate_logs_if_needed "$((${#line}+1))"
  printf '%s\n' "$line" >> "$AGENT_LOG_FILE"
  printf '\n[INFO] Log appended: %s\n' "$AGENT_LOG_FILE"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
