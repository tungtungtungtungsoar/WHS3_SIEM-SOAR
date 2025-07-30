#!/bin/bash

#109997

LOG="/var/ossec/logs/active-responses.log"
read INPUT
NOW=$(date "+%Y-%m-%d %H:%M:%S")
TTY=$(echo "$INPUT" | grep -oP 'pts[0-9]+' | sed 's/pts/pts\//' | head -n1)
REAL_IP=$(who | grep "$TTY" | awk '{print $5}' | tr -d '()' | tail -n1)

if [[ -z "$REAL_IP" ]]; then
echo "$NOW [ERROR] Could not resolve IP from TTY : $TTY " >> "$LOG"
exit 1
fi

IP="$REAL_IP"
#---------------------------------------------------------------------
WHITELIST="/etc/wazuh/bastion_whitelist.txt"
BLOCKED_LIST="/etc/wazuh/blocked_ip_list.txt"
LOCKFILE="/tmp/ssh_response.lock"
#---------------------------------------------------------------------

# 중복 실행 방지

if [ -e "$LOCKFILE" ]; then
echo "$NOW [INFO] Lockfile exists. Skipping duplicate execution." >> "$LOG"
exit 0
fi

touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# 함수: 화이트리스트 확인

is_whitelisted() {
grep -qFx "$IP" "$WHITELIST" 2>/dev/null
}

# 함수: 이미 차단되었는지 확인

already_blocked() {
grep -qFx "$IP" "$BLOCKED_LIST" 2>/dev/null
}

# 함수: 현재 감지된 TTY의 SSH 세션 강제 종료

kill_detected_ssh_session() {
local target_ip="$1"
local detected_tty="$2"

echo "$NOW [INFO] Attempting to terminate SSH session for TTY: $detected_tty from IP: $target_ip" >> "$LOG"

# 현재 감지된 TTY만 정확히 종료

if [[ -n "$detected_tty" && "$detected_tty" =~ ^pts/ ]]; then
# 해당 TTY가 실제로 target_ip에서 온 것인지 재확인
current_ip=$(who | grep " $detected_tty " | awk '{print $5}' | tr -d '()')

```
if [[ "$current_ip" == "$target_ip" ]]; then
  echo "$NOW [INFO] Killing SSH session on $detected_tty from IP $target_ip" >> "$LOG"
  pkill -KILL -t "$detected_tty" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "$NOW [SUCCESS] SSH session on $detected_tty terminated successfully" >> "$LOG"
  else
    echo "$NOW [WARNING] Failed to terminate session on $detected_tty" >> "$LOG"
  fi
else
  echo "$NOW [WARNING] IP mismatch for TTY $detected_tty. Expected: $target_ip, Found: $current_ip" >> "$LOG"
fi

```

else
echo "$NOW [WARNING] Invalid or non-PTS TTY detected: $detected_tty" >> "$LOG"
fi
}

# 화이트리스트 검사

if is_whitelisted; then
echo "$NOW [INFO] $IP is in whitelist. No action taken." >> "$LOG"
exit 0
fi

# 이미 차단된 IP인지 검사

if already_blocked; then
echo "$NOW [INFO] $IP is already blocked. Skipping." >> "$LOG"
exit 0
fi

# 차단 리스트에 추가

echo "$IP" >> "$BLOCKED_LIST"

# 경고 로그 출력

echo "$NOW [ALERT] Unauthorized SSH access from $IP. Blocking IP and terminating session..." >> "$LOG"

# 해당 IP의 특정 SSH 세션 강제 종료

kill_detected_ssh_session "$IP" "$TTY"

# 실제 차단 명령 (활성화 시 주석 해제)

iptables -I INPUT -s "$IP" -j DROP
iptables-save > /etc/iptables/rules.v4
iptables-save > /etc/sysconfig/iptables

# 시스템 재부팅 (활성화 시 주석 해제)

# /sbin/shutdown -r now

exit 0