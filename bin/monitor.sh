#!/usr/bin/env bash
# =====================================================================
# monitor.sh — 앱 상태 점검 + 시스템 자원 측정 + 로그 기록
#   실행 계정 : agent-admin (cron이 매분 실행)
#   실패 기준 : 앱 프로세스 없음 / 15034 포트 LISTEN 아님 → exit 1
#   경고 기준 : 방화벽 비활성, CPU>20%, MEM>10%, DISK>80% → [WARNING]만 출력
# =====================================================================
set -euo pipefail   # 오류(-e)·미정의 변수(-u)·파이프 중간 실패(pipefail) 시 즉시 중단
export LC_ALL=C     # 소수점·날짜 등 출력 형식을 표준(영문)으로 고정

# ── 설정값 ───────────────────────────────────────────────────────────
# cron은 /etc/profile.d 환경 변수를 읽지 않으므로 ':-기본값'으로 대비한다.
AGENT_PORT="${AGENT_PORT:-15034}"
LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="$LOG_DIR/monitor.log"

CPU_LIMIT=20
MEM_LIMIT=10
DISK_LIMIT=80

MAX_LOG_BYTES=$((10 * 1024 * 1024))   # 10MB
MAX_LOG_FILES=10                      # monitor.log + monitor.log.1 ~ .9

# 앱 프로세스를 찾는 정규식 (아래 check_process 설명 참고)
PROCESS_PATTERN='^([^ ]*/)?(agent-app-linux-(arm64|x86)|python[0-9.]* [^ ]*agent_app[.]py)( |$)'

warn() { echo "[WARNING] $*"; }

# ── 1. 앱 프로세스 확인 ──────────────────────────────────────────────
# pgrep -f 는 "전체 명령줄"에서 정규식을 찾는다.
# 맨 앞을 ^ 로 고정해 "실행 파일 자체"가 앱인 프로세스만 찾는다.
#   (예: 'sudo ... agent-app-linux-arm64' 처럼 인자로만 들어간 명령은 제외)
# 제공 바이너리(arm64/x86) 또는 python 으로 실행한 agent_app.py 를 인정한다.
check_process() {
  if PROCESS_PID=$(pgrep -o -f "$PROCESS_PATTERN"); then   # -o: 가장 오래된 프로세스 1개
    echo "Checking agent process... [OK] (PID: $PROCESS_PID)"
  else
    echo "Checking agent process... [FAIL]"
    return 1
  fi
}

# ── 2. 포트 LISTEN 확인 ─────────────────────────────────────────────
# ss -H(제목 없음) -l(LISTEN) -t(TCP) -n(숫자) + 'sport = :포트' 필터
check_port() {
  if [[ -n $(ss -Hltn "sport = :$AGENT_PORT") ]]; then
    echo "Checking port $AGENT_PORT... [OK]"
  else
    echo "Checking port $AGENT_PORT... [FAIL]"
    return 1
  fi
}

# ── 3. 방화벽 확인 (경고만, 종료하지 않음) ───────────────────────────
# setup.sh가 agent-admin에게 'ufw status' 하나만 비밀번호 없이(sudo -n) 허용해 두었다.
check_firewall() {
  local status
  if ! status=$(sudo -n /usr/sbin/ufw status 2>&1); then
    warn 'Firewall status unavailable (permission or command failure)'
  elif [[ $status == *'Status: active'* ]]; then
    echo '[INFO] Firewall status: ufw active'
  else
    warn 'Firewall is not active (ufw)'
  fi
}

# ── 4. 자원 측정 ────────────────────────────────────────────────────
# CPU: /proc/stat 첫 줄은 부팅 후 누적 시간이다.
#   cpu  user nice system idle iowait irq softirq steal ...
#   1초 간격으로 두 번 읽어 "늘어난 전체 시간 중 놀지 않은 비율"을 구한다.
get_cpu_usage() {
  # awk 출력: "전체시간 대기시간"  (대기시간 = idle + iowait)
  local snap='/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6}'
  local total1 idle1 total2 idle2
  read -r total1 idle1 < <(awk "$snap" /proc/stat)
  sleep 1
  read -r total2 idle2 < <(awk "$snap" /proc/stat)
  awk -v t=$((total2 - total1)) -v i=$((idle2 - idle1)) \
    'BEGIN { printf "%.1f", (t > 0 ? 100 * (t - i) / t : 0) }'
}

