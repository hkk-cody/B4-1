# 리눅스 서버 운영 과제 — 심층 핸즈온 수동 실습 가이드 (Deep Dive)

이 문서는 자동 설치 스크립트(`setup.sh`)를 사용하지 않고, 과제의 모든 요구사항(SSH, UFW, 계정/그룹, ACL, 환경 변수, sudo 권한, cron)을 **Ubuntu 터미널에서 명령어 한 줄 한 줄 직접 입력하면서 리눅스 시스템 엔지니어링 원리를 체득할 수 있도록 작성된 단계별 수동 실습 가이드**입니다.

---

## 📌 목차
1. [실습 개요 및 주의사항](#1-실습-개요-및-주의사항)
2. [Step 0. Ubuntu VM 접속 및 루트 권한 준비](#step-0-ubuntu-vm-접속-및-루트-권한-준비)
3. [Step 1. 필수 패키지 점검 및 설치](#step-1-필수-패키지-점검-및-설치)
4. [Step 2. SSH 보안 설정 (포트 20022 & Root 차단)](#step-2-ssh-보안-설정-포트-20022--root-차단)
5. [Step 3. UFW 방화벽 규칙 구성 및 활성화](#step-3-ufw-방화벽-규칙-구성-및-활성화)
6. [Step 4. 사용자 계정 및 그룹 체계 생성](#step-4-사용자-계정-및-그룹-체계-생성)
7. [Step 5. 디렉터리 권한 및 ACL (Setgid 2770) 설정](#step-5-디렉터리-권한-및-acl-setgid-2770-설정)
8. [Step 6. 공용 환경 변수 및 API 키 배포](#step-6-공용-환경-변수-및-api-키-배포)
9. [Step 7. 앱 바이너리 및 실행 스크립트 배포](#step-7-앱-바이너리-및-실행-스크립트-배포)
10. [Step 8. ufw status 전용 최소 sudo 권한 부여](#step-8-ufw-status-전용-최소-sudo-권한-부여)
11. [Step 9. cron 자동 관제 스케줄 등록](#step-9-cron-자동-관제-스케줄-등록)
12. [Step 10. 앱 실행 및 시스템 관제 종합 검증](#step-10-앱-실행-및-시스템-관제-종합-검증)

---

## 1. 실습 개요 및 주의사항

- **실습 환경**: Mac OrbStack의 Ubuntu VM (`24.04ubuntu`)
- **실습 원칙**:
  - 시스템 설정을 변경하는 단계(Step 1~Step 9)는 **관리자(root 또는 `sudo`)** 권한으로 수행합니다.
  - 앱 실행과 관제 단계(Step 10)는 과제 보안 원칙에 따라 반드시 **일반 계정(`agent-admin`)**으로 수행합니다.
  - 각 단계마다 **[명령어]**를 실행한 후 바로 아래의 **[검증 명령어]**로 정상 적용되었는지 직접 눈으로 확인합니다.

---

## Step 0. Ubuntu VM 접속 및 루트 권한 준비

### 1) VM 터미널 접속
Mac 터미널에서 다음 명령을 실행합니다:
```bash
orb -m 24.04ubuntu
```

### 2) 작업 편의를 위해 root 쉘로 전환
시스템 설정을 한 줄씩 연속으로 입력하기 편하도록 root 쉘로 진입합니다:
```bash
sudo -i
```
*(프롬프트가 `#`으로 바뀌며 `whoami` 실행 시 `root`로 표시됩니다)*

### 3) 저장소 경로 변수 설정
```bash
REPO_DIR="/Users/hankkim/Desktop/codyssey/B4-1"
cd "$REPO_DIR"
```

---

## Step 1. 필수 패키지 점검 및 설치

과제 수행에 필요한 기본 도구들을 설치합니다:

```bash
apt-get update
apt-get install -y openssh-server ufw acl cron sudo procps iproute2 util-linux
```

- `openssh-server`: SSH 원격 접속 데몬
- `ufw`: 우분투 기본 방화벽 도구
- `acl`: 디렉터리/파일별 상세 접근 제어 목록(`setfacl`, `getfacl`)
- `cron`: 주기적 작업 스케줄러

---

## Step 2. SSH 보안 설정 (포트 20022 & Root 차단)

기본 포트(22) 대신 **20022**를 사용하고, 보안 위험이 큰 **root 원격 접속을 차단**합니다.

### 1) 기존 설정 백업
```bash
cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

### 2) 포트 및 루트 로그인 차단 설정 적용
sshd는 동일 설정 키가 여러 번 나오면 맨 위에 선언된 값을 우선 적용하므로, 파일 상단에 추가하거나 기존 항목을 교체합니다:
```bash
# 기존 Port, PermitRootLogin 라인 제거
sed -i -E '/^\s*(Port|PermitRootLogin)\s/d' /etc/ssh/sshd_config

# 파일 맨 첫 줄에 Port 20022 및 PermitRootLogin no 삽입
sed -i '1i Port 20022\nPermitRootLogin no' /etc/ssh/sshd_config
```

### 3) sshd 설정 문법 검사
설정에 오타가 있으면 SSH 서비스가 뻗을 수 있으므로 항상 문법 검사를 먼저 거칩니다:
```bash
mkdir -p /run/sshd
ssh-keygen -A
sshd -t
```
*(아무 에러 메시지도 출력되지 않아야 문법 통과입니다)*

### 4) 서비스 및 소켓 재시작
Ubuntu 24.04는 systemd의 `ssh.socket`이 포트를 대기하므로 소켓과 서비스를 함께 재시작합니다:
```bash
systemctl daemon-reload
if systemctl is-active --quiet ssh.socket; then
  systemctl restart ssh.socket
fi
systemctl enable --now ssh
systemctl restart ssh
```

### 🔍 검증
```bash
# 1. 설정값 확인
sshd -T | grep -E '^(port|permitrootlogin) '
# 출력 결과:
# port 20022
# permitrootlogin no

# 2. 실제 20022 포트가 열렸는지 확인
ss -ltnp 'sport = :20022'
# (LISTEN 상태 및 20022 표시 확인)
```

---

## Step 3. UFW 방화벽 규칙 구성 및 활성화

불필요한 외부 접속을 전면 차단하고, SSH(20022)와 앱(15034) 포트만 인바운드 허용합니다.

### 1) 방화벽 초기화 및 기본 정책 설정
```bash
# 기존 방화벽 규칙 초기화
ufw --force reset

# 들어오는 연결(incoming)은 기본 차단, 나가는 연결(outgoing)은 기본 허용
ufw default deny incoming
ufw default allow outgoing
```

### 2) 필수 포트 허용
```bash
ufw allow 20022/tcp
ufw allow 15034/tcp
```

### 3) 방화벽 활성화
```bash
ufw --force enable
```

### 🔍 검증
```bash
ufw status verbose
```
**기대 출력:**
```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW IN    Anywhere
15034/tcp                  ALLOW IN    Anywhere
20022/tcp (v6)             ALLOW IN    Anywhere (v6)
15034/tcp (v6)             ALLOW IN    Anywhere (v6)
```

---

## Step 4. 사용자 계정 및 그룹 체계 생성

최소 권한 원칙(Principle of Least Privilege)에 따라 역할을 나눕니다:
- **그룹**:
  - `agent-common`: 모든 담당자 공유 (admin, dev, test)
  - `agent-core`: 핵심 운영/개발자 전용 (admin, dev)
- **계정**:
  - `agent-admin`: 운영 및 관제 실행자
  - `agent-dev`: 개발자 (스크립트 작성자)
  - `agent-test`: QA/테스터 (core 접근 권한 배제)

### 1) 그룹 생성
```bash
groupadd agent-common
groupadd agent-core
```
*(이미 존재한다는 에러가 나면 무시해도 됩니다)*

### 2) 사용자 생성 (홈 디렉터리 생성 및 기본 셸 지정)
```bash
useradd -m -s /bin/bash agent-admin
useradd -m -s /bin/bash agent-dev
useradd -m -s /bin/bash agent-test
```

### 3) 계정별 보조 그룹 지정
```bash
usermod -aG agent-common,agent-core agent-admin
usermod -aG agent-common,agent-core agent-dev
usermod -aG agent-common agent-test   # test는 core 그룹에서 제외!
```

### 🔍 검증
```bash
id agent-admin
id agent-dev
id agent-test
```
- `agent-admin`: `agent-common`, `agent-core` 포함
- `agent-dev`: `agent-common`, `agent-core` 포함
- `agent-test`: `agent-common`만 포함 (`agent-core`가 없어야 함)

---

## Step 5. 디렉터리 권한 및 ACL (Setgid 2770) 설정

공유 디렉터리(`upload_files`)와 보안 디렉터리(`api_keys`, `/var/log/agent-app`)의 권한을 분리합니다.

### 1) 상위 경로 및 실행 권한 통과(traverse) 설정
```bash
# agent-admin 홈 디렉터리에 agent-common 그룹 통과 권한(x) 부여
setfacl -m g:agent-common:--x /home/agent-admin

# 애플리케이션 홈 디렉터리 생성
AGENT_HOME=/home/agent-admin/agent-app
install -d -o agent-admin -g agent-common -m 750 "$AGENT_HOME"
install -d -o agent-dev   -g agent-core   -m 750 "$AGENT_HOME/bin"
```

### 2) 그룹 공유/보안 디렉터리 생성 (Setgid 2770 + Default ACL)
Setgid(`2`xxx)를 부여하면 새로 생기는 파일이 디렉터리의 그룹을 물려받으며, Default ACL(`d:...`)은 신규 파일에 자동으로 그룹 rwx를 상속합니다:

```bash
# 1. upload_files: agent-common 그룹 공유 (admin, dev, test 모두 접근)
install -d -o agent-admin -g agent-common -m 2770 "$AGENT_HOME/upload_files"
setfacl --set "u::rwx,g::rwx,g:agent-common:rwx,o::---,d:u::rwx,d:g::rwx,d:g:agent-common:rwx,d:o::---" "$AGENT_HOME/upload_files"

# 2. api_keys: agent-core 그룹 전용 (admin, dev만 접근)
install -d -o agent-admin -g agent-core -m 2770 "$AGENT_HOME/api_keys"
setfacl --set "u::rwx,g::rwx,g:agent-core:rwx,o::---,d:u::rwx,d:g::rwx,d:g:agent-core:rwx,d:o::---" "$AGENT_HOME/api_keys"

# 3. /var/log/agent-app: agent-core 그룹 전용 (admin, dev만 접근)
install -d -o agent-admin -g agent-core -m 2770 /var/log/agent-app
setfacl --set "u::rwx,g::rwx,g:agent-core:rwx,o::---,d:u::rwx,d:g::rwx,d:g:agent-core:rwx,d:o::---" /var/log/agent-app
```

### 🔍 검증
```bash
# 각 디렉터리의 그룹 및 ACL 규칙 확인
getfacl "$AGENT_HOME/upload_files"
getfacl "$AGENT_HOME/api_keys"
getfacl /var/log/agent-app
```

---

## Step 6. 공용 환경 변수 및 API 키 배포

### 1) 시스템 공용 환경 변수 설정
모든 사용자가 로그인할 때 로드되도록 `/etc/profile.d/agent_env.sh`를 작성합니다:
```bash
cat > /etc/profile.d/agent_env.sh << 'EOF'
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR=/var/log/agent-app
EOF

chmod 644 /etc/profile.d/agent_env.sh
```

### 2) API 키 파일 생성 및 심볼릭 링크 연결
과제 요구사항은 `t_secret.key`이고, 제공된 바이너리는 `secret.key`를 기대하므로 심볼릭 링크를 연결합니다:
```bash
# 1. 키 파일 생성 (내용: agent_api_key_test)
echo 'agent_api_key_test' > "$AGENT_HOME/api_keys/t_secret.key"
chown agent-admin:agent-core "$AGENT_HOME/api_keys/t_secret.key"
chmod 660 "$AGENT_HOME/api_keys/t_secret.key"

# 2. 바이너리 호환용 심볼릭 링크 생성
ln -sfn t_secret.key "$AGENT_HOME/api_keys/secret.key"
```

### 🔍 검증
```bash
# 환경 변수 확인
sudo -iu agent-admin env | grep '^AGENT_'

# 키 파일 확인
ls -la "$AGENT_HOME/api_keys"
cat "$AGENT_HOME/api_keys/t_secret.key"
```

---

## Step 7. 앱 바이너리 및 실행 스크립트 배포

Mac의 저장소 폴더에 있는 실행 파일과 스크립트를 실제 서비스 위치로 복사(`install`)합니다:

```bash
# 1. CPU 아키텍처에 맞는 바이너리 복사 (Apple Silicon Mac은 arm64)
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  BINARY="agent-app-linux-arm64"
else
  BINARY="agent-app-linux-x86"
fi

install -o agent-admin -g agent-core -m 750 "$REPO_DIR/agent-app/$BINARY" "$AGENT_HOME/$BINARY"

# 2. 실행 스크립트(run-agent.sh, monitor.sh) 복사 및 권한 부여
install -o agent-dev -g agent-core -m 750 "$REPO_DIR/bin/run-agent.sh" "$AGENT_HOME/bin/run-agent.sh"
install -o agent-dev -g agent-core -m 750 "$REPO_DIR/bin/monitor.sh"   "$AGENT_HOME/bin/monitor.sh"
```

### 🔍 검증
```bash
ls -l "$AGENT_HOME/$BINARY"
ls -l "$AGENT_HOME/bin"
```
*(소유자 `agent-dev`, 그룹 `agent-core`, 퍼미션 `rwxr-x---(750)` 확인)*

---

## Step 8. ufw status 전용 최소 sudo 권한 부여

`monitor.sh`는 방화벽 상태(`ufw status`)를 확인해야 합니다. 하지만 일반 계정인 `agent-admin`에게 root 전체 권한을 주면 보안상 위험하므로, **`/usr/sbin/ufw status` 명령어만 비밀번호 없이 실행할 수 있도록 sudoers 규칙을 추가**합니다:

```bash
# 1. 단일 허용 규칙 파일 생성
echo 'agent-admin ALL=(root) NOPASSWD: /usr/sbin/ufw status' > /etc/sudoers.d/agent-monitor
chmod 440 /etc/sudoers.d/agent-monitor

# 2. sudoers 문법 검증 (오류가 없어야 함)
visudo -cf /etc/sudoers.d/agent-monitor
```

### 🔍 검증
```bash
# agent-admin 권한으로 암호 없이 ufw status 실행 가능한지 확인
sudo -u agent-admin sudo -n /usr/sbin/ufw status
```

---

## Step 9. cron 자동 관제 스케줄 등록

`agent-admin` 계정의 crontab에 1분마다 `monitor.sh`를 실행하도록 등록합니다:

```bash
# 1. crontab 등록 (* * * * * = 매 분 실행)
echo '* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1' | crontab -u agent-admin -

# 2. cron 서비스 활성화 및 시작
systemctl enable --now cron
```

### 🔍 검증
```bash
# 1. 등록된 crontab 확인
crontab -u agent-admin -l

# 2. cron 데몬 상태 확인 (active여야 함)
systemctl is-active cron
```

---

## Step 10. 앱 실행 및 시스템 관제 종합 검증

수동 환경 구성이 모두 끝났습니다! 이제 터미널을 2개 열어 실제 운영 환경을 검증합니다.

### 1) [터미널 1] root 쉘 종료 후 일반 계정으로 앱 실행
```bash
# root 쉘 종료
exit

# agent-admin 계정으로 앱 실행
sudo -iu agent-admin /home/agent-admin/agent-app/bin/run-agent.sh
```
**성공 화면:**
```text
Running as service user 'agent-admin'
[1/5] Checking environment variables... [OK]
[2/5] Checking directories and permissions... [OK]
[3/5] Checking API key access... [OK]
[4/5] Checking log directory access... [OK]
[5/5] Checking port 15034 availability... [OK]

Agent READY
Agent listening at port 15034
```
> ⚠️ **터미널 1은 이 상태 그대로 유지합니다.**

---

### 2) [터미널 2] 관제 스크립트 수동 실행 및 종료 코드 확인
새 터미널을 열고 `orb -m 24.04ubuntu`로 들어옵니다:

```bash
# 1. 수동 관제 실행
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh

# 2. 종료 코드 확인 (0이어야 정상)
echo $?

# 3. 로그 파일 확인
sudo -u agent-admin tail -n 5 /var/log/agent-app/monitor.log
```

---

### 3) [터미널 2] 1~2분 대기 후 cron 자동 로깅 증가 확인
```bash
date
sudo -u agent-admin wc -l /var/log/agent-app/monitor.log

# (1~2분 대기 후 다시 실행)
sudo -u agent-admin wc -l /var/log/agent-app/monitor.log
```
로그 파일의 줄 수가 1~2줄 늘어났다면 cron 자동 로깅까지 모두 성공한 것입니다!

---

### 4) [터미널 2] 종합 자동 검증 테스트
```bash
cd /Users/hankkim/Desktop/codyssey/B4-1
bash tests/verify_vm.sh
bash tests/test_monitor.sh
```
두 스크립트 모두 `ALL PASS`가 나오면 모든 과제 요구사항을 완벽하게 수동으로 구축한 것입니다! 🎉
