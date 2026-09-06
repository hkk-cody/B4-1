# 7. 검증과 문제 해결

[이전](06-logs-and-cron.md) · [목차](../README.md) · [다음: 용어·복습](08-glossary.md)

**목표:** 명령을 반복하기 전에 실패 위치를 찾고, 성공했다는 근거를 남긴다.

## 7.1 오류를 만났을 때 첫 다섯 가지

1. **오류 메시지를 그대로 읽는다.** `No such file`과 `Permission denied`는 다른 문제다.
2. `uname -s`, `whoami`, `pwd`로 어디서 누구로 실행했는지 확인한다.
3. 명령이 가리킨 파일과 상위 경로가 실제로 있는지 확인한다.
4. 설정값, 실제 프로세스·포트, 권한을 차례로 본다.
5. 하나를 고친 뒤 같은 조건으로 재실행한다. 다른 변경을 섞으면 원인 파악이 어려워진다.

오류가 났다고 `sudo`를 모든 명령에 붙이면 일반 계정에서의 권한 오류가 숨겨진다. 앱과 monitor는 계속 agent-admin으로 검사한다.

## 7.2 상황별 확인

### `No such file or directory`

```bash
pwd
ls -l /Users/hankkim/Desktop/codyssey/B4-1/bin/setup.sh
sudo ls -l /home/agent-admin/agent-app/bin/monitor.sh
```

첫 경로는 소스, 두 번째는 설치본이다. 저장소 위치가 바뀌었거나 VM 공유 폴더가 없으면 첫 경로가 다르다. 설치를 하지 않았다면 두 번째 파일이 없을 수 있다. 파일이 존재하는데도 실행 오류가 나면 실행 형식·인터프리터 문제도 확인한다.

### `Exec format error` 또는 Mac에서 실행 불가

```bash
uname -s
uname -m
file /home/agent-admin/agent-app/agent-app-linux-arm64
```

Linux ARM64 파일은 Linux ARM64 환경에서 실행한다. x86_64 VM에는 x86 파일이 필요하다. `setup.sh`는 VM 아키텍처를 기준으로 선택한다.

### `Permission denied`

```bash
id agent-admin
sudo namei -l /home/agent-admin/agent-app/bin/monitor.sh
sudo getfacl /home/agent-admin
sudo stat -c '%U:%G %a' /home/agent-admin/agent-app/bin/monitor.sh
```

파일 모드뿐 아니라 부모 디렉토리 통과 권한과 ACL도 본다. 설치된 monitor 기대값은 `agent-dev:agent-core 750`이다. 그룹을 추가한 뒤 이전 로그인 셸은 옛 그룹 목록을 유지할 수 있다. 새 로그인 세션으로 다시 확인한다.

### SSH 설정은 20022인데 LISTEN은 22

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin) '
sudo systemctl status ssh ssh.socket --no-pager
sudo ss -ltnp 'sport = :20022'
```

Include 설정, 서비스 재시작, Ubuntu 24.04 socket activation 반영 여부를 확인한다. [2장](02-network.md)의 설정·상태·동작 구분으로 돌아가 본다. 현재 setup은 socket 반영을 처리한다. 원격 접속 중 무작정 방화벽을 초기화하지 않는다.

### Boot에서 `Missing File: secret.key`

```bash
sudo -iu agent-admin env | grep '^AGENT_'
sudo ls -l /home/agent-admin/agent-app/api_keys
sudo -u agent-admin readlink /home/agent-admin/agent-app/api_keys/secret.key
```

실제 키는 t_secret.key, 링크는 secret.key → t_secret.key다. 바이너리를 직접 실행해 로그인 환경의 파일 경로를 그대로 넘겼는지 확인한다. [run-agent.sh](../../bin/run-agent.sh)를 사용하면 앱에 필요한 디렉토리 경로로 바꾼다.

### Boot에서 포트를 이미 사용한다고 함

```bash
sudo ss -ltnp 'sport = :15034'
sudo systemctl status agent-assignment --no-pager
```

이전 앱이 실행 중이면 중복 실행하지 않는다. 검증용 agent-assignment 서비스가 active라면 기존 것을 사용하거나 정상 중지한 뒤 전경 앱을 켠다. 다른 프로세스라면 이름과 용도를 확인하기 전 임의로 종료하지 않는다.

### `Checking agent process... [FAIL]`

앱 터미널이 살아 있는지 확인하고 [앱 실행 안내](../../README.md)의 명령으로 시작한다. 현재 monitor는 ARM64/x86 제공 파일명과 Python 앱을 자동으로 확인한다. 예전 문서처럼 `AGENT_PROCESS_PATTERN`을 추가할 필요는 없다.

### 프로세스는 OK인데 포트 FAIL

앱이 아직 준비 중인지, 다른 포트로 실행되었는지 `ss`와 Boot 로그를 본다. “프로세스 존재”는 “요청을 받을 준비 완료”와 다르다. 앱을 다시 켰다면 Boot 성공 후 관제를 실행한다.

### `Firewall status unavailable`

```bash
sudo -u agent-admin sudo -n /usr/sbin/ufw status
```

바깥 sudo는 agent-admin으로 명령을 시작하고, 안쪽 sudo는 이 사용자에게 허용한 **상태 조회 한 개**를 root로 수행한다. `-n`은 암호를 기다리지 않고 권한이 없으면 즉시 실패하게 한다.

조회가 거부되면 `/etc/sudoers.d/agent-monitor` 설정 적용 여부를 관리 계정에서 확인한다. 앱 전체를 root로 바꾸는 방법으로 해결하지 않는다. `Firewall is not active`와 `status unavailable`은 각각 비활성 확인과 조회 실패를 뜻한다.

### 로그가 없거나 cron 이후 늘지 않음

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
echo $?
sudo -u agent-admin crontab -l
sudo systemctl is-active cron
sudo journalctl -u cron --since '5 minutes ago' --no-pager
```

