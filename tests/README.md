# 검증 스크립트 안내

테스트는 **Ubuntu 과제 VM**에서 실행한다. macOS에서 실행하거나 앱을 켜지 않은 상태에서 전체 검증을 시작하지 않는다. [실행 안내](../README.md)에서 설치와 앱 실행을 먼저 마친다.

| 파일 | 실행자 | 검사 내용 | 실제 영향 |
| --- | --- | --- | --- |
| [test_monitor.sh](test_monitor.sh) | agent-admin | 임계값, 10MiB 회전, 실제 자원 수집, 통계, 잘못된 로그 | /tmp의 테스트 자료만 생성·정리. 운영 로그를 사용하지 않음 |
| [verify_vm.sh](verify_vm.sh) | root | SSH/UFW·계정·ACL·환경·앱·관제 | 임시 접근 검사 파일 생성·정리, 정상 monitor.log 한 줄 추가 |
| [verify_ssh.sh](verify_ssh.sh) | root | 일반 계정 SSH 성공·root 거부 | 임시 인증키를 authorized_keys에 추가하고 종료 시 원래 상태로 복원 |
| [verify_failures.sh](verify_failures.sh) | root | 닫힌 포트와 앱 정지의 exit 1 | agent-assignment 서비스를 SIGINT로 정지하고 앱 다시 실행 |

## 처음에는 이 두 개부터

VM의 기본 관리 계정에서 실행한다.

```bash
sudo -u agent-admin bash /Users/hankkim/Desktop/codyssey/B4-1/tests/test_monitor.sh
sudo bash /Users/hankkim/Desktop/codyssey/B4-1/tests/verify_vm.sh
```

정상 기준은 각각 마지막의 `All regression tests passed.`, `All VM checks passed.`다. SSH 로그인을 추가 확인할 때:

```bash
sudo bash /Users/hankkim/Desktop/codyssey/B4-1/tests/verify_ssh.sh
```

`agent-admin authenticated`, `root rejected` 두 PASS를 확인한다. root의 `Permission denied`는 의도한 성공 결과다. 테스트는 일반·root 계정에 같은 유효한 임시 공개키를 등록하고 root 정책으로 거부되는지 확인한다. 테스트 후 임시 키로 계속 접속할 수는 없다.

## 실패 검사는 실행 방식부터 확인

`verify_failures.sh`는 **앱이 agent-assignment 임시 systemd 서비스로 실행 중인 환경**을 전제로 한다. 임의의 앱 프로세스를 종료하는 범용 스크립트가 아니다. `sudo systemctl status agent-assignment --no-pager`로 먼저 확인한다.

해당 서비스로 실행 중이면:

```bash
sudo bash /Users/hankkim/Desktop/codyssey/B4-1/tests/verify_failures.sh
```

전경 터미널에서 앱을 실행 중이라면 대신 해당 터미널에서 Ctrl+C로 앱을 종료하고, 별도 터미널에서 monitor의 FAIL과 종료 코드 1을 확인한다. 검사 후 [README](../README.md)의 일반 계정 실행 명령으로 앱을 다시 켠다.

## 결과 해석

- 방화벽 active는 실제 VM 명령으로 확인한다. 회귀 테스트의 inactive/조회 오류 분기는 명령 응답을 대체해 검사한다.
- 임계값·회전 테스트의 숫자는 통제한 테스트 입력이다. 실제 VM 사용률과 혼동하지 않는다.
- 기존 실행 결과는 [증거 목록](../docs/evidence/README.md)에 있다. 설정을 바꿨다면 새 결과를 남긴다.
- 테스트는 설치나 제출 자체가 아니다. 실행 후 문서의 설정값과 증거가 일치하는지도 확인한다.
