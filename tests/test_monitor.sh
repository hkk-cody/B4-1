#!/usr/bin/env bash
# 실제 Linux에서 실행하는 경계값/회전/보고서 회귀 검사. 운영 로그는 사용하지 않는다.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export AGENT_LOG_DIR="$TMP"
source "$ROOT/bin/monitor.sh"
pass() { printf '[PASS] %s\n' "$*"; }
[[ -z $(print_warning_if_needed 20 10 80) ]]
[[ $(print_warning_if_needed 20.1 10.1 80.1 | wc -l) -eq 3 ]]
pass 'Threshold boundaries: equality silent; all three greater values warn'
# 실제 10MiB 한계와 현재 파일을 포함한 최대 개수를 확인한다.
truncate -s "$MAX_LOG_BYTES" "$AGENT_LOG_FILE"
for n in {1..9} 12; do printf '%s\n' "$n" > "$AGENT_LOG_FILE.$n"; done
rotate_logs_if_needed 2
printf 'x\n' >> "$AGENT_LOG_FILE"
[[ $(stat -c %s "$AGENT_LOG_FILE.1") -eq "$MAX_LOG_BYTES" ]]
[[ $(find "$TMP" -name 'monitor.log*' -type f | wc -l) -eq 10 ]]
[[ ! -e "$AGENT_LOG_FILE.12" ]]
[[ $(cat "$AGENT_LOG_FILE.9") == 8 ]]
pass '10MiB rotation; maximum 10 files; oldest and stray backups removed'
truncate -s "$((MAX_LOG_BYTES-2))" "$AGENT_LOG_FILE"
rotate_logs_if_needed 2
[[ $(stat -c %s "$AGENT_LOG_FILE") -eq "$((MAX_LOG_BYTES-2))" ]]
rotate_logs_if_needed 3
[[ ! -e "$AGENT_LOG_FILE" ]]
pass 'Rotate before append would exceed limit; exact limit is allowed'
[[ $(get_cpu_usage) =~ ^[0-9]+[.][0-9]+$ ]]
[[ $(get_mem_usage) =~ ^[0-9]+[.][0-9]+$ ]]
[[ $(get_disk_usage) =~ ^[0-9]+$ ]]
pass 'Real Linux CPU/MEM/DISK collection produces numeric results'
cat > "$TMP/samples.log" <<'SAMPLES'
[2026-09-06 12:00:00] PID:1 CPU:10.0% MEM:20.0% DISK_USED:30%
[2026-09-06 12:01:00] PID:1 CPU:30.0% MEM:40.0% DISK_USED:50%
SAMPLES
bash "$ROOT/bin/report.sh" "$TMP/samples.log" > "$TMP/report"
grep -q 'Average : 20.0%' "$TMP/report"
grep -q 'Average : 30.0%' "$TMP/report"
grep -q 'Average : 40.0%' "$TMP/report"
grep -q 'Data Points: 2 samples' "$TMP/report"
bash "$ROOT/bin/report.sh" "$TMP/samples.log" '2026-09-06 12:01:00' '2026-09-06 12:01:00' | grep -q 'Data Points: 1 samples'
pass 'Report averages and inclusive time range'
# 방화벽 명령 응답을 대체하여 비활성과 권한 오류의 경고 분기를 검사한다.
(
  sudo() { printf 'Status: inactive\n'; }
  output=$(check_firewall)
  [[ $output == *'Firewall is not active'* ]]
)
(
  sudo() { return 1; }
  output=$(check_firewall)
  [[ $output == *'status unavailable'* ]]
)
pass 'Simulated inactive firewall and query failure warn without exiting'
printf 'malformed log\n[2026-09-06 12:00:00] PID:1 CPU:bad%% MEM:%% DISK_USED:%%\n' > "$TMP/invalid.log"
bash "$ROOT/bin/report.sh" "$TMP/invalid.log" | grep -q 'Data Points: 0 samples'
if bash "$ROOT/bin/report.sh" "$TMP/samples.log" '2026-09-07 00:00:00' '2026-09-06 00:00:00' >/dev/null 2>&1; then exit 1; fi
pass 'Malformed log skipped and inverted time range rejected'
printf 'All regression tests passed.\n'
