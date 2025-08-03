#!/bin/bash

LOG_FILE="/var/ossec/logs/ARlog.log"
DEBUG_LOG="/var/ossec/logs/AR_debug.log"

# [1] 스크립트 시작 로그
echo "=== [AR] Script Triggered ===" >> "$DEBUG_LOG"

# [2] JSON 입력 전체 읽기
INPUT_JSON=$(cat)
echo "[AR] Raw JSON: $INPUT_JSON" >> "$DEBUG_LOG"

# [3] JSON 파싱
TARGET_FILE=$(echo "$INPUT_JSON" | jq -r '.parameters.alert.syscheck.path')
UPLOAD_DATE_RAW=$(echo "$INPUT_JSON" | jq -r '.parameters.alert.syscheck.mtime_after')

# 시간 포맷 가공
UPLOAD_DATE=$(date -d "$UPLOAD_DATE_RAW" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
if [ -z "$UPLOAD_DATE" ]; then
  UPLOAD_DATE="Unknown"
fi

# [4] 파일 경로 유효성 검사
if [ -z "$TARGET_FILE" ] || [ "$TARGET_FILE" = "null" ]; then
    echo "[ERROR] Invalid or missing file path in JSON." >> "$DEBUG_LOG"
    exit 1
fi

# [5] 파일 존재 확인 (최대 3초 대기)
for i in {1..6}; do
  if [ -f "$TARGET_FILE" ]; then
    break
  fi
  sleep 0.5
done

if [ ! -f "$TARGET_FILE" ]; then
    echo "[ERROR] File not found: $TARGET_FILE" >> "$LOG_FILE"
    echo "[ERROR] $TARGET_FILE not found, skipping grep" >> "$DEBUG_LOG"
    exit 1
fi

# [6] 탐지 로그 시작
echo "=== Webshell Detection Started ===" >> "$LOG_FILE"
echo "[*] Target File : $TARGET_FILE" >> "$LOG_FILE"
echo "[*] Upload Time : $UPLOAD_DATE" >> "$LOG_FILE"

# [7] 탐지 패턴 목록
patterns=(
  "base64_decode"
    "eval\\s*\\("
  "assert\\s*\\("
)

# [8] 탐지 수행
DETECTED=0
for pattern in "${patterns[@]}"; do
  if grep -Eiq "$pattern" "$TARGET_FILE"; then
    echo "[!] Pattern matched: $pattern" >> "$LOG_FILE"
    DETECTED=1
  fi
done

if [ "$DETECTED" -eq 1 ]; then
  echo "[!] Webshell detected: $TARGET_FILE" >> "$LOG_FILE"
else
  echo "[-] No suspicious pattern in $TARGET_FILE" >> "$LOG_FILE"
fi

# [9] 종료 로그
echo "=== Webshell Detection Finished ===" >> "$LOG_FILE"