# 8. 용어 사전과 복습

[이전](07-troubleshooting.md) · [학습 목차](../README.md)

처음부터 전부 외울 필요는 없다. 명령을 읽다가 막히는 말을 찾고 해당 단원으로 돌아간다.

## 용어 사전

| 용어 | 뜻 | 관련 단원 |
| --- | --- | --- |
| OS | 운영체제. 프로그램과 시스템 자원을 관리 | [1장](01-basics.md) |
| VM | 독립된 운영체제 환경으로 다루는 가상 머신 | [1장](01-basics.md) |
| 터미널 | 명령과 텍스트 출력을 주고받는 창 | [1장](01-basics.md) |
| 셸 / Bash | 명령을 해석하는 프로그램 / 이번에 쓰는 셸 | [5장](05-bash-and-monitor.md) |
| 프롬프트 | 셸이 다음 입력을 기다리는 표시 | [1장](01-basics.md) |
| 절대·상대 경로 | 루트부터 적은 경로 / 현재 위치 기준 경로 | [1장](01-basics.md) |
| root | 최고 관리자 계정 | [3장](03-permissions.md) |
| 루트 디렉토리 | 파일 트리의 시작인 `/` | [1장](01-basics.md) |
| sudo | 허용된 다른 사용자 권한으로 명령 실행 | [3장](03-permissions.md) |
| UID / GID | 사용자 번호 / 그룹 번호 | [3장](03-permissions.md) |
| 소유자 / 그룹 | 파일 접근 정책의 기준이 되는 계정과 묶음 | [3장](03-permissions.md) |
| ACL | 추가 사용자·그룹에 대한 접근 규칙 | [3장](03-permissions.md) |
| default ACL | 새로 생성되는 항목의 상속 기준 | [3장](03-permissions.md) |
| mask | 특정 ACL 항목들에 적용되는 권한 상한 | [3장](03-permissions.md) |
| setgid | 디렉토리에서 새 항목의 그룹 상속에 사용 | [3장](03-permissions.md) |
| umask | 기본 파일 생성 권한을 제한하는 값 | [5장](05-bash-and-monitor.md) |
| 프로세스 / PID | 실행 중인 프로그램 / 그 번호 | [2장](02-network.md) |
| 서비스 | 지속적으로 기능을 제공하는 프로그램 등 | [2장](02-network.md) |
| systemd / systemctl | 서비스 등을 관리하는 체계 / 제어 명령 | [2장](02-network.md) |
| IP / 포트 | 통신 대상을 찾는 주소 / 서비스 구분 번호 | [2장](02-network.md) |
| TCP | 연결을 맺어 데이터를 주고받는 전송 프로토콜 | [2장](02-network.md) |
| LISTEN | 포트를 열고 연결 요청을 기다리는 상태 | [2장](02-network.md) |
| SSH / sshd | 암호화된 원격 접속 방식 / 서버 프로그램 | [2장](02-network.md) |
| UFW | 방화벽 규칙을 관리하는 도구 | [2장](02-network.md) |
| 환경 변수 | 자식 프로그램에 전달할 설정값 | [4장](04-application.md) |
| source | 현재 셸 안에서 파일의 명령을 실행 | [4장](04-application.md) |
| 바이너리 | 실행 가능한 형태로 제공된 프로그램 파일 | [4장](04-application.md) |
| 아키텍처 | CPU 명령 체계. ARM64/x86_64 등 | [4장](04-application.md) |
| 심볼릭 링크 | 다른 파일 경로를 가리키는 항목 | [4장](04-application.md) |
| Boot Sequence | 앱 시작 전 준비 조건을 확인하는 단계 | [4장](04-application.md) |
| Health Check | 앱 상태를 확인하는 검사 | [5장](05-bash-and-monitor.md) |
| 종료 코드 | 프로그램 성공·실패를 나타내는 숫자 | [5장](05-bash-and-monitor.md) |
| 파이프 | 앞 명령의 출력을 뒤 명령의 입력으로 연결 | [5장](05-bash-and-monitor.md) |
| 리다이렉션 | 입력·출력을 파일 등의 대상으로 연결 | [5장](05-bash-and-monitor.md) |
| awk | 텍스트 필드 처리와 계산을 하는 도구 | [5장](05-bash-and-monitor.md) |
| /proc | 커널·프로세스 정보를 파일처럼 제공하는 경로 | [6장](06-logs-and-cron.md) |
| 임계값 | 넘으면 경고하도록 정한 수치 | [6장](06-logs-and-cron.md) |
| 로그 / 회전 | 시간별 기록 / 파일을 나누고 보관 수를 제한 | [6장](06-logs-and-cron.md) |
| flock | 동시에 실행되는 작업 사이의 파일 잠금 | [6장](06-logs-and-cron.md) |
| cron / crontab | 일정 실행 서비스 / 사용자별 일정표 | [6장](06-logs-and-cron.md) |
| commit / push | 로컬 변경 기록 / 원격 저장소로 전송 | [7장](07-troubleshooting.md) |
| 재실행 가능성 | 다시 적용했을 때 의도한 구성이 유지되는 성질 | [5장](05-bash-and-monitor.md) |

## 과제 전체를 말로 설명해 보기

다음 빈칸을 채운다.

> Ubuntu에서 SSH 포트는 ___, 앱 포트는 ___이다. 앱과 cron의 실행 계정은 ___이다. 세 계정이 함께 쓰는 그룹은 ___이고, 키·로그에 접근하는 그룹은 ___이다. 관제 소스의 소유자는 ___이고 모드는 ___이다. 앱이 없으면 종료 코드는 ___이고, CPU가 20%를 넘으면 ___한다. 로그는 현재 파일과 회전본을 합해 최대 ___개다.

<details>
<summary>정답</summary>

20022 / 15034 / agent-admin / agent-common / agent-core / agent-dev / 750 / 1 / WARNING을 출력하고 계속 기록 / 10

</details>

## 스스로 확인할 최종 질문

- Mac에서 편집한 파일과 VM에서 실행하는 파일의 차이를 설명할 수 있는가?
- 왜 앱과 관제를 서로 다른 터미널에서 다루는가?
- `agent-test`의 키 디렉토리 접근 거부가 왜 성공 결과인가?
- 과제 키 경로와 제공 바이너리의 차이를 그림 없이 설명할 수 있는가?
- `bash -n`, 수동 실행, cron 확인이 각각 무엇을 검증하는가?
- CPU 20%와 20.1%의 결과를 예상할 수 있는가?
- 로그 회전 직후 줄 수만 비교하면 왜 잘못 판단할 수 있는가?
- VM 재시작 후 로그가 안 늘 때 무엇부터 확인해야 하는가?

답이 막히는 항목만 해당 단원으로 돌아가 읽는다. 모두 설명할 수 있다면 [실행 안내서](../../README.md)를 보며 다시 수행하고 [수행 내역서](../submission.md)의 증거를 자신의 말로 설명해 본다.
