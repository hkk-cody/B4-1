#!/usr/bin/env bash
# 앱 실행 중 VM root로 실행한다. 앱을 SIGINT로 종료한 뒤 다시 시작한다.
set -euo pipefail
APP=/home/agent-admin/agent-app
TMP=$(mktemp -d)
cleanup() {
  rm -rf "$TMP"
  if ! ss -H -ltn 'sport = :15034' | grep -q .; then
    systemd-run --unit=agent-assignment --property=User=agent-admin --property=Group=agent-admin --property=KillSignal=SIGINT "$APP/bin/run-agent.sh"
  fi
}
trap cleanup EXIT
set +e
runuser -u agent-admin -- env AGENT_PORT=15035 "$APP/bin/monitor.sh" > "$TMP/port" 2>&1
rc=$?
set -e
cat "$TMP/port"
[[ $rc == 1 ]]
grep -q 'Checking port 15035... \[FAIL\]' "$TMP/port"
echo '[PASS] Closed TCP port returns exit 1'
systemctl stop agent-assignment
set +e
runuser -u agent-admin -- "$APP/bin/monitor.sh" > "$TMP/process" 2>&1
rc=$?
set -e
cat "$TMP/process"
[[ $rc == 1 ]]
grep -q 'Checking agent process... \[FAIL\]' "$TMP/process"
echo '[PASS] Stopped application returns exit 1 (no parent-command false positive)'
