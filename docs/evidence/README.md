# 실제 검증 증거

2026-09-06 22:00~22:06 KST, OrbStack `24.04ubuntu` / Ubuntu 24.04.4 LTS / ARM64에서 생성했다. 텍스트는 실제 명령 출력이며 화면은 컴퓨터 제어 도구로 저장했다.

| 파일 | 내용 |
| --- | --- |
| [verification.txt](verification.txt) | 최종 SSH/UFW·계정·ACL·환경·앱·관제 종합 검사 |
| [ssh-login.txt](ssh-login.txt) | 임시 유효 키를 이용한 일반 계정 성공과 root 거부 |
| [boot.txt](boot.txt) | 실제 앱 Boot 5단계 OK 및 Agent READY |
| [monitor.txt](monitor.txt) | 최종 관제 수동 실행 |
| [orbstack-monitor.png](orbstack-monitor.png) | OrbStack 내장 터미널에서 직접 실행한 화면 |
| [cron-before.txt](cron-before.txt), [cron-after.txt](cron-after.txt) | 22:04:03~22:05:24 사이 cron만으로 6줄→7줄 증가 |
| [failure-cases.txt](failure-cases.txt) | 닫힌 포트, 실제 앱 정지 시 exit 1 |
| [regression.txt](regression.txt) | 실제 10MiB 회전, 경계값, 자원 수집, 통계 검사. 방화벽 오류 분기는 대체 응답 사용 |
| [report.txt](report.txt) | 실제 누적 로그 10개 샘플에 대한 보너스 통계 |
| [setup.txt](setup.txt), [setup-rerun.txt](setup-rerun.txt) | 설치 및 재실행 완료 |
| [deployment.txt](deployment.txt) | 최종 소스 일치, 실행 상태, monitor 소유권·모드 |

`boot.txt`와 화면 캡처는 초기 성공 시점이며 종합 검증은 최종 배치 이후 수행했다. 검증 중 앱을 재시작했으므로 증거별 PID는 다를 수 있다. 보너스 2 및 x86 바이너리 실행 검증은 포함하지 않는다.
