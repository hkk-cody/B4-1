#!/usr/bin/env bash
set -euo pipefail

IFS=$'\n\t'
export LC_ALL=C

LOG_FILE="${1:-/var/log/agent-app/monitor.log}"
START_TS="${2:-}"
END_TS="${3:-}"

awk_script='BEGIN {
  sample_count = 0
  cpu_sum = mem_sum = disk_sum = 0
  cpu_min = mem_min = disk_min = 1e9
  cpu_max = mem_max = disk_max = -1
}

/^[[][0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9][]] PID:[0-9]+ CPU:[0-9]+([.][0-9]+)?% MEM:[0-9]+([.][0-9]+)?% DISK_USED:[0-9]+([.][0-9]+)?%$/ {
  timestamp = substr($0, 2, 19)
  if (START_TS != "" && timestamp < START_TS) {
    next
  }
  if (END_TS != "" && timestamp > END_TS) {
    next
  }

  count = split($0, parts, /CPU:|% MEM:|% DISK_USED:|%/)
  if (count < 5) {
    next
  }

  cpu_value = parts[2] + 0
  mem_value = parts[3] + 0
  disk_value = parts[4] + 0

  sample_count++
  cpu_sum += cpu_value
  mem_sum += mem_value
  disk_sum += disk_value

  if (cpu_value < cpu_min) { cpu_min = cpu_value; cpu_min_ts = timestamp }
  if (cpu_value > cpu_max) { cpu_max = cpu_value; cpu_max_ts = timestamp }
  if (mem_value < mem_min) { mem_min = mem_value; mem_min_ts = timestamp }
  if (mem_value > mem_max) { mem_max = mem_value; mem_max_ts = timestamp }
  if (disk_value < disk_min) { disk_min = disk_value; disk_min_ts = timestamp }
  if (disk_value > disk_max) { disk_max = disk_value; disk_max_ts = timestamp }
}

END {
  printf "====== STATISTICS REPORT ======\n"

  if (sample_count == 0) {
    printf "  No samples found\n"
    printf "  [Samples]\n    Data Points: 0 samples\n"
    exit 0
  }

  printf "  [CPU]\n"
  printf "    Average : %.1f%%\n", cpu_sum / sample_count
  printf "    Maximum : %.1f%% at %s\n", cpu_max, cpu_max_ts
  printf "    Minimum : %.1f%% at %s\n", cpu_min, cpu_min_ts

  printf "  [Memory]\n"
  printf "    Average : %.1f%%\n", mem_sum / sample_count
  printf "    Maximum : %.1f%% at %s\n", mem_max, mem_max_ts
  printf "    Minimum : %.1f%% at %s\n", mem_min, mem_min_ts

  printf "  [Disk]\n"
  printf "    Average : %.1f%%\n", disk_sum / sample_count
  printf "    Maximum : %.1f%% at %s\n", disk_max, disk_max_ts
  printf "    Minimum : %.1f%% at %s\n", disk_min, disk_min_ts

  printf "  [Samples]\n    Data Points: %d samples\n", sample_count
}'

if [[ -n "$START_TS" && -n "$END_TS" && "$START_TS" > "$END_TS" ]]; then
  echo "Start time must not exceed end time" >&2
  exit 1
fi

if [[ ! -f "$LOG_FILE" || ! -r "$LOG_FILE" ]]; then
  printf 'Log file not found: %s\n' "$LOG_FILE" >&2
  exit 1
fi

awk -v START_TS="$START_TS" -v END_TS="$END_TS" "$awk_script" "$LOG_FILE"
