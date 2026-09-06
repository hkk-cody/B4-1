#!/usr/bin/env bash
# 같은 유효한 임시 키로 일반 계정 성공과 root 거부를 검증하고 즉시 정리한다.
set -euo pipefail
TMP=$(mktemp -d)
cleanup() {
  for user in agent-admin root; do
    if [[ $user == root ]]; then dir=/root/.ssh; else dir=/home/agent-admin/.ssh; fi
    if [[ -f "$TMP/$user.original" ]]; then cp -p "$TMP/$user.original" "$dir/authorized_keys";
    elif [[ -f "$TMP/$user.added" ]]; then rm -f "$dir/authorized_keys"; fi
  done
  rm -rf "$TMP"
}
trap cleanup EXIT
ssh-keygen -q -t ed25519 -N '' -f "$TMP/key"
for user in agent-admin root; do
  if [[ $user == root ]]; then dir=/root/.ssh; else dir=/home/agent-admin/.ssh; fi
  install -d -o "$user" -g "$(id -gn "$user")" -m 700 "$dir"
  if [[ -f "$dir/authorized_keys" ]]; then cp -p "$dir/authorized_keys" "$TMP/$user.original";
  else touch "$TMP/$user.added"; fi
  cat "$TMP/key.pub" >> "$dir/authorized_keys"
  chown "$user:$(id -gn "$user")" "$dir/authorized_keys"
  chmod 600 "$dir/authorized_keys"
done
opts=(-n -p 20022 -i "$TMP/key" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$TMP/known_hosts" -o ConnectTimeout=5)
[[ $(ssh "${opts[@]}" agent-admin@127.0.0.1 whoami) == agent-admin ]]
echo '[PASS] SSH port 20022: agent-admin authenticated using temporary key'
if ssh "${opts[@]}" root@127.0.0.1 whoami > "$TMP/root-result" 2>&1; then
  echo '[FAIL] root login unexpectedly succeeded'; exit 1
fi
cat "$TMP/root-result"
grep -q 'Permission denied' "$TMP/root-result"
echo '[PASS] SSH port 20022: root rejected even with authorized temporary key'
echo '[INFO] Temporary keys removed by cleanup'