# MEM: free 의 Mem 줄 → $2=total, $7=available(실제로 더 쓸 수 있는 양)
get_mem_usage() {
  free | awk '/^Mem:/ { printf "%.1f", 100 * ($2 - $7) / $2 }'
}

# DISK: 루트(/) 파티션 사용률. '23%' 에서 숫자만 남긴다.
get_disk_usage() {
  df --output=pcent / | tail -n 1 | tr -dc '0-9'
}

# ── 5. 임계값 경고 ──────────────────────────────────────────────────
# Bash는 소수 비교를 못 하므로 awk로 비교한다. (같으면 경고 X, "초과"일 때만)
print_warning_if_needed() {
  awk -v cpu="$1" -v mem="$2" -v disk="$3" \
      -v ct="$CPU_LIMIT" -v mt="$MEM_LIMIT" -v dt="$DISK_LIMIT" 'BEGIN {
    if (cpu  > ct) printf "[WARNING] CPU threshold exceeded (%.1f%% > %s%%)\n",  cpu,  ct
    if (mem  > mt) printf "[WARNING] MEM threshold exceeded (%.1f%% > %s%%)\n",  mem,  mt
    if (disk > dt) printf "[WARNING] DISK threshold exceeded (%s%% > %s%%)\n",   disk, dt
  }'
}

# ── 6. 로그 회전 ────────────────────────────────────────────────────
# 새 줄($1 바이트)을 붙이면 10MB를 넘는 경우에만 회전한다.
#   .8→.9, .7→.8, ... .1→.2, monitor.log→.1  (기존 .9는 mv로 덮여 삭제됨)
rotate_logs_if_needed() {
  local size i file suffix
  size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)   # 파일이 없으면 0
  (( size + $1 > MAX_LOG_BYTES )) || return 0

  # .10 이상 기존 회전본 및 가장 오래된 회전본 정리 (총 MAX_LOG_FILES개 유지)
  for file in "$LOG_FILE".[0-9]*; do
    [[ -f "$file" ]] || continue
    suffix=${file##*.}
    if (( 10#$suffix >= MAX_LOG_FILES - 1 )); then
      rm -f -- "$file"
    fi
  done

  for (( i = MAX_LOG_FILES - 2; i >= 1; i-- )); do
    if [[ -f "$LOG_FILE.$i" ]]; then
      mv -f "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
    fi
  done
  mv -f "$LOG_FILE" "$LOG_FILE.1"
}

# ── main: 위 함수들을 순서대로 연결 ─────────────────────────────────
main() {
  local cpu mem disk line

  # cron과 수동 실행이 겹쳐 로그가 꼬이지 않도록 잠금(flock)을 건다.
  mkdir -p "$LOG_DIR"
  exec 9> "$LOG_DIR/.monitor.lock"          # 9번 파일 디스크립터로 잠금 파일 열기
  if ! flock -n 9; then                     # -n: 이미 잠겨 있으면 기다리지 않고 실패
    echo '[INFO] Another monitor is running; skipped'
    return 0
  fi

  printf '====== SYSTEM MONITOR RESULT ======\n\n[HEALTH CHECK]\n'
  check_process || return 1                 # 실패 → main이 1 반환 → 스크립트 exit 1
  check_port    || return 1

  cpu=$(get_cpu_usage)
  mem=$(get_mem_usage)
  disk=$(get_disk_usage)
  printf '\n[RESOURCE MONITORING]\nCPU Usage : %s%%\nMEM Usage : %s%%\nDISK Used : %s%%\n\n' \
    "$cpu" "$mem" "$disk"

  check_firewall
  print_warning_if_needed "$cpu" "$mem" "$disk"

  # 로그 형식: [YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
  line="[$(date '+%Y-%m-%d %H:%M:%S')] PID:$PROCESS_PID CPU:$cpu% MEM:$mem% DISK_USED:$disk%"
  rotate_logs_if_needed $(( ${#line} + 1 ))  # +1 = 줄바꿈 문자
  echo "$line" >> "$LOG_FILE"
  printf '\n[INFO] Log appended: %s\n' "$LOG_FILE"
}

# 직접 실행할 때만 main 실행. (테스트에서 source 하면 함수만 불러온다)
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
