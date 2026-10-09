# OrbStack을 활용한 리눅스 서버 운영 과제 실습 가이드

이 문서는 Mac 환경에서 **OrbStack**의 Ubuntu VM(`24.04ubuntu`)을 사용하여 본 과제를 처음부터 끝까지 직접 실습할 수 있도록 정리한 실습 안내서입니다.

---

## 📌 목차
1. [기존 관련 문서 위치 안내](#1-기존-관련-문서-위치-안내)
2. [사전 준비 및 환경 확인](#2-사전-준비-및-환경-확인)
3. [실습 방식 선택 (자동 셋업 vs 수동 셋업)](#3-실습-방식-선택)
4. [단계별 실습 절차](#4-단계별-실습-절차)
   - [Step 1: OrbStack VM 시작 및 접속](#step-1-orbstack-vm-시작-및-접속)
   - [Step 2: 작업 디렉터리 이동 및 환경 구성](#step-2-작업-디렉터리-이동-및-환경-구성)
   - [Step 3: 터미널 2개 분할 준비](#step-3-터미널-2개-분할-준비)
   - [Step 4: [터미널 1] 앱 실행](#step-4-터미널-1-앱-실행)
   - [Step 5: [터미널 2] 모니터링 스크립트 수동 실행](#step-5-터미널-2-모니터링-스크립트-수동-실행)
   - [Step 6: [터미널 2] cron 자동 로깅 검증](#step-6-터미널-2-cron-자동-로깅-검증)
   - [Step 7: [터미널 2] 보안 및 권한 체계 검증](#step-7-터미널-2-보안-및-권한-체계-검증)
   - [Step 8: 전체 자동화 테스트 실행](#step-8-전체-자동화-테스트-실행)
5. [자주 발생하는 문제 및 문제 해결(Troubleshooting)](#5-자주-발생하는-문제-및-문제-해결)

---

## 1. 기존 관련 문서 위치 안내

저장소 내에 이미 목적별로 상세한 문서들이 준비되어 있습니다:

| 문서 위치 | 문서명/역할 | 주요 내용 |
| :--- | :--- | :--- |
| [README.md](file:///Users/hankkim/Desktop/codyssey/B4-1/README.md) | **루트 실행 안내서** | 과제 전체 실행 절차, 명령어, 확인 기준 요약 |
| [docs/submission.md](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/submission.md) | **과제 수행 내역서 (모범 답안)** | 실제 입력한 명령어와 실행 결과, 체크리스트 증거 |
| [docs/assignment/requirements.md](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/assignment/requirements.md) | **원본 과제 요구사항** | 원본 과제 명세, 보안 규칙, 권한 정책, 로깅 규격 |
| [docs/README.md](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/README.md) | **학습 로드맵** | 리눅스 기초부터 트러블슈팅까지의 학습 순서 안내 |
| [docs/lessons/](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/) | **학습 단원별 교재 (01~08)** | [01-기초](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/01-basics.md), [02-네트워크/SSH](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/02-network.md), [03-권한/ACL](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/03-permissions.md), [04-앱/환경변수](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/04-application.md), [05-Bash/관제](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/05-bash-and-monitor.md), [06-로그/cron](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/06-logs-and-cron.md), [07-트러블슈팅](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/07-troubleshooting.md), [08-용어사전](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/lessons/08-glossary.md) |
| [docs/evidence/](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/evidence/) | **검증 증거 자료** | [OrbStack 실행 캡처](file:///Users/hankkim/Desktop/codyssey/B4-1/docs/evidence/orbstack-monitor.png) 및 실제 명령 출력 텍스트들 |
| [tests/README.md](file:///Users/hankkim/Desktop/codyssey/B4-1/tests/README.md) | **자동 검증 테스트 안내** | 환경 및 관제 스크립트를 자동 검사하는 테스트 설명서 |

---

## 2. 사전 준비 및 환경 확인

현재 Mac 환경에는 이미 OrbStack CLI(`orb`)와 `24.04ubuntu` 머신이 준비되어 있습니다.

### 현재 머신 상태 확인 (Mac 터미널에서 실행)
```bash
orb list
```
*출력 예시:*
```text
NAME         STATE    DISTRO  VERSION  ARCH   SIZE      IP
24.04ubuntu  stopped  ubuntu  noble    arm64  1.0 GB    
```

---

## 3. 실습 방식 선택

실습 목적에 따라 두 가지 경로 중 하나를 선택할 수 있습니다:

- **방식 A. 빠른 핸즈온 (Quick Start - 추천)**:
  - 이미 작성된 [`bin/setup.sh`](file:///Users/hankkim/Desktop/codyssey/B4-1/bin/setup.sh)를 1회 실행하여 환경(SSH, UFW, 계정, ACL, 앱/스크립트 배포, cron)을 자동 구성한 뒤, **앱 실행, 모니터링 스크립트 실행, cron 검증, 로그 확인** 등 핵심 운영 업무를 직접 실습합니다.
- **방식 B. 심층 핸즈온 (Deep Dive - 수동 구성)**:
  - `setup.sh`를 쓰지 않고, SSH 포트 변경부터 UFW 방화벽, 계정 생성(`useradd`), ACL(`setfacl`), 환경 변수 세팅 등을 커맨드라인으로 한 줄씩 직접 입력하며 원리를 체득합니다.
  - 👉 상세 가이드: [수동 심층 핸즈온 실습 가이드](manual_deep_dive_guide.md)를 보면서 따라 하실 수 있습니다.

---

## 4. 단계별 실습 절차

> **주의**: 아래의 모든 실습 명령어는 **Ubuntu VM 내부**에서 실행합니다.

### Step 1: OrbStack VM 시작 및 접속

#### 방법 1. Mac 터미널에서 바로 접속 (가장 빠름)
Mac 터미널을 열고 다음 명령을 실행하면 VM이 꺼져 있더라도 자동으로 켜지면서 접속됩니다:
```bash
orb -m 24.04ubuntu
```

#### 방법 2. OrbStack GUI 앱 이용
1. Mac에서 **OrbStack** 앱을 엽니다.
2. 왼쪽 **Machines** 목록에서 **24.04ubuntu**를 클릭합니다.
3. 머신이 정지(Stopped) 상태라면 상단 **Start(재생)** 버튼을 누릅니다.
4. 상단 탭에서 **Terminal**을 클릭합니다.

#### 접속 확인 (VM 내부인지 검증)
```bash
uname -s
whoami
```
- `uname -s` 결과가 **`Linux`** 여야 합니다 (`Darwin`이 나오면 Mac 로컬 터미널입니다).
- `whoami` 결과는 관리 계정(예: `hankkim`)으로 표시됩니다.

---

### Step 2: 작업 디렉터리 이동 및 환경 구성

OrbStack은 Mac의 파일 시스템을 VM의 동일한 절대 경로로 자동 마운트/공유해 줍니다.

```bash
# 1. Mac 저장소 폴더로 이동
cd /Users/hankkim/Desktop/codyssey/B4-1

# 2. 파일 목록 확인
ls -l bin/setup.sh

# 3. 환경 셋업 스크립트 실행 (관리자 권한)
sudo bash bin/setup.sh
```

**셋업 스크립트가 자동으로 수행하는 작업:**
1. 필수 패키지 설치 (`openssh-server`, `ufw`, `acl`, `cron` 등)
2. SSH 설정 변경 (Port 20022, PermitRootLogin no) 및 재시작
3. UFW 방화벽 활성화 (20022/tcp, 15034/tcp 인바운드 허용)
4. 계정 및 그룹 생성 (`agent-admin`, `agent-dev`, `agent-test` / `agent-common`, `agent-core`)
5. 디렉토리 구조 생성 및 ACL 권한 부여 (`/home/agent-admin/agent-app`, `/var/log/agent-app`)
6. 환경 변수 등록 (`/etc/profile.d/agent_env.sh`) 및 API 키 파일 생성
7. 바이너리 및 스크립트 배포 (`run-agent.sh`, `monitor.sh`)
8. `agent-admin` 계정의 crontab에 매분 관제 스크립트 등록

스크립트 마지막에 `Setup complete.` 메시지가 나오면 기본 준비가 완료된 것입니다.

---

### Step 3: 터미널 2개 분할 준비

앱은 백그라운드 데몬이 아닌 **포그라운드(화면 유지) 프로세스**로 실행해야 합니다. 따라서 터미널을 2개 띄워야 합니다:

- **[터미널 1 (Terminal A)]**: 애플리케이션 실행 전용 (로그가 계속 출력되며 대기)
- **[터미널 2 (Terminal B)]**: 시스템 관제(`monitor.sh`) 및 상태 점검 전용

> **새 터미널 열기:** Mac 터미널 새 창(또는 새 탭)을 열고 `orb -m 24.04ubuntu`를 입력하여 접속합니다.

---

### Step 4: [터미널 1] 앱 실행

터미널 1에서 포트가 이미 사용 중인지 확인한 뒤 앱을 실행합니다.

```bash
# 1. 15034 포트 점유 여부 확인
sudo ss -ltnp 'sport = :15034'
```
*(아무것도 출력되지 않아야 정상입니다. 만약 LISTEN 상태가 보인다면 이전 프로세스가 돌고 있는 것이므로 종료해야 합니다)*

```bash
# 2. agent-admin 계정으로 앱 실행
sudo -iu agent-admin /home/agent-admin/agent-app/bin/run-agent.sh
```

**정상 실행 출력 기준:**
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
> ⚠️ **중요**: 이 터미널은 **Ctrl+C를 누르지 말고 그대로 켜 두어야 합니다.**

---

### Step 5: [터미널 2] 모니터링 스크립트 수동 실행

터미널 2로 전환하여 관제 스크립트를 직접 실행해 봅니다.

```bash
# 1. agent-admin 권한으로 관제 스크립트 실행
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh

# 2. 직전 명령어 종료 코드 확인 (0이어야 성공)
echo $?
```

**정상 실행 출력:**
```text
[OK] Process is running (PID: xxxx)
[OK] Port 15034 is listening
CPU: x.x% | MEM: xx.x% | DISK: x%
[INFO] Log appended: [2026-xx-xx xx:xx:xx] PID:xxxx CPU:x.x% MEM:xx.x% DISK_USED:x%
```
*(종료 코드 `echo $?` 결과가 `0`으로 나와야 합니다)*

```bash
# 3. 로그 파일에 정상 기록되었는지 확인
sudo -u agent-admin tail -n 5 /var/log/agent-app/monitor.log
```

---

### Step 6: [터미널 2] cron 자동 로깅 검증

cron 데몬이 매분마다 `monitor.sh`를 자동으로 실행하는지 검증합니다.

```bash
# 1. cron 데몬이 실행 중인지 확인
sudo systemctl is-active cron
# (결과: active)

# 2. agent-admin의 crontab 등록 내용 확인
sudo -u agent-admin crontab -l
# (결과: * * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1)

# 3. 현재 로그 파일 줄 수 및 현재 시각 기록
date
sudo -u agent-admin wc -l /var/log/agent-app/monitor.log
```

**검증 방법:**
1. 명령을 입력하지 말고 **1분~2분간 대기**합니다.
2. 1~2분 후 다시 줄 수를 확인합니다:
   ```bash
   sudo -u agent-admin wc -l /var/log/agent-app/monitor.log
   sudo -u agent-admin tail -n 3 /var/log/agent-app/monitor.log
   ```
3. 로그 파일의 줄 수가 1~2줄 늘어나 있고, 최근 기록 시각이 최신으로 갱신되었으면 자동 관제가 정상 작동하는 것입니다.

---

### Step 7: [터미널 2] 보안 및 권한 체계 검증

과제의 주요 보안/권한 요구사항이 잘 충족되었는지 점검합니다.

#### 1) SSH 설정 및 포트 검사
```bash
# SSH 포트 20022 및 Root 로그인 차단 확인
sudo sshd -T | grep -E '^(port|permitrootlogin) '
# 포트 20022 리슨 여부 확인
sudo ss -ltnp 'sport = :20022'
```

#### 2) 방화벽(UFW) 상태 검사
```bash
sudo ufw status verbose
# Status: active
# 20022/tcp  ALLOW IN
# 15034/tcp  ALLOW IN
```

#### 3) 사용자 계정 및 그룹 체계 확인
```bash
id agent-admin   # groups: agent-common, agent-core
id agent-dev     # groups: agent-common, agent-core
id agent-test    # groups: agent-common (agent-core 제외)
```

#### 4) 디렉터리 권한 및 ACL 확인
```bash
# upload_files: agent-common 공유 (2770)
sudo getfacl /home/agent-admin/agent-app/upload_files

# api_keys: agent-core 전용 (2770)
sudo getfacl /home/agent-admin/agent-app/api_keys

# log: agent-core 전용 (2770)
sudo getfacl /var/log/agent-app
```

#### 5) 환경 변수 검사
```bash
sudo -iu agent-admin env | grep '^AGENT_'
```

---

### Step 8: 전체 자동화 테스트 실행

프로젝트에 포함된 종합 검증 테스트 스크립트를 실행하여 모든 기능 요구사항을 자동으로 점검합니다.

```bash
cd /Users/hankkim/Desktop/codyssey/B4-1

# 1. VM 시스템 상태 검증 (SSH, UFW, 계정, ACL, 환경변수)
bash tests/verify_vm.sh

# 2. monitor.sh 기능 단위 테스트 (정상 수집, 리소스 계산, 임계값 경고, 로그 회전)
bash tests/test_monitor.sh
```

모든 테스트에서 `ALL PASS` 또는 `[OK]`가 출력되면 과제의 모든 요구사항이 완벽하게 구현된 것입니다! 🎉

---

## 5. 자주 발생하는 문제 및 문제 해결

### Q1. `Port 15034 is already in use` 에러가 나면서 앱이 안 켜져요.
- **원인**: 이전 실습이나 백그라운드 서비스에서 15034 포트를 이미 점유하고 있습니다.
- **해결책**:
  ```bash
  # 1. 점유 프로세스 확인
  sudo ss -ltnp 'sport = :15034'
  # 2. 혹시 agent-assignment 임시 서비스가 돌고 있다면 중지
  sudo systemctl stop agent-assignment 2>/dev/null || true
  # 3. 실행 중인 agent 바이너리 종료
  sudo pkill -f agent-app-linux
  ```

### Q2. VM 안에서 `/Users/hankkim/Desktop/codyssey/B4-1` 디렉터리가 안 보여요.
- **원인**: OrbStack 공유 폴더 마운트가 일시적으로 지연되었거나 비활성화되어 있을 수 있습니다.
- **해결책**:
  - Mac OrbStack 설정 -> `Sharing`에서 Mac 파일 공유가 활성화되어 있는지 확인합니다.
  - 또는 VM 내에서 `ls /Users/hankkim`을 확인해 봅니다.

### Q3. `monitor.sh` 실행 시 `[FAIL] Process is not running`이 떠요.
- **원인**: 터미널 1에서 앱을 실행하지 않았거나, 에러로 인해 앱이 종료된 상태입니다.
- **해결책**:
  - Step 4를 따라 터미널 1에서 앱을 다시 실행한 후, 터미널 2에서 `monitor.sh`를 실행해 보세요.
  - 앱이 꺼졌을 때 `monitor.sh`가 실패(`exit 1`)를 띄우는 것은 과제에서 요구한 정상적인 장애 감지 동작입니다.

### Q4. 실습을 마치고 앱을 종료하고 싶어요.
- **방법**:
  - 터미널 1에서 `Ctrl + C`를 누르면 앱이 안전하게 종료됩니다.
  - cron 스케줄링을 멈추고 싶다면 `sudo systemctl stop cron`을 실행하거나 `sudo crontab -u agent-admin -r`로 crontab을 비울 수 있습니다.
