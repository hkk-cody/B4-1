#!/usr/bin/env bash
# =====================================================================
# test_monitor.sh — monitor.sh 함수 단위 회귀 검사
#   실행: sudo -u agent-admin bash tests/test_monitor.sh   (Ubuntu VM)
#   임시 디렉토리만 사용하고 운영 로그(/var/log/agent-app)는 건드리지 않는다.
# =====================================================================
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT            # 끝나면(성공/실패 모두) 임시 폴더 삭제

export AGENT_LOG_DIR="$TMP"          # 로그 경로를 임시 폴더로 바꿔서
source "$ROOT/bin/monitor.sh"        # 함수만 불러온다 (main은 실행되지 않음)
pass() { echo "[PASS] $*"; }

# 1) 임계값: 같으면 조용, 초과하면 3개 모두 경고
[[ -z $(print_warning_if_needed 20 10 80) ]]
[[ $(print_warning_if_needed 20.1 10.1 81 | wc -l) -eq 3 ]]
pass 'Threshold: equal values silent, greater values warn'

# 2) 회전: 10MB 꽉 찬 로그 + 회전본 .1~.9 + 과거 .12 파일 → 회전 후에도 총 10개
truncate -s "$MAX_LOG_BYTES" "$LOG_FILE"
for n in {1..9}; do echo "$n" > "$LOG_FILE.$n"; done
echo 12 > "$LOG_FILE.12"                                      # .10 이상 stray 파일
rotate_logs_if_needed 2
echo x >> "$LOG_FILE"
[[ $(stat -c %s "$LOG_FILE.1") -eq $MAX_LOG_BYTES ]]          # 기존 로그가 .1로 이동
[[ $(cat "$LOG_FILE.9") == 8 ]]                               # .8 → .9, 옛 .9는 삭제
[[ ! -e "$LOG_FILE.12" ]]                                     # stray .12 삭제 확인
[[ $(find "$TMP" -name 'monitor.log*' -type f | wc -l) -eq 10 ]]
pass 'Rotation at 10MB keeps 10 files (current + 9, stray backups removed)'

# 3) 경계: 딱 10MB가 되는 건 허용, 넘으면 회전
truncate -s $((MAX_LOG_BYTES - 2)) "$LOG_FILE"
rotate_logs_if_needed 2
[[ -e "$LOG_FILE" ]]
rotate_logs_if_needed 3
[[ ! -e "$LOG_FILE" ]]
pass 'Rotate only when the next line would exceed 10MB'

# 4) 실제 자원 측정값이 숫자인지
[[ $(get_cpu_usage)  =~ ^[0-9]+\.[0-9]$ ]]
[[ $(get_mem_usage)  =~ ^[0-9]+\.[0-9]$ ]]
[[ $(get_disk_usage) =~ ^[0-9]+$ ]]
pass 'CPU/MEM/DISK collection returns numbers'

# 5) 프로세스 정규식: 실제 앱은 찾고, 인자로만 들어간 명령은 무시
grep -Eq "$PROCESS_PATTERN" <<< '/home/agent-admin/agent-app/agent-app-linux-arm64'
grep -Eq "$PROCESS_PATTERN" <<< 'python3 /opt/agent_app.py'
# 주의: set -e 는 '! 명령' 의 실패를 무시하므로 부정 검사는 if 로 직접 처리한다.
for cmd in 'sudo -u agent-admin /home/agent-admin/agent-app/agent-app-linux-arm64' 'vim agent_app.py'; do
  if grep -Eq "$PROCESS_PATTERN" <<< "$cmd"; then echo "[FAIL] matched: $cmd"; exit 1; fi
done
pass 'Process pattern matches the app, ignores parent/editor commands'

# 6) 방화벽: sudo 응답을 가짜 함수로 바꿔 비활성/조회 실패 분기 확인
( sudo() { echo 'Status: inactive'; }; [[ $(check_firewall) == *'not active'* ]] )
( sudo() { return 1; };               [[ $(check_firewall) == *'unavailable'* ]] )
pass 'Firewall inactive / query failure only warn'

echo 'All regression tests passed.'
