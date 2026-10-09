#!/usr/bin/env bash
# =====================================================================
# setup.sh — 과제 VM 환경을 한 번에 구성하는 설치 스크립트
#   실행 위치 : Ubuntu VM 안 (Mac 저장소가 공유 폴더로 보이는 상태)
#   실행 방법 : sudo bash bin/setup.sh
#   여러 번 실행해도 같은 결과가 나오도록 작성했다. (소스 수정 후 재배포용)
# =====================================================================
set -euo pipefail   # 오류·미정의 변수·파이프 실패 시 즉시 중단
export LC_ALL=C     # 명령 출력 형식을 표준(영문)으로 고정

# ── 0. 사전 검사 ────────────────────────────────────────────────────
[[ $(uname -s) == Linux ]] || { echo 'Run inside the Ubuntu VM.' >&2; exit 1; }
(( EUID == 0 )) || exec sudo bash "$0" "$@"     # root가 아니면 sudo로 자기 자신을 다시 실행

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)      # 저장소 최상위 (= bin/ 의 상위 폴더)
AGENT_HOME=/home/agent-admin/agent-app
LOG_DIR=/var/log/agent-app

# CPU 종류에 맞는 제공 바이너리 선택
case $(uname -m) in
  aarch64|arm64) BINARY=agent-app-linux-arm64 ;;   # Apple Silicon 등
  x86_64)        BINARY=agent-app-linux-x86 ;;     # Intel/AMD
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac
[[ -f "$REPO_DIR/agent-app/$BINARY" ]] || { echo "Missing $BINARY" >&2; exit 1; }

