# 리눅스 서버 운영 과제 — 실행과 확인 안내

이 과제는 **앱이 실행될 Linux 환경을 만들고, 서버 상태를 매분 로그에 기록하는 것**이다. 앱은 제공된 실행 파일을 사용하며, 핵심 작성 대상은 Bash 스크립트 `monitor.sh`다.

처음 공부한다면 [학습 안내](docs/README.md)부터 읽는다. 이 README는 실제 과제를 수행할 때 옆에 두고 따라가는 실행 안내서다. [원본 과제](docs/assignment/requirements.md), [수행 내역서](docs/submission.md), [실제 검증 증거](docs/evidence/README.md)는 각각 따로 보관했다.

## 1. 실행 전에 알아둘 것

| 구분 | 이 저장소의 기준 |
| --- | --- |
| 실습 환경 | Mac의 OrbStack → `24.04ubuntu` → Ubuntu 24.04.4 LTS, ARM64 |
| 저장소 위치 | `/Users/hankkim/Desktop/codyssey/B4-1` — 소스와 문서를 편집하는 곳 |
| 앱 설치 위치 | `/home/agent-admin/agent-app` — VM에서 앱과 관제를 실제 실행하는 곳 |
| 로그 위치 | `/var/log/agent-app/monitor.log` — VM에 생성되는 결과 |
| 수행 범위 | 필수 과제만 수행. 보너스 1·2는 미선택 |
| 검증 이력 | 2026-10-08 ARM64 VM에서 간소화한 스크립트로 재설치·전체 테스트 통과 |

**아래 명령은 별도 표시가 없으면 Ubuntu VM의 일반 관리 계정 터미널에서 실행한다.** 현재 VM의 기본 계정은 `hankkim`이다. `sudo`는 필요한 명령 한 개를 관리자 권한으로 실행한다. `sudo -u agent-admin`은 해당 명령을 `agent-admin`으로 실행한다.

터미널에 명령을 붙여 넣고 Enter를 누른다. `$` 같은 프롬프트 표시는 입력하지 않는다. 암호를 물으면 현재 관리 계정의 암호를 입력한다. 입력 중 글자가 표시되지 않는 것은 정상이다.

### VM 터미널 열기

1. Mac에서 OrbStack을 연다.
2. 왼쪽 **Machines**에서 **24.04ubuntu**를 선택한다.
3. Stopped이면 재생 버튼을 누른다.
4. 상단 **Terminal**을 선택한다.
5. 아래 명령으로 Linux인지 확인한다.

```bash
uname -s
whoami
pwd
```

첫 결과가 `Linux`여야 한다. `Darwin`이면 Mac 터미널이다. Mac 터미널에서 VM으로 들어가려면 다음을 먼저 실행한다.

```bash
orb -m 24.04ubuntu
```

## 2. 어떤 파일을 사용하는가?

```text
B4-1/
├── README.md              실행 순서·확인 기준·파일 안내
├── agent-app/             제공된 Linux 앱 2종
├── bin/
│   ├── setup.sh           VM 설정·파일 설치·cron 등록
│   ├── run-agent.sh       일반 계정으로 앱 실행
│   └── monitor.sh         상태 측정·경고·로그 기록·로그 회전
├── tests/                 검증용 Bash 스크립트
└── docs/
    ├── README.md          학습 순서
    ├── lessons/           초보자용 학습 단원
    ├── assignment/        원본 과제와 수정 내역
    ├── submission.md      완료된 수행 내역서
    ├── evidence/          실제 실행 출력과 OrbStack 캡처
    ├── images/history/    과거 캡처 — 학습·비교용
    └── examples/          선택 학습 예제
```

| 파일 | 실행 시점 | 실행 권한 |
| --- | --- | --- |
| [setup.sh](bin/setup.sh) | 처음 설치하거나 수정한 소스를 VM에 다시 반영할 때 | 관리 계정에서 sudo |
| [run-agent.sh](bin/run-agent.sh) | 앱을 켤 때 | agent-admin |
| [monitor.sh](bin/monitor.sh) | 앱 상태를 한 번 확인할 때, cron이 매분 실행할 때 | agent-admin |
| [tests 안내](tests/README.md) | 정상/실패 조건을 자동 검사할 때 | 테스트별로 다름 |

**저장소 파일을 수정해도 VM에 이미 설치한 복사본이 자동으로 바뀌지는 않는다.** 수정 후에는 설치 명령으로 다시 반영하고 검증한다.

