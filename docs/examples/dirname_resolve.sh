#!/usr/bin/env bash
set -euo pipefail

echo "--- 스크립트 디렉터리 안전하게 얻기 (심볼릭 링크 처리) ---"

# 사용법: 이 스크립트를 심볼릭 링크로 호출해도 실제 원본 스크립트의 디렉터리를 찾습니다.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  # 심볼릭 링크가 가리키는 대상 읽기
  TARGET="$(readlink "$SOURCE")"
  if [[ $TARGET == /* ]]; then
    SOURCE="$TARGET"
  else
    SOURCE="$DIR/$TARGET"
  fi
done

SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
echo "Resolved script dir: $SCRIPT_DIR"

# readlink -f 사용 가능한 경우(일부 Linux) - 간단한 대안
if command -v readlink >/dev/null 2>&1; then
  if readlink -f "$SOURCE" >/dev/null 2>&1; then
    echo "(readlink -f 사용 결과): $(dirname "$(readlink -f "$SOURCE")")"
  fi
fi

echo "끝"
