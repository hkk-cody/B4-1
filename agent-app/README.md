# 제공 애플리케이션

이 폴더의 두 파일은 과제에서 제공한 Linux 실행 바이너리다. 소스코드처럼 편집하는 대상이 아니다.

| VM에서 실행한 uname -m | 파일 |
| --- | --- |
| aarch64 / arm64 | [agent-app-linux-arm64](agent-app-linux-arm64) |
| x86_64 | [agent-app-linux-x86](agent-app-linux-x86) |

`setup.sh`가 아키텍처에 맞는 파일을 `/home/agent-admin/agent-app`에 복사한다. 실행은 VM 안에서 일반 계정으로 `run-agent.sh`를 사용한다. [실행 방법](../README.md)과 [환경 변수·키 경로 설명](../docs/lessons/04-application.md)을 참고한다.

원본 과제는 t_secret.key 파일 경로를 환경 변수로 요구하지만 제공 바이너리는 디렉토리 아래 secret.key를 찾는다. 래퍼와 심볼릭 링크로 차이를 처리하며 바이너리 자체는 수정하지 않았다.

중복된 `agent-app.zip`은 내부 두 바이너리와 이 폴더 파일의 SHA-256 일치를 확인한 뒤 정리했다. 실행에 필요한 두 원본 파일은 보존했다. ARM64는 실제 검증했고 x86 실행은 별도로 검증하지 않았다.