## 3. 처음 설치하기

이미 설정된 현재 VM에서는 곧바로 **4번 앱 상태 확인**으로 가도 된다. 새로 구성하거나 소스 변경을 반영할 때만 아래를 실행한다.

VM 터미널:

```bash
cd /Users/hankkim/Desktop/codyssey/B4-1
ls bin/setup.sh
sudo bash bin/setup.sh
```

저장소를 다른 위치로 옮겼다면 `cd` 뒤의 경로를 실제 위치로 바꾼다. OrbStack 공유 폴더가 없으면 [파일 위치 문제](docs/lessons/07-troubleshooting.md)를 확인한다.

설치는 SSH·UFW·계정·ACL·환경 변수·앱 배치·cron 등록까지 수행한다. 마지막에 `Setup complete`가 나오면 설치가 끝난 것이다. **앱 자체는 다음 단계에서 실행한다.** 다른 서버가 아닌 이 과제 VM에서 실행한다. 재실행하면 과제 환경 변수·테스트 키·권한도 다시 적용된다.

## 4. 앱을 켜기 — 터미널 A

먼저 이미 실행 중인지 확인한다.

```bash
sudo ss -ltnp 'sport = :15034'
```

`LISTEN`과 `0.0.0.0:15034`가 나오면 해당 앱 프로세스인지 확인한 후 **5번 관제 실행**으로 이동한다. 실행 중인 앱을 한 번 더 켜면 포트 충돌이 난다.

아무 LISTEN 줄도 없으면 다음을 실행한다.

```bash
sudo -iu agent-admin /home/agent-admin/agent-app/bin/run-agent.sh
```

정상 기준:

- `Running as service user 'agent-admin'`
- Boot Sequence `[1/5]`부터 `[5/5]`까지 모두 `[OK]`
- `Agent READY`
- `Agent listening at port 15034`

이 터미널은 **앱을 실행한 채로 둔다.** 명령 입력 표시가 다시 나오지 않고 로그가 계속 출력되는 것이 정상이다. 앱을 종료할 때만 Ctrl+C를 누른다.

### 이전 검증용 앱이 실행 중인 경우

이전 검증에서는 `agent-assignment`라는 임시 systemd 서비스로 앱을 켜 두었다. 직접 Boot 화면을 보고 싶다면 먼저 관리 계정 터미널에서 아래를 실행한다.

```bash
sudo systemctl status agent-assignment --no-pager
```

`active (running)`이면 `sudo systemctl stop agent-assignment`로 멈춘 뒤 위의 일반 계정 실행 명령을 사용한다. 서비스가 없으면 이 단계는 생략한다. 임시 서비스는 VM 재부팅 뒤 자동 시작하지 않는다.

## 5. 관제를 실행하기 — 터미널 B

Mac에서 새 터미널 창을 열고 `orb -m 24.04ubuntu`로 같은 VM에 들어간다. 앱을 실행 중인 터미널 A는 그대로 둔다.

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
echo $?
```

정상 기준은 프로세스·포트 `[OK]`, CPU/MEM/DISK 숫자, `[INFO] Log appended`, 종료 코드 `0`이다. `echo $?`는 **바로 직전에 실행한 명령**의 결과를 확인하므로 다른 명령보다 먼저 입력한다.

```bash
sudo -u agent-admin tail -n 5 /var/log/agent-app/monitor.log
```

최근 5줄을 보여 준다. 로그가 적으면 있는 줄만 출력한다. 다음 형식이면 된다. 시간·PID·사용률은 실행할 때마다 달라진다.

```text
[2026-09-06 22:05:03] PID:4734 CPU:2.9% MEM:12.8% DISK_USED:2%
```

`[WARNING] MEM threshold exceeded` 같은 자원 경고는 임계값 초과를 알리는 정상 기능이다. 로그가 계속 추가되어야 한다. `[FAIL]` 또는 `Firewall status unavailable`이면 [문제 해결](docs/lessons/07-troubleshooting.md)에서 원인을 확인한다.

![OrbStack에서 agent-admin 권한으로 실행한 실제 관제](docs/evidence/orbstack-monitor.png)

## 6. 매분 자동 실행 확인하기

설치 스크립트가 `agent-admin`의 crontab에 다음 항목을 등록한다. 이미 있으므로 같은 줄을 다시 추가하지 않는다.

```bash
sudo -u agent-admin crontab -l
sudo systemctl is-active cron
```

기대 결과:

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
```

서비스 상태는 `active`여야 한다. 다음 순서로 비교한다.

