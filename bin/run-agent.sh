#!/usr/bin/env bash
# 과제 환경변수는 파일 경로로 유지하고 제공 바이너리에만 디렉토리를 전달한다.
set -euo pipefail
source /etc/profile.d/agent_env.sh
if ((EUID == 0)); then echo 'Run as agent-admin, not root.' >&2; exit 1; fi
case "$(uname -m)" in
  aarch64|arm64) binary=agent-app-linux-arm64 ;;
  x86_64) binary=agent-app-linux-x86 ;;
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac
export AGENT_KEY_PATH
AGENT_KEY_PATH=$(dirname -- "$AGENT_KEY_PATH")
cd "$AGENT_HOME"
exec "$AGENT_HOME/$binary"
