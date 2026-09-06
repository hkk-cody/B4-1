#!/usr/bin/env bash
# Ubuntu 과제 VM 전용 설치. 실행 위치와 무관하며 재실행해도 원본을 보존한다.
set -euo pipefail
export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
[[ $(uname -s) == Linux ]] || { echo 'Run inside the Ubuntu VM.' >&2; exit 1; }
if ((EUID != 0)); then exec sudo bash "$0" "$@"; fi
AGENT_HOME=/home/agent-admin/agent-app
LOG_DIR=/var/log/agent-app
case "$(uname -m)" in
  aarch64|arm64) binary=agent-app-linux-arm64 ;;
  x86_64) binary=agent-app-linux-x86 ;;
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac
[[ -f "$REPO_DIR/agent-app/$binary" ]] || { echo 'App binary missing' >&2; exit 1; }
missing=()
for package in openssh-server ufw acl cron sudo procps iproute2 util-linux; do
  dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -qx 'install ok installed' || missing+=("$package")
done
if ((${#missing[@]})); then apt-get update; apt-get install -y "${missing[@]}"; fi

printf '\n[1/5] SSH and firewall\n'
# 활성화된 방화벽에서도 새 SSH 포트를 먼저 허용한다.
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
# 다른 서비스의 규칙을 임의로 지우지 않고, 과제의 두 포트만 있는지 검사한다.
if ufw status | awk '/ALLOW IN/ && $1!="20022/tcp" && $1!="15034/tcp" {bad=1} END {exit bad?0:1}'; then
  echo 'Unexpected UFW allow rule: review ufw status numbered before continuing.' >&2; exit 1
fi
backup=/etc/ssh/sshd_config.before-agent-assignment
[[ -e "$backup" ]] || cp -p /etc/ssh/sshd_config "$backup"
# 기존 전역 Port/PermitRootLogin을 정리하고 파일 첫머리에 고정한다.
sed -i -E '/^[[:space:]]*Port[[:space:]]+/d; /^[[:space:]]*PermitRootLogin[[:space:]]+/d' /etc/ssh/sshd_config
sed -i '1iPort 20022\nPermitRootLogin no' /etc/ssh/sshd_config
install -d -m 755 /run/sshd
ssh-keygen -A
sshd -t
[[ $(sshd -T | awk '$1=="port" {print $2}') == 20022 ]]
[[ $(sshd -T | awk '$1=="permitrootlogin" {print $2}') == no ]]
systemctl daemon-reload
# Ubuntu 24.04의 socket activation에서도 포트 변경이 반영되도록 한다.
if systemctl is-active --quiet ssh.socket; then systemctl restart ssh.socket; fi
systemctl enable ssh
systemctl restart ssh
ss -H -ltn 'sport = :20022' | grep -q .

printf '\n[2/5] Accounts and permissions\n'
for group in agent-common agent-core; do getent group "$group" >/dev/null || groupadd "$group"; done
for user in agent-admin agent-dev agent-test; do
  id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
  usermod -s /bin/bash -aG agent-common "$user"
done
usermod -aG agent-core agent-admin
usermod -aG agent-core agent-dev
if id -nG agent-test | tr ' ' '\n' | grep -qx agent-core; then gpasswd -d agent-test agent-core; fi
# 홈 전체를 공개하지 않고 common에 통과 권한만 부여한다.
setfacl -m g:agent-common:--x /home/agent-admin
install -d -o agent-admin -g agent-common -m 750 "$AGENT_HOME"
install -d -o agent-dev -g agent-core -m 750 "$AGENT_HOME/bin"
for entry in upload_files:agent-common api_keys:agent-core; do
  dir="$AGENT_HOME/${entry%:*}"; group=${entry#*:}
  install -d -o agent-admin -g "$group" -m 2770 "$dir"
  setfacl -b "$dir"; setfacl -k "$dir"
  setfacl -m "u::rwx,g::rwx,g:$group:rwx,m::rwx,o::---" "$dir"
  setfacl -d -m "u::rwx,g::rwx,g:$group:rwx,m::rwx,o::---" "$dir"
done
install -d -o agent-admin -g agent-core -m 2770 "$LOG_DIR"
setfacl -b "$LOG_DIR"; setfacl -k "$LOG_DIR"
setfacl -m u::rwx,g::rwx,g:agent-core:rwx,m::rwx,o::--- "$LOG_DIR"
setfacl -d -m u::rwx,g::rwx,g:agent-core:rwx,m::rwx,o::--- "$LOG_DIR"

printf '\n[3/5] Environment and application\n'
cat > /etc/profile.d/agent_env.sh <<'PROFILE'
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR=/var/log/agent-app
PROFILE
chmod 644 /etc/profile.d/agent_env.sh
printf 'agent_api_key_test\n' > "$AGENT_HOME/api_keys/t_secret.key"
chown agent-admin:agent-core "$AGENT_HOME/api_keys/t_secret.key"
chmod 660 "$AGENT_HOME/api_keys/t_secret.key"
# 제공 바이너리의 secret.key 이름도 같은 내용으로 유지한다.
ln -sfn t_secret.key "$AGENT_HOME/api_keys/secret.key"
chown -h agent-admin:agent-core "$AGENT_HOME/api_keys/secret.key"
# 실행 중인 파일에 덮어쓰지 않도록 내용이 달라질 때만 원자적으로 교체한다.
if ! cmp -s "$REPO_DIR/agent-app/$binary" "$AGENT_HOME/$binary"; then
  install -o agent-admin -g agent-core -m 750 "$REPO_DIR/agent-app/$binary" "$AGENT_HOME/$binary.new"
  mv -f "$AGENT_HOME/$binary.new" "$AGENT_HOME/$binary"
fi
for script in monitor.sh report.sh run-agent.sh; do
  install -o agent-dev -g agent-core -m 750 "$SCRIPT_DIR/$script" "$AGENT_HOME/bin/$script.new"
  bash -n "$AGENT_HOME/bin/$script.new"
  mv -f "$AGENT_HOME/bin/$script.new" "$AGENT_HOME/bin/$script"
done

printf '\n[4/5] Read-only firewall permission\n'
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf 'agent-admin ALL=(root) NOPASSWD: /usr/sbin/ufw status\n' > "$tmp"
visudo -cf "$tmp"
install -o root -g root -m 440 "$tmp" /etc/sudoers.d/agent-monitor

printf '\n[5/5] Cron\n'
# 기존의 과제 monitor 항목만 교체하고 다른 cron 작업은 보존한다.
{ crontab -u agent-admin -l 2>/dev/null || true; } | 
  awk '!/\/agent-app\/bin\/monitor[.]sh/ && !/^AGENT_PROCESS_PATTERN=/ && NF' > "$tmp"
printf '\n* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1\n' >> "$tmp"
crontab -u agent-admin "$tmp"
systemctl enable --now cron
printf '\nSetup complete. Run as agent-admin: %s/bin/run-agent.sh\n' "$AGENT_HOME"