# 필요한 패키지 중 설치 안 된 것만 골라 설치
missing=()
for pkg in openssh-server ufw acl cron sudo procps iproute2 util-linux; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'ok installed' || missing+=("$pkg")
done
if (( ${#missing[@]} )); then apt-get update; apt-get install -y "${missing[@]}"; fi

# ── 1. SSH + 방화벽 ─────────────────────────────────────────────────
echo '[1/5] SSH (port 20022, no root login) and UFW'

# 원본 설정은 최초 1회만 백업
[[ -e /etc/ssh/sshd_config.bak ]] ||
  cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# 기존 Port / PermitRootLogin 줄을 지우고 파일 맨 위에 새로 넣는다.
# (sshd는 같은 항목이 여러 번 나오면 "처음 값"을 쓰므로 맨 위가 확실하다)
sed -i -E '/^\s*(Port|PermitRootLogin)\s/d' /etc/ssh/sshd_config
sed -i '1i Port 20022\nPermitRootLogin no' /etc/ssh/sshd_config

mkdir -p /run/sshd     # sshd 검사에 필요한 디렉토리
ssh-keygen -A          # 호스트 키가 없으면 생성
sshd -t                # 설정 문법 검사 (틀리면 set -e 로 여기서 중단)
systemctl daemon-reload
# Ubuntu 24.04는 ssh.socket이 포트를 대신 열어 두므로 소켓도 재시작해야 새 포트가 반영된다.
if systemctl is-active --quiet ssh.socket; then systemctl restart ssh.socket; fi
systemctl enable ssh   # reboot 이후에도 자동 실행
systemctl restart ssh  # 현재 서비스 재시작
ss -Hltn 'sport = :20022' | grep -q .   # 20022가 실제로 열렸는지 확인

# 방화벽: 규칙을 초기화한 뒤 들어오는 연결은 기본 차단, 20022·15034만 허용
ufw --force reset > /dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw --force enable                      # --force: 확인 질문(y/n) 생략

# ── 2. 계정 / 그룹 / 디렉토리 권한 ───────────────────────────────────
echo '[2/5] Accounts, groups and directories'

for g in agent-common agent-core; do
  getent group "$g" > /dev/null || groupadd "$g"       # 없을 때만 생성
done
for u in agent-admin agent-dev agent-test; do
  id "$u" &> /dev/null || useradd -m -s /bin/bash "$u" # -m: 홈 디렉토리 생성
done
usermod -aG agent-common,agent-core agent-admin        # -aG: 기존 그룹 유지하며 추가
usermod -aG agent-common,agent-core agent-dev
usermod -G  agent-common            agent-test         # -G: test 보조 그룹을 common만으로 고정 (core 제외)
gpasswd -d agent-test agent-core &>/dev/null || true   # 기존에 속해 있었더라도 core에서 확실히 제거

# /home/agent-admin(750)은 다른 계정이 못 들어간다 → common 그룹에 "통과(x)" 권한만 준다.
setfacl -m g:agent-common:--x /home/agent-admin       # setfacl : -m 수정, g: 그룹
install -d -o agent-admin -g agent-common -m 750 "$AGENT_HOME" # install : -o 소유자, -g 소유그룹, -m 권한지정
install -d -o agent-dev   -g agent-core   -m 750 "$AGENT_HOME/bin" 

# 그룹 공유 디렉토리 만들기
#   2770 = setgid(새 파일이 디렉토리 그룹을 물려받음) + 소유자·그룹 rwx + 기타 없음
#   d:... = default ACL → 안에 새로 생기는 파일/폴더도 같은 그룹 권한을 상속
make_group_dir() {   # 사용법: make_group_dir 경로 그룹
  install -d -o agent-admin -g "$2" -m 2770 "$1"
  setfacl --set "u::rwx,g::rwx,g:$2:rwx,o::---,d:u::rwx,d:g::rwx,d:g:$2:rwx,d:o::---" "$1"
}
make_group_dir "$AGENT_HOME/upload_files" agent-common   # 공유: admin/dev/test
make_group_dir "$AGENT_HOME/api_keys"     agent-core     # 보안: admin/dev
make_group_dir "$LOG_DIR"                 agent-core     # 보안: admin/dev

# ── 3. 환경 변수 / 키 / 앱 파일 배포 ─────────────────────────────────
echo '[3/5] Environment, key and application files'

# 로그인할 때 자동으로 읽히는 위치(/etc/profile.d)에 환경 변수 등록
# <<'EOF' (따옴표) → $AGENT_HOME 을 지금 치환하지 않고 글자 그대로 저장
cat > /etc/profile.d/agent_env.sh << 'EOF'
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR=/var/log/agent-app
EOF
chmod 644 /etc/profile.d/agent_env.sh

# 과제 키 파일 (내용 1줄)
echo 'agent_api_key_test' > "$AGENT_HOME/api_keys/t_secret.key"
chown agent-admin:agent-core "$AGENT_HOME/api_keys/t_secret.key"
chmod 660 "$AGENT_HOME/api_keys/t_secret.key"
# 제공 바이너리는 secret.key 라는 이름을 찾으므로 같은 파일을 가리키는 링크를 만든다.
ln -sfn t_secret.key "$AGENT_HOME/api_keys/secret.key"

# install = 복사 + 소유자(-o)·그룹(-g)·권한(-m) 지정을 한 번에.
# 기존 파일을 지우고 새로 만들기 때문에 실행 중인 앱/스크립트도 안전하게 교체된다.
install -o agent-admin -g agent-core -m 750 "$REPO_DIR/agent-app/$BINARY" "$AGENT_HOME/$BINARY"
for script in monitor.sh run-agent.sh; do
  bash -n "$REPO_DIR/bin/$script"   # 문법 오류가 있으면 배포 전에 중단
  install -o agent-dev -g agent-core -m 750 "$REPO_DIR/bin/$script" "$AGENT_HOME/bin/$script"
done
rm -f "$AGENT_HOME/bin/report.sh"   # 보너스 미수행: 이전에 설치된 파일 정리

# ── 4. 방화벽 조회용 최소 sudo 권한 ─────────────────────────────────
echo '[4/5] sudo rule: agent-admin may run only "ufw status"'
# monitor.sh 전체를 root로 돌리지 않고, 조회 명령 하나만 비밀번호 없이 허용한다.
echo 'agent-admin ALL=(root) NOPASSWD: /usr/sbin/ufw status' > /etc/sudoers.d/agent-monitor
chmod 440 /etc/sudoers.d/agent-monitor    # 파일 읽기 권한만 부여
visudo -cf /etc/sudoers.d/agent-monitor   # sudoers 문법 검사

# ── 5. cron 매분 실행 등록 ──────────────────────────────────────────
echo '[5/5] cron: run monitor.sh every minute as agent-admin'
# 분 시 일 월 요일 → "* * * * *" = 매분.  화면 출력은 버리고 로그는 스크립트가 직접 쓴다.
# agent-admin의 기존 crontab은 보존하고, monitor.sh 작업만 중복 없이 등록/갱신한다.
CRON_JOB='* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1'
( crontab -u agent-admin -l 2>/dev/null | grep -Fv '/home/agent-admin/agent-app/bin/monitor.sh' || true; echo "$CRON_JOB" ) | crontab -u agent-admin -
systemctl enable --now cron

echo
echo "Setup complete. Start the app as agent-admin: $AGENT_HOME/bin/run-agent.sh"
