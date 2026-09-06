#!/usr/bin/env bash
# 과제 VM 안에서 root로 실행. 쓰기 검사는 임시 파일을 만들고 즉시 제거한다.
set -euo pipefail
export LC_ALL=C
APP=/home/agent-admin/agent-app
pass() { printf '[PASS] %s\n' "$*"; }
[[ $(id -u) -eq 0 ]]
printf 'Verification time: '; date -Is
cat /etc/os-release | head -4
uname -m
sshd -t
sshd -T | grep -E '^(port|permitrootlogin) '
[[ $(sshd -T | awk '$1=="port" {print $2}') == 20022 ]]
[[ $(sshd -T | awk '$1=="permitrootlogin" {print $2}') == no ]]
ss -ltnp 'sport = :20022'
[[ -z $(ss -H -ltn 'sport = :22') ]]
pass 'SSH 20022; root login disabled; port 22 closed'
ufw status verbose
ufw status | grep -q '^Status: active'
[[ $(ufw status | awk '/ALLOW IN/ && $1!="20022/tcp" && $1!="15034/tcp" {n++} END {print n+0}') == 0 ]]
pass 'UFW active with only TCP 20022 and 15034 allowed'
for user in agent-admin agent-dev agent-test; do id "$user"; done
getent group agent-common
getent group agent-core
for dir in "$APP" "$APP/upload_files" "$APP/api_keys" "$APP/bin" /var/log/agent-app; do stat -c '%A %a %U:%G %n' "$dir"; done
getfacl -p /home/agent-admin "$APP/upload_files" "$APP/api_keys" /var/log/agent-app
[[ $(stat -c '%U:%G %a' "$APP/bin/monitor.sh") == 'agent-dev:agent-core 750' ]]
# QA 업로드 → dev 수정으로 기본 ACL의 실제 상속도 확인한다.
file="$APP/upload_files/verify-normal-$$"
runuser -u agent-test -- bash -c 'umask 077; printf test > "$1"' _ "$file"
runuser -u agent-dev -- bash -c 'printf dev >> "$1"' _ "$file"
getfacl -p "$file"
rm -f "$file"
for dir in "$APP/api_keys" /var/log/agent-app; do
  for user in agent-admin agent-dev; do
    file=$(runuser -u "$user" -- mktemp "$dir/verify.XXXXXX"); rm -f "$file"
  done
  if runuser -u agent-test -- ls "$dir" >/dev/null 2>&1; then echo 'QA isolation failed'; exit 1; fi
done
pass 'Upload shared R/W; core R/W; test denied keys/logs; ACL inheritance; monitor owner/mode'
runuser -l agent-admin -c 'env | sort | grep "^AGENT_"'
runuser -l agent-admin -c 'test "$AGENT_KEY_PATH" = "$AGENT_HOME/api_keys/t_secret.key"'
runuser -u agent-admin -- grep -qx agent_api_key_test "$APP/api_keys/t_secret.key"
runuser -u agent-admin -- cmp "$APP/api_keys/t_secret.key" "$APP/api_keys/secret.key"
stat -c '%A %U:%G %n' "$APP/api_keys/t_secret.key"
pass 'Canonical assignment key path and binary compatibility link'
ss -ltnp 'sport = :15034'
ss -H -ltn 'sport = :15034' | grep -q '0.0.0.0:15034'
runuser -u agent-admin -- "$APP/bin/monitor.sh"
runuser -u agent-admin -- tail -n 5 /var/log/agent-app/monitor.log
crontab -u agent-admin -l
systemctl is-active cron
pass 'App 0.0.0.0:15034; monitor successful; cron active and registered'
printf '\nAll VM checks passed.\n'
