#!/usr/bin/env bash
# =====================================================================
# run-agent.sh — 제공 앱을 일반 계정(agent-admin)으로 실행
#   실행 방법 : sudo -iu agent-admin /home/agent-admin/agent-app/bin/run-agent.sh
#   종료 방법 : Ctrl+C
# =====================================================================
set -euo pipefail

# 환경 변수 불러오기 (로그인 셸이 아닌 방식으로 실행돼도 값이 있도록)
source /etc/profile.d/agent_env.sh

# 과제 조건: root로 실행 금지
if (( EUID == 0 )); then echo 'Run as agent-admin, not root.' >&2; exit 1; fi

# CPU 종류에 맞는 바이너리 선택 (setup.sh가 해당 파일만 설치함)
case $(uname -m) in
  aarch64|arm64) BINARY=agent-app-linux-arm64 ;;
  x86_64)        BINARY=agent-app-linux-x86 ;;
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac

# 과제는 AGENT_KEY_PATH를 "파일 경로(.../t_secret.key)"로 정하지만,
# 제공 바이너리는 "디렉토리"를 받아 그 안의 secret.key를 찾는다.
# → 앱에 넘길 때만 디렉토리로 바꿔 준다. (로그인 환경 변수는 과제 값 그대로)
export AGENT_KEY_PATH="${AGENT_KEY_PATH%/*}"   # %/* : 마지막 '/' 뒤를 잘라냄

cd "$AGENT_HOME"
exec "$AGENT_HOME/$BINARY"   # exec: 이 셸을 앱 프로세스로 교체 (Ctrl+C가 앱에 바로 전달)
