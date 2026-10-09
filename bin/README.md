# 과제 실행 스크립트

| 파일 | 역할 | 읽을 학습 단원 |
| --- | --- | --- |
| [setup.sh](setup.sh) | Ubuntu 설정·파일 배치·cron 등록 | [권한](../docs/lessons/03-permissions.md), [코드 읽기](../docs/lessons/05-bash-and-monitor.md) |
| [run-agent.sh](run-agent.sh) | 일반 계정의 앱 실행·키 경로 호환 | [앱 환경](../docs/lessons/04-application.md) |
| [monitor.sh](monitor.sh) | 필수 관제 소스. 검사·측정·경고·로그 회전 | [코드 읽기](../docs/lessons/05-bash-and-monitor.md), [로그](../docs/lessons/06-logs-and-cron.md) |

세 파일 모두 섹션별로 학습용 주석을 달아 두었다. 처음 읽는다면 `setup.sh` → `run-agent.sh` → `monitor.sh` 순서를 권장한다. 보너스 과제(report.sh, 로그 아카이브)는 수행하지 않는다.

실행 순서는 [루트 README](../README.md), 실제 수행 결과는 [수행 내역서](../docs/submission.md)를 참고한다. 저장소 소스와 VM 설치본은 별도 파일이며 편집 후 `sudo bash bin/setup.sh`로 다시 반영해야 한다. 선택 학습용 dirname 예제는 [docs/examples](../docs/examples/dirname_resolve.sh)로 옮겼다.