수동 실행부터 성공해야 한다. 앱이 없으면 monitor는 기록 전에 종료하므로 cron이 정상이어도 새 줄이 생기지 않는다. 회전 직후라면 현재 로그의 줄 수가 작아진다. 최신 시간과 `.1`도 함께 확인한다.

### 수정했는데 동작이 똑같음

소스와 설치본이 다른지 확인한다.

```bash
sudo cmp /Users/hankkim/Desktop/codyssey/B4-1/bin/monitor.sh /home/agent-admin/agent-app/bin/monitor.sh
echo $?
```

0이면 같고 1이면 다르다. 경로 오류 같은 문제는 다른 실패 코드가 될 수 있다. 수정본은 setup으로 다시 배치한 뒤 검사한다. [tests 안내](../../tests/README.md)를 참고한다.

## 7.3 검증은 세 가지로 나눈다

| 종류 | 예 | 증명 범위 |
| --- | --- | --- |
| 문법 검사 | bash -n | 코드를 해석할 수 있는지 |
| 임시 자료 검사 | 10MiB 회전, 경계값, 샘플 통계 | 특정 로직이 예상대로 작동하는지 |
| 실제 환경 검사 | 사용자 접근, SSH 인증, 앱 포트, cron 로그 | 실제 VM에서 연결되어 작동하는지 |

[tests/README](../../tests/README.md)에 실행자와 변경 범위를 적었다. 특히 실패 테스트는 앱을 중지하며 SSH 테스트는 임시 키를 등록·제거한다. 학습 첫 단계에서 테스트 전체를 이유 없이 실행할 필요는 없다.

“테스트 통과”는 검사한 범위에서 통과했다는 뜻이다. 예를 들어 ARM64 검증은 x86 실행까지 증명하지 않으며, 방화벽의 비활성 분기를 응답 대체로 검사했다면 실제 방화벽을 껐다고 기록하지 않는다.

## 7.4 제출 증거를 남기는 방법

명령과 결과가 함께 보이게 저장한다. 성공 기준을 짚는 설명도 한 줄 붙인다. 비밀번호·실제 인증 비밀을 캡처하지 않는다.

- SSH: 최종 설정 + 실제 LISTEN + 인증 검사
- 권한: 소유권·ACL + 일반 사용자로 실제 허용/거부 확인
- 앱: 5단계 OK + READY + 0.0.0.0:15034
- 관제: 정상 측정·경고·로그 + 실패 시 종료 코드
- cron: 일정표 + 1~2분 전후 로그 + 실행 기록

현재 [수행 내역서](../submission.md)가 이 구조로 작성되어 있다. [검증 자료](../evidence/README.md)를 읽고 “이 출력이 어떤 요구사항을 증명하는가”를 설명해 보는 것이 좋은 복습이다.

Git으로 제출한다면 `git status`에서 파일 목록을 확인한다. `??`는 아직 추적되지 않는 파일이며 일반 `git diff`에 내용이 나타나지 않을 수 있다. 새 문서·이미지를 직접 확인하고, 필요한 파일을 선택해 추가·커밋한다. 커밋은 로컬 기록이고 push는 원격 전송이다. 최신 반영 여부는 `git status`와 GitHub의 커밋 내역을 함께 확인한다.

## 확인 질문

1. 앱이 없어서 관제 로그가 늘지 않는데 cron부터 재설치해야 하는가?
2. 실패 화면은 어떤 용도로 제출할 수 있는가?
3. `git diff`가 비었다면 새 파일이 전혀 없다는 뜻인가?

<details>
<summary>답 확인</summary>

1. 아니다. 앱 → 수동 관제 → cron 순서로 원인을 좁힌다.
2. 장애 조건을 의도대로 탐지한 증거나 문제 해결 과정으로 사용할 수 있다. 최종 정상 상태의 증거도 따로 필요하다.
3. 아니다. untracked 파일은 git status와 직접 파일 읽기로 확인한다.

</details>