1. 앱이 켜진 상태에서 아래 명령을 실행해 줄 수와 마지막 시간을 기록한다.
2. `monitor.sh`를 수동 실행하지 않고 1~2분 기다린다.
3. 같은 명령을 다시 실행해 새 시간의 로그가 생겼는지 확인한다.

```bash
date
sudo -u agent-admin wc -l /var/log/agent-app/monitor.log
sudo -u agent-admin tail -n 3 /var/log/agent-app/monitor.log
```

실행 기록도 확인할 수 있다.

```bash
sudo journalctl -u cron --since '5 minutes ago' --no-pager
```

매분은 “명령 실행 후 정확히 60초마다”가 아니라 **매 시각의 분 단위 일정**이다. 측정에 약 1초가 들어가므로 로그 시간은 정각보다 조금 늦을 수 있다. 로그 회전이 일어나면 현재 파일의 줄 수가 줄 수 있으므로 마지막 시간과 회전본도 함께 본다.

## 7. 제출 전에 확인할 내용

| 항목 | 확인 명령 또는 방법 | 정상 기준 |
| --- | --- | --- |
| SSH 설정 | `sudo sshd -T \| grep -E '^(port\|permitrootlogin) '` | 20022, no |
| SSH 실제 포트 | `sudo ss -ltnp 'sport = :20022'` | LISTEN |
| 방화벽 | `sudo ufw status verbose` | active, 20022/tcp·15034/tcp만 허용 |
| 계정·그룹 | `id agent-admin`, `id agent-dev`, `id agent-test` | common에 3명, core에 admin/dev |
| 권한·ACL | 아래 상세 명령 | upload는 common, 키·로그는 core |
| 환경 변수 | `sudo -iu agent-admin env \| grep '^AGENT_'` | 아래 표와 일치 |
| 앱 | Boot 화면과 `ss` 확인 | 5개 OK, Agent READY, 0.0.0.0:15034 |
| 관제 권한 | `sudo stat -c '%U:%G %a' /home/agent-admin/agent-app/bin/monitor.sh` | agent-dev:agent-core 750 |
| 실패 시 동작 | 앱 종료 후 관제 실행, `echo $?` | 프로세스 FAIL, 종료 코드 1 |
| 관제·cron | 5~6번 절차 | 로그 기록 및 자동 증가 |
| 로그 회전 | tests의 경계값 검사 | 10MiB, 현재 파일 포함 최대 10개 |

권한과 환경 변수:

```bash
sudo getfacl /home/agent-admin/agent-app/upload_files
sudo getfacl /home/agent-admin/agent-app/api_keys
sudo getfacl /var/log/agent-app
sudo -iu agent-admin env | grep '^AGENT_'
```

| 변수 | 값 |
| --- | --- |
| AGENT_HOME | /home/agent-admin/agent-app |
| AGENT_PORT | 15034 |
| AGENT_UPLOAD_DIR | /home/agent-admin/agent-app/upload_files |
| AGENT_KEY_PATH | /home/agent-admin/agent-app/api_keys/t_secret.key |
| AGENT_LOG_DIR | /var/log/agent-app |

키는 과제의 `t_secret.key`에 저장된다. 제공 바이너리는 `secret.key`와 디렉토리 경로를 기대하므로 `run-agent.sh`가 앱에 전달할 값만 변환한다. 자세한 이유는 [환경 변수 학습](docs/lessons/04-application.md)에 설명했다.

자동 검증을 실행하려면 [tests 안내](tests/README.md)를 따른다. 테스트 일부는 앱을 종료하거나 임시 인증키를 추가·제거하므로 먼저 해당 테스트 설명을 읽는다. 앱 종료 검증 후에는 4번 명령으로 앱을 다시 켠다.

## 8. 제출 자료

보너스 과제(report.sh 통계, 시간 기반 로그 아카이브)는 수행하지 않는다. 제출할 핵심 자료는 다음과 같다.

- [수행 내역서](docs/submission.md): 설정·명령·결과·검증 증거 링크
- [monitor.sh](bin/monitor.sh): 필수 소스
- [실제 증거](docs/evidence/README.md): 해당 문서가 참조하는 출력과 이미지

문서만 따로 복사하면 상대 링크의 이미지와 증거가 빠질 수 있다. 관련 폴더 구조를 함께 유지한다. 설정을 바꿨다면 기존 캡처를 그대로 완료 증거로 쓰지 말고 현재 결과로 갱신한다.
